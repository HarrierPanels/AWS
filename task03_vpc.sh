#!/bin/bash

# Get AWS Configuration Variables
source_file=".env"
. "$source_file"

# Function to configure AWS CLI profile
aws_profile_config() {
    aws configure --profile $1 set aws_access_key_id $2
    aws configure --profile $1 set aws_secret_access_key $3
}

# Configure AWS profile
echo "Configuring AWS Profile $aws_profile ..."
aws_profile_config $aws_profile $aws_access_key_id $aws_secret_access_key

# Variables for region, CIDR, etc.
region_a="us-east-1"
region_b="eu-west-1"
region_c="ap-south-1"

vpc_tag_a="cmtr-79e2b04a-vpc-a"
vpc_tag_b="cmtr-79e2b04a-vpc-b"
vpc_tag_c="cmtr-79e2b04a-vpc-c"

route_table_tag_a="cmtr-79e2b04a-public-rt-a"
route_table_tag_b="cmtr-79e2b04a-public-rt-b"
route_table_tag_c="cmtr-79e2b04a-public-rt-c"

ec2_instance_a="i-07888b63fec58f367"
ec2_instance_b="i-0e880597875dc34da"
ec2_instance_c="i-09cbb506c19121403"

# Function to get VPC ID by tag
get_vpc_id_by_tag() {
    local tag=$1
    local region=$2
    aws ec2 describe-vpcs \
        --filters "Name=tag:Name,Values=$tag" \
        --region $region \
        --profile $aws_profile \
        --query 'Vpcs[0].VpcId' \
        --output text
}

# Function to get Route Table ID by tag
get_route_table_id_by_tag() {
    local tag=$1
    local region=$2
    aws ec2 describe-route-tables \
        --filters "Name=tag:Name,Values=$tag" \
        --region $region \
        --profile $aws_profile \
        --query 'RouteTables[0].RouteTableId' \
        --output text
}

# Get actual VPC IDs
vpc_a=$(get_vpc_id_by_tag $vpc_tag_a $region_a)
vpc_b=$(get_vpc_id_by_tag $vpc_tag_b $region_b)
vpc_c=$(get_vpc_id_by_tag $vpc_tag_c $region_c)

# Get actual Route Table IDs
route_table_a=$(get_route_table_id_by_tag $route_table_tag_a $region_a)
route_table_b=$(get_route_table_id_by_tag $route_table_tag_b $region_b)
route_table_c=$(get_route_table_id_by_tag $route_table_tag_c $region_c)

# Function to create VPC peering connection
create_vpc_peering() {
    local requester_vpc=$1
    local accepter_vpc=$2
    local region=$3
    echo "Creating VPC peering between $requester_vpc and $accepter_vpc in $region..."
    aws ec2 create-vpc-peering-connection \
        --vpc-id $requester_vpc \
        --peer-vpc-id $accepter_vpc \
        --region $region \
        --profile $aws_profile
}

# Function to update route table for VPC peering
update_route_table() {
    local route_table=$1
    local destination_cidr=$2
    local peering_connection_id=$3
    local region=$4
    echo "Updating route table $route_table for VPC peering in $region..."
    aws ec2 create-route \
        --route-table-id $route_table \
        --destination-cidr-block $destination_cidr \
        --vpc-peering-connection-id $peering_connection_id \
        --region $region \
        --profile $aws_profile
}

# Function to create Transit Gateway
create_transit_gateway() {
    local region=$1
    echo "Creating Transit Gateway in $region..."
    aws ec2 create-transit-gateway --region $region --profile $aws_profile
}

# Function to create Transit Gateway peering
create_transit_gateway_peering() {
    local tgw_id_1=$1
    local tgw_id_2=$2
    local region_1=$3
    local region_2=$4
    echo "Creating Transit Gateway peering between $region_1 and $region_2..."
    aws ec2 create-transit-gateway-peering-attachment \
        --transit-gateway-id $tgw_id_1 \
        --peer-transit-gateway-id $tgw_id_2 \
        --peer-region $region_2 \
        --region $region_1 \
        --profile $aws_profile
}

# Function to update Transit Gateway route table
update_tgw_route_table() {
    local tgw_route_table_id=$1
    local destination_cidr=$2
    local tgw_attachment_id=$3
    local region=$4
    echo "Updating Transit Gateway route table in $region..."
    aws ec2 create-route \
        --route-table-id $tgw_route_table_id \
        --destination-cidr-block $destination_cidr \
        --transit-gateway-attachment-id $tgw_attachment_id \
        --region $region \
        --profile $aws_profile
}

# Function to perform health checks
perform_healthcheck() {
    local instance_id=$1
    local region=$2
    echo "Performing health check on EC2 instance $instance_id in $region..."
    aws ssm send-command \
        --instance-ids $instance_id \
        --document-name "AWS-RunShellScript" \
        --parameters 'commands=["ping -c 4 10.1.0.5"]' \
        --region $region \
        --profile $aws_profile
}

# Main execution
echo "Creating VPC peering connections..."
create_vpc_peering $vpc_a $vpc_b $region_a

# Assuming peering connection IDs are retrieved after creation (pseudo IDs for illustration)
peering_connection_ab="pcx-01234"
peering_connection_bc="pcx-56789"

echo "Updating route tables..."
update_route_table $route_table_a "10.1.0.0/16" $peering_connection_ab $region_a
update_route_table $route_table_b "10.0.0.0/16" $peering_connection_ab $region_b

echo "Creating Transit Gateways..."
create_transit_gateway $region_a
create_transit_gateway $region_b
create_transit_gateway $region_c

echo "Creating Transit Gateway Peering..."
create_transit_gateway_peering "tgw-12345" "tgw-67890" $region_c $region_a
create_transit_gateway_peering "tgw-12345" "tgw-67890" $region_c $region_b

echo "Performing health checks..."
perform_healthcheck $ec2_instance_a $region_a
perform_healthcheck $ec2_instance_b $region_b
perform_healthcheck $ec2_instance_c $region_c

echo "All tasks completed successfully."
