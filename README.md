# AWS VPC and Subnet Provisioning API (Serverless with Terraform)

This project deploys a secure, authenticated REST API using AWS API Gateway and Lambda that allows users to create a VPC with subnets. Subnet metadata is stored in a DynamoDB table. The infrastructure deplouyment is fully autimated using Terraform.

## Features

- Authenticated API with AWS Cognito
- Create a VPC with multiple subnets
- VPC-Subnet metadata stored in DynamoDB
- Configurable VPC CIDR, subnet size, and AWS region

---

## Technology Stack

- AWS Lambda
- AWS API Gateway (for REST API)
- AWS Cognito (user authentication and authorization)
- AWS DynamoDB
- Hashicorp Terraform

---

## Authentication

The API is protected using AWS Cognito. Only authenticated users can access the VPC creation endpoint. Authorization is currently set to open for any authenticated user.

---

## Terraform Variables

| Name            | Description                      | Type   | Default       |
|-----------------|----------------------------------|--------|---------------|
| `region`        | AWS region for deployment        | string | `"us-east-1"` |
| `account_id`    | AWS Account ID                   | string | N/A           |

---

## Using this automation after deployment

Once this infrastructure is deployed, follow the below steps to **create** and **retrieve** a VPC and its subnets.

---

### 1. Authenticate with Cognito

Use any pre-provisioned test user or sign up a new user in the Cognito User Pool. Then authenticate to get a **Cognito ID token (JWT)**.

You can use tools like Postman or AWS CLI to perform the authentication and extract the token.

---

### 2. Create a VPC and subnets within it via API

Use the API Gateway endpoint (from Terraform output: `api_url`) to create a VPC with subnets by making a `POST` request like this:

\`\`\`bash
curl -X POST https://<api-id>.execute-api.us-east-1.amazonaws.com/demo/create_network_infra \
  -H "Authorization: Bearer <your-id-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "region": "us-east-1",
    "cidr": "10.1.0.0/24",
    "subnet_size": 28
  }'

### 3. Retrieve All or particular VPC and Subnet Metadata from the API

1- All Metadata

Send an authenticated `GET` request to:

GET https://<api-id>.execute-api.<region>.amazonaws.com/demo/create_network_infra

2- Particular Metadata

Example - All VPCs and subnets in a particular region

GET https://<api-id>.execute-api.<region>.amazonaws.com/demo/create_network_infra/region/{region}