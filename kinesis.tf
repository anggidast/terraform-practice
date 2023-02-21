# 5.1. create kinesis data stream
resource "aws_kinesis_stream" "test_stream" {
  name             = "kinesis-to-s3"
  shard_count      = 1

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }
}

# 5.2. create kinesis data generator for testing
resource "aws_cloudformation_stack" "kdg" {
  name = "Kinesis-Data-Generator-Cognito-User"
  template_url = "https://aws-kdg-tools.s3.${var.region}.amazonaws.com/cognito-setup.json"
  parameters = {
    Username = var.kdg_username
    Password = var.kdg_password
  }
  capabilities = ["CAPABILITY_IAM"]
}

# 5.3. create kinesis delivery stream to deliver data from kinesis stream to S3 bucket
resource "aws_kinesis_firehose_delivery_stream" "extended_s3_stream" {
  name        = "terraform-kinesis-firehose-extended-s3-test-stream"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.test_stream.arn
    role_arn = aws_iam_role.firehose_role.arn
  }

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.stream_bucket_output.arn
  }
}

# 5.4. create S3 bucket to store stream output
resource "aws_s3_bucket" "stream_bucket_output" {
  bucket = "test-stream-bucket-output-anggi"
  force_destroy = true
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.stream_bucket_output.id
  acl    = "private"
}

# 5.5. create IAM role for kinesis delivery stream
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

# 5.6. add kinesis data stream and S3 bucket IAM role policy
resource "aws_iam_role_policy" "kinesis_data_stream_policy" {
  name = "kinesis_data_stream_policy"
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
          "${aws_s3_bucket.stream_bucket_output.arn}",
          "${aws_s3_bucket.stream_bucket_output.arn}/*"
        ]
      },
      {
        "Sid": "",
        "Effect": "Allow",
        "Action": [
          "kinesis:DescribeStream",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:ListShards"
        ],
        "Resource": "${aws_kinesis_stream.test_stream.arn}"
      }
    ]
  })
}