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

# 6.1. create iot core stream output S3 bucket
resource "aws_s3_bucket" "iot_core_output" {
  bucket = "test-iot-core-output-anggi"
  force_destroy = true
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.iot_core_output.id
  acl    = "private"
}

# 6.2. create kinesis delivery stream to stream iot core data to S3
resource "aws_kinesis_firehose_delivery_stream" "stream_to_s3" {
  name        = "terraform-kinesis-firehose-s3-test-stream"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.iot_core_output.arn
  }
}

# 6.3. create firehose IAM role
resource "aws_iam_role" "firehose_role" {
  name = "firehose_test_role"

  assume_role_policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "firehose.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF
}

# 6.4. add S3 role policy to firehose IAM role
resource "aws_iam_role_policy" "s3_policy" {
  name = "s3_policy"
  role = aws_iam_role.firehose_role.id
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

# 6.5. create IoT rule
resource "aws_iot_topic_rule" "rule" {
  name        = "MyRule"
  description = "Example rule"
  enabled     = true
  sql         = "SELECT *, timestamp() AS timestamp FROM 'test-topic-anggi'"
  sql_version = "2016-03-23"

  # s3 {
  #   bucket_name = aws_s3_bucket.iot_core_output.bucket
  #   key = "output"
  #   role_arn = aws_iam_role.iot_role.arn
  # }
  firehose {
    delivery_stream_name = aws_kinesis_firehose_delivery_stream.stream_to_s3.name
    role_arn = aws_iam_role.iot_role.arn
    separator = "\n"
  }
}

# 6.6. create IoT IAM role
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

# 6.7. add firehose role policy to IoT IAM role
resource "aws_iam_role_policy" "firehose_policy" {
  name = "firehose_policy"
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
      },
      {
        "Sid": "",
        "Effect": "Allow",
        "Action": [
          "firehose:DeleteDeliveryStream",
          "firehose:PutRecord",
          "firehose:PutRecordBatch",
          "firehose:UpdateDestination"
        ],
        "Resource": ["${aws_kinesis_firehose_delivery_stream.stream_to_s3.arn}"]
      }
    ]
  })
}