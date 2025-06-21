#### Lambda Execution IAM Role ####
resource "aws_iam_role" "network_infra_lambda_execution_role" {
  name = "network_infra_lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

#### Lambda Execution IAM Role Policy ####
resource "aws_iam_role_policy" "network_infra_lambda_execution_role_policy" {
  name = "network_infra_lambda_exec_role_policy"
  role = aws_iam_role.network_infra_lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:CreateVpc",
          "ec2:CreateSubnet",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets"
        ],
        Resource = [
          "arn:aws:ec2:${var.region}:${var.account_id}:vpc/*",
          "arn:aws:ec2:${var.region}:${var.account_id}:subnet/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem",
          "dynamodb:Scan"
        ],
        Resource = "arn:aws:dynamodb:${var.region}:${var.account_id}:table/network_infra_data"
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/lambda/network_infra_lambda_function:*"
      }
    ]
  })
}

#### Lambda Function ####
resource "aws_lambda_function" "network_infra_lambda_function" {
  function_name = "network_infra_function"
  handler       = "network.lambda_handler"
  runtime       = "python3.10"
  role          = aws_iam_role.network_infra_lambda_execution_role.arn
  filename      = "network.zip"
  environment {
    variables = {
      DynamoDB_Table_Name = aws_dynamodb_table.network_infra_data.name
    }
  }
}

#### DynamoDB table for network infra ref data storage ####
resource "aws_dynamodb_table" "network_infra_data" {
  name         = "network_infra_data"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "VpcId"
  range_key    = "SubnetId"
  attribute {
    name = "VpcId"
    type = "S"
  }
  attribute {
    name = "SubnetId"
    type = "S"
  }
}

#### Cognito user pool ####
resource "aws_cognito_user_pool" "authorized_users" {
  name = "network_infra_api_user_pool"
}

#### Cognito user pool client ####
resource "aws_cognito_user_pool_client" "authorized_users_client" {
  name                                 = "network_infra_api_users_client"
  user_pool_id                         = aws_cognito_user_pool.authorized_users.id
  generate_secret                      = false
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid"]
  callback_urls                        = ["http://localhost/callback"]
  logout_urls                          = ["http://localhost/logout"]
  supported_identity_providers         = ["COGNITO"]
}

#### API Gateway ####
resource "aws_api_gateway_rest_api" "network_infra_api" {
  name = "network_infra_api"
}

resource "aws_api_gateway_resource" "network_infra_apigw_resource" {
  parent_id   = aws_api_gateway_rest_api.network_infra_api.root_resource_id
  path_part   = "create_network_infra"
  rest_api_id = aws_api_gateway_rest_api.network_infra_api.id
}

resource "aws_api_gateway_authorizer" "network_infra_apigw_authorizer" {
  name            = "network_infra_apigw_authorizer"
  rest_api_id     = aws_api_gateway_rest_api.network_infra_api.id
  identity_source = "method.request.header.Authorization"
  type            = "COGNITO_USER_POOLS"
  provider_arns   = [aws_cognito_user_pool.authorized_users.arn]
}

resource "aws_api_gateway_method" "network_infra_apigw_method" {
  authorization = "COGNITO_USER_POOLS"
  http_method   = "POST"
  resource_id   = aws_api_gateway_resource.network_infra_apigw_resource.id
  rest_api_id   = aws_api_gateway_rest_api.network_infra_api.id
  authorizer_id = aws_api_gateway_authorizer.network_infra_apigw_authorizer.id
}

resource "aws_api_gateway_integration" "network_infra_apigw_integration" {
  rest_api_id             = aws_api_gateway_rest_api.network_infra_api.id
  resource_id             = aws_api_gateway_resource.network_infra_apigw_resource.id
  http_method             = aws_api_gateway_method.network_infra_apigw_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.network_infra_lambda_function.invoke_arn
}

resource "aws_api_gateway_deployment" "network_infra_apigw_deployment" {
  depends_on  = [aws_api_gateway_integration.network_infra_apigw_integration]
  rest_api_id = aws_api_gateway_rest_api.network_infra_api.id
  stage_name  = "demo"
}

resource "aws_lambda_permission" "network_infra_api_lambda_invoke_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.network_infra_lambda_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.network_infra_api.execution_arn}/*/*"
}
