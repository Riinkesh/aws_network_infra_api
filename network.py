import boto3
import os
import ipaddress
from botocore.exceptions import ClientError
import json

dynamodb_table_name = os.environ.get('DynamoDB_Table_Name')
if not dynamodb_table_name:
    raise ValueError("Environment variable dynamodb_table_name is missing")

def lambda_handler(event, context):
    try:
        body = json.loads(event.get("body", "{}"))

        cidr = body.get("cidr")
        region = body.get("region")
        subnet_size = int(body.get("subnet_size", 28)) # Default to /28

        if not cidr or not region:
            return {
                "statusCode": 400,
                "body": {"error": "cidr and region are missing"}
            }

        # Validate CIDR
        try:
            base_network = ipaddress.ip_network(cidr)
        except ValueError:
            return {
                "statusCode": 400,
                "body": {"error": "Invalid CIDR format"}
            }

        if subnet_size < 28:
            return {
                "statusCode": 400,
                "body": {"error": "subnet_size must be >= 28"}
            }

        ec2 = boto3.client("ec2", region_name=region)
        dynamodb = boto3.resource("dynamodb", region_name=region)
        table = dynamodb.Table(dynamodb_table_name)

        # Create VPC
        vpc_response = ec2.create_vpc(CidrBlock=cidr)
        vpc_id = vpc_response['Vpc']['VpcId']

        ec2.get_waiter('vpc_available').wait(VpcIds=[vpc_id])

        # Get list of AZs in the region & use first 3
        azs = ec2.describe_availability_zones()['AvailabilityZones'][:3]

        subnet_cidrs = list(base_network.subnets(new_prefix=subnet_size))[:3]

        subnet_info = []

        for i in range(3):
            az = azs[i]['ZoneName']
            subnet_cidr = subnet_cidrs[i]

            subnet_resp = ec2.create_subnet(
                VpcId=vpc_id,
                CidrBlock=str(subnet_cidr),
                AvailabilityZone=az
            )
            subnet_id = subnet_resp['Subnet']['SubnetId']

            # Store metadata in DynamoDB
            table.put_item(Item={
                'VpcId': vpc_id,
                'SubnetId': subnet_id,
                'Cidr': str(subnet_cidr),
                'AZ': az
            })

            subnet_info.append({
                "SubnetId": subnet_id,
                "Cidr": str(subnet_cidr),
                "AZ": az
            })

        return {
            "statusCode": 200,
            "body": {
                "VpcId": vpc_id,
                "Subnets": subnet_info
            }
        }

    except ClientError as e:
        return {
            "statusCode": 500,
            "body": {"error": e.response['Error']['Message']}
        }
    except Exception as e:
        return {
            "statusCode": 500,
            "body": {"error": str(e)}
        }