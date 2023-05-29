# Deploy de um bucket S3 com KMS para separação de deveres

Separação de deveres é um dos principios em gerenciamento de segurança que procura reduzir o risco de atividades fradulentas ou maliciosas, garantindo que nenhuma pessoa tenha controle completo sobre tarefas críticas ou informações sensíveis. Para aplicarmos esse princípios em nosso bucket S3 precisaremos utilizar algumas outras tecnologias disponíveis na aws, sendo elas: IAM e KMS.

<img src="/img/arquitetura.png" alt="arquitetura de rede"/>

-----

## Passos necessarios:

*  Instalar terraforma e configurar sua aws


* Criar políticas para restringir usúarios IAM

* Criar roles para usúarios IAM

* Criar usuários IAM

* Criar uma KMS key

* Criar um s3 buck  que aceita apenas dados criptografados em KMS especificas




### Passo 1: Instalar terraforma e configurar sua aws


### Instalando terraform:

Rode os seguintes comandos no terminal para instalar terraform no ubuntu:

```
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg

gpg --no-default-keyring --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg --fingerprint

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update && sudo apt install terraform
```
---

### Configurando suas credenciais para utilizar sua conta AWS a partir do terminal:


Rode os seguintes comandos no terminal:

```
sudo apt install awscli
```

Para acessar sua conta será necessário fornecer as suas credenciais no seguinte comando:

```
aws configure
```

Em *AWS Access Key ID* e *AWS Secret Access Key ID*: adicione o ID das suas chaves AWS.

Em *Default region name*: adicione uma região (como `us-east-1`).

Em *Default output format*: adicione um formato (como `json`).

Feito os passos acimas agora já podemos começar a criar a arqutitetura em si.

### Passo 2: Criar políticas para restringir usúarios IAM

É necessário criar uma pasta com os seguintes arquivos: iam-policies.tf e iam-roles.tf

No arquivo iam-policies.tf iremos criar as políticas que serão utilizadas para restringir os usúarios IAM, sendo elas:


* Primeira política que criaremos será chamado: *bucket-admin* com a permissão de criar e gerenciar permissões em um s3 bucket

``` hcl
data "aws_iam_policy_document" "bucket-admin" {
  statement {
    sid       = "AllowAllActions"
    effect    = "Allow"
    resources = ["*"]
    actions   = ["s3:*"]
  }

  statement {
    sid       = "DenyObjectAccess"
    effect    = "Deny"
    resources = ["arn:aws:s3:::*drive-cloud*"]

    actions = [
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:PutObjectVersionAcl",
    ]
  }
}

resource "aws_iam_policy" "bucket-admin" {
  name   = "bucket-admin"
  path   = "/"
  policy = data.aws_iam_policy_document.bucket-admin.json 
}
```

O código acima criará a política para gerenciar o bucket chamado drive-cloud, dando responsabilidades de admin para o bucket específico.

---

* Segunda política será chamada de: *kms-admin* que poderá criar e gerenciar permissões de nossa chave KMS, responsável por criptografar os dados que serão colocados na nuvem

``` hcl
data "aws_iam_policy_document" "kms-admin" {
  statement {
    sid       = "AllowAllKMS"
    effect    = "Allow"
    resources = [" arn:aws:kms:*:*111122223333*:key/*"]
    actions   = ["kms:*"]
  }

  statement {
    sid       = "DenyKMSKeyUsage"
    effect    = "Deny"
    resources = [" arn:aws:kms:*:*111122223333*:key/*"]

    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:ReEncryptFrom",
      "kms:ReEncryptTo",
    ]
  }
}

resource "aws_iam_policy" "kms-admin" {
  name   = "kms-admin"
  path   = "/"
  policy = data.aws_iam_policy_document.kms-admin.json
}

```

O código acima criará a política chamada kms-admin, que tem como função permitir diversos gerenciamentos de chaves KMS, criar chaves, gerenciar permissões e modificar permissões da chave, sendo uma política de alto privilégio, entretanto não permite alguns usos da chave, como por exemplo, criptografar e descriptografar dados, é importante salientar que para o código funcionar é necessário mudar *111122223333* para o ID da sua conta AWS.

---

* Terceira política será chamada de: *authorized-users* que poderá acessar um bucket específico e usar a chave KMS para criptografar os dados, entretanto sem poder de gerenciamento.

``` hcl
resource "aws_iam_policy" "authorized-access" {
  name   = "secure-bucket-access"
  path   = "/"
  policy = data.aws_iam_policy_document.authorized-access.json
}

data "aws_iam_policy_document" "authorized-access" {
  statement {
    sid       = "BasicList"
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "s3:ListAllMyBuckets",
      "s3:HeadBucket",
    ]
  }

  statement {
    sid    = "AllowSecureBucket"
    effect = "Allow"

    resources = [
      "arn:aws:s3:::*drive-cloud*/*",
      "arn:aws:s3:::*drive-cloud*",
    ]

    actions = [
      "s3:PutObject",
      "s3:GetObjectAcl",
      "s3:GetObject",
      "s3:DeleteObjectVersion",
      "s3:DeleteObject",
      "s3:GetBucketLocation",
      "s3:GetObjectVersion",
    ]
  }
}
    
```

Essa política será responsável por permitir que os usúarios IAM possam acessar o bucket e usar a chave KMS para criptografar os dados, entretanto sem poder de gerenciamento, também é importante notar que é preciso mudar o nome do bucket para o nome do bucket que voce irá utilizar em *drive-cloud*

### Passo 3: Criar role para usúarios iam

Um AWS IAM Role é uma identidade que você pode criar em sua conta da AWS que possui permissões específicas. Uma função do IAM é semelhante a um usuário do IAM, em que ambos são identidades com credenciais e permissões associadas que determinam quais operações eles podem e não podem realizar em outros recursos da AWS. Esse próximo passo será feito em outro arquivo para manter a organização, esse arquivo será chamado: iam-roles.tf

``` hcl
resource "aws_iam_role" "authorized-access-role" {
  name = "authorized-access-role"
    assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  }

resource "aws_iam_role_policy_attachment" "authorized_access-attach" {
  role       = aws_iam_role.authorized_access.name
  policy_arn = aws_iam_policy.authorized-access.arn
}

```

Essa função é para ser usada apenas por usúarios que estão operando dentro de uma instância EC2, só criamos uma role para o authorized-access, pois as outras funções não terão um alto volume de usuários e nem será trocado muitas vezes, podendo ser atribuído as políticas apenas na criação do usúario, entretanto se for necessário criar uma role para os outros usúarios, basta copiar o código acima e mudar o nome da role e da política, além disso a função também será usado quando criarmos o EC2.

### Passo 4: Criar usúarios IAM

Para o próximo passo vamos criar um arquivo chamado: iam-users.tf, nesse arquivo criaremos usúarios e adicionaremos as políticas criadas anteriormente.

``` hcl
resource "aws_iam_user" "user_createKMSadmin" {
  name = "secure-key-admin"
  }


resource "aws_iam_user_policy_attachment" "kms-attach-policy" {
  user       = aws_iam_user.user_createKMSadmin.name
  policy_arn = aws_iam_policy.kms-admin.arn
}


resource "aws_iam_user" "user_create_bucket-admin" {
  name = "secure-bucket-admin-user"
  }


resource "aws_iam_user_policy_attachment" "admin-attach-policy" {
  user       = aws_iam_user.user_create_bucket-admin.name
  policy_arn = aws_iam_policy.bucket-admin.arn
}


resource "aws_iam_user" "bucket-access-user" {
  name = "bucket-access-user"
  }

resource "aws_iam_user_policy_attachment" "user-attach-policy" {
  user       = aws_iam_user.bucket-access-user.name
  policy_arn = aws_iam_policy.authorized-access.arn
}
```

Esse código irá criar três usúarios, um para gerenciar a chave KMS, outro para gerenciar o bucket e o último para acessar o bucket, entretanto sem poder de gerenciamento.

Além disso precisaremos também criar as credenciais de acesso para os usúarios, para isso utilizaremos o seguinte código:

```
aws iam create-access-key --user-name secure-bucket-admin-user
```
Onde secure-bucket-admin-user é o nome de usuário que você criou, esse comando irá retornar as credenciais de acesso, é importante salvar essas credenciais, pois elas serão usadas para que cada usuário consigo fazer seus comandos, além disso é importante tomar cuidado ao enviar as suas chaves de acesso, pois elas são como uma senha, se alguém tiver acesso a elas, poderá fazer qualquer coisa que o usúario tenha permissão, o que é exatamente o que estamos tentando evitar.


### Passo 5: Criar uma KMS key

A KMS key por ser algo sensível e que não será gerado diversas vezes, poderia ser criado utilizando o console da aws fazendo os seguintes passos:

* Selecione o botão crete key

* Na primeira tela defina um nome de exibição(chamado de "Alias") e uma descrição para a chave, recomendo uma descrição signficativa que informe aos outros para que serve a chave

* Na tela Step 2, defina tags se precisar delas para rastrear o uso das chaves para fins de faturamento. As tags não terão impacto funcional neste exercício, então você pode pular esta etapa se quiser, selecionando Next.

* Na terceira tela, selecione os administradores da chave. Escolha apenas o usuário kms-admin, não selecione outra função ou usuário, para garantirmos a separação de funções. Exemplo: Se escolhe a função authorized-access-role, qualquer usuário que tenha essa funçao poderá elevar seus próprios privilégios para administrador da chave, o que não é o que queremos.

* Na quarta tela, selecione os usuários escolha todos que tenham como função authorized-access-role e o usuário bucket-access-user(ou qualquer outro usuário que você queira que tenha acesso a chave).

Depois de criar a chave, faça uma nota do ARN da chave. Ele terá uma aparência semelhante a esta:

arn:aws:kms::11112222333:key/1234abcd-12ab-34cd-56ef-1234567890ab

Esse arn será utilizado dentro da policy na criação de nosso s3 bucket.

Outra possibilidade é criar a chave a partir do terraform utilizando o seguinte código:

``` hcl

resource "aws_kms_key" "authorized-access" {
  description             = "KMS key for bucket access"
  deletion_window_in_days = 10
  policy = data.aws_iam_policy_document.hello.json
  }

output "key_id" {
  value = aws_kms_key.authorized-access.key_id
}

output "key_arn" {
  value = aws_kms_key.authorized-access.arn
}


data "aws_iam_policy_document" "hello" {
  statement {
    sid       = "Enable IAM User Permissions"
    effect    = "Allow"
    resources = ["*"]
    actions   = ["kms:*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::111122223333:root"]
    }
  }

  statement {
    sid       = "Allow access for Key Administrators"
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion",
    ]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::111122223333:user/secure-key-admin"]
    }
  }

  statement {
    sid       = "Allow use of the key"
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::111122223333:role/authorized-access-role"]
    }
  }

  statement {
    sid       = "Allow attachment of persistent resources"
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant",
    ]

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::111122223333:role/authorized-access-role"]
    }
  }
}
```

# Lembre-se: Esse código poderia ser tanto realizado por voce para criação do código ou o seu kms-admin poderia executá-lo, após gerado a chave iremos utilizá-la na policy do bucket, que pode ser criada pelo secure-bucket-admin-user, se quiser use o .tf presente em kms-admin para gerar a chave antes de rodar o código.

### Passo 6: Criar um bucket

Utilizaremos o código abaixo para criar o bucket, esse bucket terá uma policy que irá negar o upload de objetos sem criptografia e que não utilizem a chave que criamos no passo anterior.

** IMPORTANTE: o passo abaixo só pode ser feito depois de ser criado a KMS KEY, já que em values deverá ser colocado o arn da kms**

``` hcl
data "aws_iam_policy_document" "s3-policy-kms" {
  statement {
    sid       = "DenyUnencryptedObjectUploads"
    effect    = "Deny"
    resources = ["arn:aws:s3:::drive-cloud/*"]
    actions   = ["s3:PutObject"]

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }

  statement {
    sid       = "DenyWrongKMSKey"
    effect    = "Deny"
    resources = ["arn:aws:s3:::drive-cloud/*"]
    actions   = ["s3:PutObject"]

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
      values   = ["arn:aws:kms::11112222333:key/1234abcd-12ab-34cd-56ef-1234567890ab"]
    }

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket" "drive-cloud" {
  bucket = "drive-cloud"
  policy = data.aws_iam_policy_document.s3-policy-kms.json
}
```

Uma outra solução séria em vez de aplicar uma política de bucket, você poderia considerar ativar a criptografia padrão do S3. Essa funcionalidade força todos os novos objetos enviados para um bucket do S3 a serem criptografados usando a chave KMS que você criou. A menos que o usuário especifique uma chave diferente. Essa funcionalidade não impede que chamadas criptografem objetos com outras chaves KMS, mas garante que os dados estejam protegidos mesmo se o usuário não especificar a criptografia KMS ao colocar o objeto. A política de bucket realizada acima é um pouco mais rigorosa do que a criptografia padrão do S3, pois garante que nenhum objeto seja criptografado por qualquer chave que não seja a chave KMS criada na etapa 5. Essa rigidez significa que a tentativa de adicionar um objeto falhará, a menos que o chamador especifique explicitamente o ID da chave KMS em cada solicitação PUT do S3. Com a criptografia padrão do S3, as tentativas de adicionar um objeto sem especificar a criptografia terão sucesso e os dados serão protegidos pela chave KMS nomeada.

Por fim, criaremos um ec2 profile utilizando a role que criamos anteriormente, para que o ec2 possa utilizar a chave kms.

``` hcl
resource "aws_iam_instance_profile" "test_profile" {
  name = "test_profile"
  role = "authorized-access-role"
}

```

Esse profile será utilizado na hora de criar o ec2 utilizando o dashboard da aws, para cria-lo selecione as seguintes opções: Amazon Linux AMI, qualquer instância para o teste pode funcionar e o instance profile que criamos acima.

Pronto agora nossa infraestrutura está pronta para ser utilizada.

### Como utilizar o KMS para criptografar e descriptografar dados

Para criptografar ao enviar algo para a kms é necessário o seguinte código:
```
aws s3 cp KMS-Cryptographic-Details.pdf s3://secure-demo-bucket/test4.pdf --sse aws:kms --sse-kms-key-id abcdefab-1234-1234-1234-abcdef01234567890


``` 

Onde KMS-Cryptographic-Details.pdf é seu arquivo desejado, secure-demo-bucket o bucket criado anteriormente e o arn é o arn da chave kms criada anteriormente.

Se funcionar aparecerá a seguinte mensagem:
```
upload: ./KMS-Cryptographic-Details.pdf to s3://secure-demo-bucket/KMS-Cryptographic-Details.pdf

```

Para descriptografar o arquivo é necessário o seguinte código no seu ec2:

```
aws s3 cp s3://secure-demo-bucket/KMS-Cryptographic-Details.pdf test3.pdf
```

Pronto, se um arquivo chamado test3.pdf apareceu na instância, isso mostra que o arquivo foi descriptografado com sucesso.
