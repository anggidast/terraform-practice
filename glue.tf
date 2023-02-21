# 3.1. create S3 bucket
resource "aws_s3_bucket" "proj1" {
  bucket = "proj1-bucket-anggi-test"

  tags = {
    Name = "Project 1 bucket"
  }
}

# 3.2. configure S3 ACL
resource "aws_s3_bucket_acl" "acl" {
  bucket = aws_s3_bucket.proj1.id
  acl    = "private"
}

# 3.3. upload file to S3 bucket
resource "aws_s3_object" "object" {
  bucket = aws_s3_bucket.proj1.bucket
  key    = "${var.s3_path}customer.csv"
  source = "${path.root}/file/customer.csv"
}

# 4.1. create IAM role for Glue
resource "aws_iam_role" "glue" {
  name               = "AWSGlueServiceRoleDefault"
  assume_role_policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "glue.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF
}

# 4.2. attach policy to Glue IAM role
resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# 4.3. add S3 policy for Glue IAM role
resource "aws_iam_role_policy" "my_s3_policy" {
  name = "my_s3_policy"
  role = aws_iam_role.glue.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:*"
        ],
        "Resource" : [
          "${aws_s3_bucket.proj1.arn}",
          "${aws_s3_bucket.proj1.arn}/*"
        ]
      }
    ]
  })
}

# 4.4. create Glue data catalog database
resource "aws_glue_catalog_database" "proj1" {
  name = "proj_1_catalog_db"
}

# 4.5. crawl S3 object
resource "aws_glue_crawler" "proj1" {
  database_name = aws_glue_catalog_database.proj1.name
  name          = "customer_data_crawler"
  role          = aws_iam_role.glue.arn

  s3_target {
    path = "s3://${aws_s3_bucket.proj1.bucket}/${var.s3_path}"
  }
}