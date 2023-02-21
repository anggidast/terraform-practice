terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-west-2"
}

resource "aws_s3_bucket" "iot_core_output" {
  bucket = "test-iot-core-output-anggi"
  force_destroy = true
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.iot_core_output.id
  acl    = "private"
}

resource "aws_iot_topic_rule" "rule" {
  name        = "MyRule"
  description = "Example rule"
  enabled     = true
  sql         = "SELECT *, timestamp() AS timestamp FROM 'test-topic-anggi'"
  sql_version = "2016-03-23"

  s3 {
    bucket_name = aws_s3_bucket.iot_core_output.bucket
    key = "output"
    role_arn = aws_iam_role.iot_role.arn
  }
}

resource "aws_iam_role" "iot_role" {
  name = "iot_role"

  assume_role_policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "iot.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy" "s3_policy" {
  name = "s3_policy"
  role = aws_iam_role.iot_role.id
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "",
        "Effect": "Allow",
        "Action": [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ],
        "Resource": [
          "${aws_s3_bucket.iot_core_output.arn}",
          "${aws_s3_bucket.iot_core_output.arn}/*"
        ]
      }
    ]
  })
}