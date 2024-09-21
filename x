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
echo "VPC A ID: $vpc_a"
vpc_b=$(get_vpc_id_by_tag $vpc_tag_b $region_b)
echo "VPC B ID: $vpc_b"
vpc_c=$(get_vpc_id_by_tag $vpc_tag_c $region_c)
echo "VPC C ID: $vpc_c"

# Get actual Route Table IDs
route_table_a=$(get_route_table_id_by_tag $route_table_tag_a $region_a)
echo "Route Table A ID: $route_table_a"
route_table_b=$(get_route_table_id_by_tag $route_table_tag_b $region_b)
echo "Route Table B ID: $route_table_b"
route_table_c=$(get_route_table_id_by_tag $route_table_tag_c $region_c)
echo "Route Table C ID: $route_table_c"

# Function to create VPC peering connection and get its ID
create_vpc_peering() {
    local requester_vpc=$1
    local accepter_vpc=$2
    local requester_region=$3
    local accepter_region=$4
    echo "Creating VPC peering between $requester_vpc in $requester_region and $accepter_vpc in $accepter_region..."
    local peering_id=$(aws ec2 create-vpc-peering-connection \
        --vpc-id $requester_vpc \
        --peer-vpc-id $accepter_vpc \
        --region $requester_region \
        --peer-region $accepter_region \
        --profile $aws_profile \
        --query 'VpcPeeringConnection.VpcPeeringConnectionId' \
        --output text)

    echo "VPC Peering Connection ID: $peering_id"
    echo "$peering_id"
}

create_vpc_peering $vpc_a $vpc_b $region_a $region_b
