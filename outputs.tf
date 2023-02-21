output "server_public_ip" {
  value = aws_eip.one.public_ip
}

output "server_private_ip" {
  value = aws_instance.web_server_instance.private_ip
}

output "server_id" {
  value = aws_instance.web_server_instance.id
}

output "kinesis_data_generator_url" {
  value       = aws_cloudformation_stack.kdg.outputs["KinesisDataGeneratorUrl"]
  description = "URL outputs of the CloudFormation Stack Kinesis Data Generator"
}

output "kinesis_data_generator" {
  value       = "open kinesis data generator url for test, login using KDG username and password"
}