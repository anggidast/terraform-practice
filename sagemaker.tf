resource "aws_sagemaker_notebook_instance" "my-notebook" {
  name          = "my-notebook-instance"
  role_arn      = aws_iam_role.sagemaker_role.arn
  instance_type = "ml.t2.medium"

  tags = {
    Name = "Test Notebook"
  }
}

output "notebook_url" {
  value       = "https://${aws_sagemaker_notebook_instance.my-notebook.url}/tree"
}

resource "aws_iam_role_policy" "s3_policy" {
  name = "s3_policy"
  role = aws_iam_role.sagemaker_role.id
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "",
        "Effect": "Allow",
        "Action": [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ],
        "Resource": [
          "arn:aws:s3:::*"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "sagemaker_role" {
  name = "sagemaker_test_anggi_role"

  assume_role_policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "sagemaker.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF
}