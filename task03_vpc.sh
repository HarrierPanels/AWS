#!/bin/bash

# Get AWS Configuration Variables
source_file=".env"
. "$source_file"

# Function to configure AWS CLI profile
aws_profile_config() {
    aws configure --profile $1 set aws_access_key_id $2
    aws configure --profile $1 set aws_secret_access_key $3
}

# Function to check if three arguments are provided
check_arguments() {
    if [ "$#" -ne 3 ]; then
        echo "Error: You must provide exactly three EC2 instance IDs as arguments."
        echo "Usage: $0 <EC2_INSTANCE_A> <EC2_INSTANCE_B> <EC2_INSTANCE_C>"
        exit 1
    fi
}

# Check if three arguments are provided
check_arguments "$@"

# Configure AWS profile
echo "Configuring AWS Profile $aws_profile ..."
aws_profile_config $aws_profile $aws_access_key_id $aws_secret_access_key

# Variables for region, CIDR, etc.
region_a="us-east-1"
region_b="eu-west-1"
region_c="ap-south-1"

cidr_a="10.0.0.0/16"
cidr_b="10.1.0.0/16"
cidr_c="10.2.0.0/16"

vpc_tag_a="cmtr-79e2b04a-vpc-a"
vpc_tag_b="cmtr-79e2b04a-vpc-b"
vpc_tag_c="cmtr-79e2b04a-vpc-c"

route_table_tag_a="cmtr-79e2b04a-public-rt-a"
route_table_tag_b="cmtr-79e2b04a-public-rt-b"
route_table_tag_c="cmtr-79e2b04a-public-rt-c"

ec2_instance_a=$1
ec2_instance_b=$2
ec2_instance_c=$3

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

# Function to get private IP address of an EC2 instance
get_instance_private_ip() {
    local instance_id=$1
    local region=$2
    aws ec2 describe-instances \
        --instance-ids $instance_id \
        --region $region \
        --profile $aws_profile \
        --query 'Reservations[0].Instances[0].PrivateIpAddress' \
        --output text
}

# Function to create VPC peering connection and get its ID
create_vpc_peering() {
    local requester_vpc=$1
    local accepter_vpc=$2
    local requester_region=$3
    local accepter_region=$4
    local peering_id=$(aws ec2 create-vpc-peering-connection \
        --vpc-id $requester_vpc \
        --peer-vpc-id $accepter_vpc \
        --region $requester_region \
        --peer-region $accepter_region \
        --profile $aws_profile \
        --query 'VpcPeeringConnection.VpcPeeringConnectionId' \
        --output text)
}

# Function to accept VPC peering connection
accept_vpc_peering() {
    local peering_id=$1
    local region=$2
    aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id \
        $peering_id --region $region --profile $aws_profile
}

# Function to update route table for VPC peering
update_route_table() {
    local route_table=$1
    local destination_cidr=$2
    local peering_connection_id=$3
    local region=$4
    aws ec2 create-route \
        --route-table-id $route_table \
        --destination-cidr-block $destination_cidr \
        --vpc-peering-connection-id $peering_connection_id \
        --region $region \
        --profile $aws_profile
}

# Function to create a transit gateway
create_transit_gateway() {
    local region=$1
    local tgw_id=$(aws ec2 create-transit-gateway \
        --region $region \
        --profile $aws_profile \
        --query 'TransitGateway.TransitGatewayId' \
        --output text)
}

# Function to check if a transit gateway exists in a region
check_transit_gateway_exists() {
    local region=$1
    local tgw_id=$(aws ec2 describe-transit-gateways \
        --region $region \
        --profile $aws_profile \
        --query 'TransitGateways[0].TransitGatewayId' \
        --output text)
}

# Function to create a transit gateway VPC attachment
create_tgw_vpc_attachment() {
    local tgw_id=$1
    local vpc_id=$2
    local region=$3
    aws ec2 create-transit-gateway-vpc-attachment \
        --transit-gateway-id $tgw_id \
        --vpc-id $vpc_id \
        --subnet-ids $(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --region $region --profile $aws_profile --query 'Subnets[*].SubnetId' --output text) \
        --region $region \
        --profile $aws_profile
}

# Function to create a transit gateway peering attachment
create_tgw_peering_attachment() {
    local tgw_id=$1
    local peer_tgw_id=$2
    local region=$3
    local peer_region=$4
    aws ec2 create-transit-gateway-peering-attachment \
        --transit-gateway-id $tgw_id \
        --peer-transit-gateway-id $peer_tgw_id \
        --region $region \
        --peer-region $peer_region \
        --profile $aws_profile
}

# Function to update transit gateway route table
update_tgw_route_table() {
    local tgw_route_table_id=$1
    local destination_cidr=$2
    local tgw_attachment_id=$3
    local region=$4
    aws ec2 create-transit-gateway-route \
        --transit-gateway-route-table-id $tgw_route_table_id \
        --destination-cidr-block $destination_cidr \
        --transit-gateway-attachment-id $tgw_attachment_id \
        --region $region \
        --profile $aws_profile
}

# Function to perform health checks
perform_healthcheck() {
    local instance_id=$1
    local target_ip=$2
    local region=$3
    echo "Performing health check on EC2 instance $instance_id in $region..."
    aws ssm send-command \
        --instance-ids $instance_id \
        --document-name "AWS-RunShellScript" \
        --parameters "commands=[\"ping -c 4 $target_ip\"]" \
        --region $region \
        --profile $aws_profile
}

# Main execution
main() {
    # Get VPC IDs
    echo "Getting VPC IDs..."
    vpc_id_a=$(get_vpc_id_by_tag $vpc_tag_a $region_a)
    echo "VPC A ID: $vpc_id_a"
    vpc_id_b=$(get_vpc_id_by_tag $vpc_tag_b $region_b)
    echo "VPC B ID: $vpc_id_b"
    vpc_id_c=$(get_vpc_id_by_tag $vpc_tag_c $region_c)
    echo "VPC C ID: $vpc_id_c"

    # Get Route Table IDs
    echo "Getting Route Table IDs..."
    route_table_id_a=$(get_route_table_id_by_tag $route_table_tag_a $region_a)
    echo "Route Table A ID: $route_table_id_a"
    route_table_id_b=$(get_route_table_id_by_tag $route_table_tag_b $region_b)
    echo "Route Table B ID: $route_table_id_b"
    route_table_id_c=$(get_route_table_id_by_tag $route_table_tag_c $region_c)
    echo "Route Table C ID: $route_table_id_c"

    # Get EC2 instance private IPs
    echo "Getting private IP addresses of EC2 instances..."
    private_ip_a=$(get_instance_private_ip $ec2_instance_a $region_a)
    echo "Private IP of EC2 Instance A: $private_ip_a"
    private_ip_b=$(get_instance_private_ip $ec2_instance_b $region_b)
    echo "Private IP of EC2 Instance B: $private_ip_b"
    private_ip_c=$(get_instance_private_ip $ec2_instance_c $region_c)
    echo "Private IP of EC2 Instance C: $private_ip_c"

    # Create VPC peering connections
    echo "Creating VPC peering between VPC A and VPC B..."
    peering_connection_ab=$(create_vpc_peering $vpc_id_a $vpc_id_b $region_a $region_b)
    echo "VPC Peering Connection ID: $peering_connection_ab"
    accept_vpc_peering $peering_connection_ab $region_b

    # Update route tables for VPC peering
    echo "Updating route tables for VPC peering..."
    update_route_table $route_table_id_a $cidr_b $peering_connection_ab $region_a
    update_route_table $route_table_id_b $cidr_a $peering_connection_ab $region_b

    # Check if Transit Gateways exist and create if necessary
    echo "Checking for existing Transit Gateways..."
    tgw_a=$(check_transit_gateway_exists $region_a)
    if [ "$tgw_a" == "None" ]; then
        echo "Creating Transit Gateway in Region A..."
        tgw_a=$(create_transit_gateway $region_a)
    else
        echo "Transit Gateway already exists in Region A: $tgw_a"
    fi

    tgw_b=$(check_transit_gateway_exists $region_b)
    if [ "$tgw_b" == "None" ]; then
        echo "Creating Transit Gateway in Region B..."
        tgw_b=$(create_transit_gateway $region_b)
    else
        echo "Transit Gateway already exists in Region B: $tgw_b"
    fi

    tgw_c=$(check_transit_gateway_exists $region_c)
    if [ "$tgw_c" == "None" ]; then
        echo "Creating Transit Gateway in Region C..."
        tgw_c=$(create_transit_gateway $region_c)
    else
        echo "Transit Gateway already exists in Region C: $tgw_c"
    fi

    # Create Transit Gateway VPC attachments
    echo "Creating Transit Gateway VPC Attachments..."
    create_tgw_vpc_attachment $tgw_a $vpc_id_a $region_a
    create_tgw_vpc_attachment $tgw_b $vpc_id_b $region_b
    create_tgw_vpc_attachment $tgw_c $vpc_id_c $region_c

    # Create Transit Gateway peering attachments
    echo "Creating Transit Gateway peering between Region A and Region C..."
    tgw_peering_ac=$(create_tgw_peering_attachment $tgw_a $tgw_c $region_a $region_c)
    echo "Transit Gateway Peering Attachment AC ID: $tgw_peering_ac"
    echo "Creating Transit Gateway peering between Region B and Region C..."
    tgw_peering_bc=$(create_tgw_peering_attachment $tgw_b $tgw_c $region_b $region_c)
    echo "Transit Gateway Peering Attachment BC ID: $tgw_peering_bc"

    # Update Transit Gateway route tables
    echo "Updating Transit Gateway route tables..."
    update_tgw_route_table $tgw_a $cidr_c $tgw_peering_ac $region_a
    update_tgw_route_table $tgw_c $cidr_a $tgw_peering_ac $region_c
    update_tgw_route_table $tgw_b $cidr_c $tgw_peering_bc $region_b
    update_tgw_route_table $tgw_c $cidr_b $tgw_peering_bc $region_c

    # Perform health checks with actual target IPs
    echo "Performing health checks..."
    perform_healthcheck $ec2_instance_a $private_ip_b $region_a  # Ping from instance A to instance B
    perform_healthcheck $ec2_instance_b $private_ip_a $region_b  # Ping from instance B to instance A
    perform_healthcheck $ec2_instance_c $private_ip_a $region_c  # Ping from instance C to instance A

    echo "All tasks completed successfully."
}

# Execute the main function
main
