# Using shared VPC
data "aws_vpc" "ce9-coaching-shared-vpc"{
  id = "vpc-012814271f30b4442"
}

# Use existing security group
data "aws_security_group" "default"{
  name = "default"
  vpc_id = data.aws_vpc.ce9-coaching-shared-vpc.id
}


# ec2 using default security group
resource "aws_instance" "yk_ec2" {
  ami = "ami-0c614dee691cbbf37"
  instance_type = "t2.micro"

  key_name = "ykwong_ce9"
  vpc_security_group_ids = [data.aws_security_group.default.id]
  associate_public_ip_address = true
  subnet_id = "subnet-079049edc56a73fc3"

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

}

# Create dynamo and populate data
resource "aws_dynamodb_table" "db" {
  name = "yk-bookinventory"
  hash_key = "ISBN"
  billing_mode     = "PAY_PER_REQUEST"

  attribute {
    name = "ISBN"
    type = "S"
  }
}

locals {
  books = {
    "978-0134685991" = {
      Genre  = "Technology"
      Title  = "Effective Java"
      Author = "Joshua Bloch"
      Stock  = 1
    },
    "978-0134685009" = {
      Genre  = "Technology"
      Title  = "Learning Python"
      Author = "Mark Lutz"
      Stock  = 2
    },
    "974-0134789698" = {
      Genre  = "Fiction"
      Title  = "The Hitchhiker"
      Author = "Douglas Adams"
      Stock  = 10
    }
  }
}

resource "aws_dynamodb_table_item" "book-items" {
  for_each = local.books

  table_name = aws_dynamodb_table.db.name
  hash_key = "ISBN"

  item = <<JSON
{
  "ISBN": {"S": "${each.key}"},
  "Genre": {"S": "${each.value["Genre"]}"},
  "Title": {"S": "${each.value["Title"]}"},
  "Author": {"S": "${each.value["Author"]}"},
  "Stock": {"N": "${each.value["Stock"]}"}
}
JSON
}

# IAM policy for DB
resource "aws_iam_policy" "db_iam_policy" {
  name = "yk-dynamodb-read"
  
    policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "dynamodb:ListTables",   # Allow listing tables
          "dynamodb:GetItem",      # Allow getting items from tables
          "dynamodb:Query",        # Allow querying tables
          "dynamodb:Scan"          # Allow scanning tables
        ]
        Resource = "*"
      }
    ]
  })
}

# Create ec2 role
resource "aws_iam_role" "ec2_role" {
  name               = "ec2_role"
  assume_role_policy = jsonencode({

    Statement = [
      {
        Action    = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Effect    = "Allow"
        Sid       = ""
      }
    ]
  })
}

# Instance profile for IAM role
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = aws_iam_role.ec2_role.name
}

# Attach policy to ec2 role
resource "aws_iam_role_policy_attachment" "ec2_dynamodb_attachment" {
  policy_arn = aws_iam_policy.db_iam_policy.arn
  role       = aws_iam_role.ec2_role.name
}

