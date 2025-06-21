output "user_pool_id" {
  value = aws_cognito_user_pool.authorized_users.id
}

output "lambda_function_name" {
  value = aws_lambda_function.network_infra_lambda_function.function_name
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.network_infra_data.name
}

output "api_url" {
  value = "https://${aws_api_gateway_rest_api.network_infra_api.id}.execute-api.${var.region}.amazonaws.com/demo/create_network_infra"
}