#!/bin/bash

# Variables
aws_profile=$1
access_key=$2
secret_key=$3
region=$4
bucket_name="cmtr-79e2b04a-cloudfront-sswo-bucket-179026"
oai_name="cmtr-79e2b04a-cloudfront-sswo-oai"
cloudfront_desc="cmtr-79e2b04a-cloudfront-sswo-distribution"
nonexistent_page="database.html"

# Function to configure AWS profile
aws_profile_config() {
    aws configure set aws_access_key_id $access_key --profile $aws_profile
    aws configure set aws_secret_access_key $secret_key --profile $aws_profile
    aws configure set region $region --profile $aws_profile
}

# Function to check if three arguments are provided
check_arguments() {
    if [ "$#" -ne 4 ]; then
        echo "Error: You must provide AWS Profile Name, AWS Access Key, AWS Secret Key, and AWS Region as arguments."
        echo "Usage: $0 <your_aws_profile> <aws_access_key> <aws_secret_key> <region>"
        exit 1
    fi
}

# Check if three arguments are provided
check_arguments "$@"

# Retrieve OAI ID
get_oai_id() {
    oai_id=$(aws cloudfront list-cloud-front-origin-access-identities --query "CloudFrontOriginAccessIdentityList.Items[?Comment=='$oai_name'].Id" --output text --profile $aws_profile)
    if [ -z "$oai_id" ]; then
        echo "Error: Unable to retrieve OAI ID for $oai_name"
        exit 1
    fi
    echo "Retrieved OAI ID: $oai_id"
}

# Retrieve CloudFront Distribution ID
get_distribution_id() {
    distribution_id=$(aws cloudfront list-distributions --query "DistributionList.Items[?Comment=='$cloudfront_desc'].Id" --output text --profile $aws_profile)
    if [ -z "$distribution_id" ]; then
        echo "Error: Unable to retrieve CloudFront distribution ID for $cloudfront_desc"
        exit 1
    fi
    echo "Retrieved CloudFront Distribution ID: $distribution_id"
}

# Attach OAI to CloudFront distribution
attach_oai_to_distribution() {
    distribution_config=$(aws cloudfront get-distribution-config --id $distribution_id --profile $aws_profile)
    etag=$(echo $distribution_config | jq -r '.ETag')
    config=$(echo $distribution_config | jq -r '.DistributionConfig')

    updated_config=$(echo $config | jq --arg oai_id "origin-access-identity/cloudfront/$oai_id" '.Origins.Items[0].S3OriginConfig.OriginAccessIdentity = $oai_id')

    aws cloudfront update-distribution \
        --id $distribution_id \
        --if-match $etag \
        --distribution-config "$updated_config" \
        --profile $aws_profile

    echo "OAI attached to CloudFront distribution."
}

# Update CloudFront custom error responses
update_cloudfront_error_page() {
    distribution_config=$(aws cloudfront get-distribution-config --id $distribution_id --profile $aws_profile)
    etag=$(echo $distribution_config | jq -r '.ETag')
    config=$(echo $distribution_config | jq -r '.DistributionConfig')

    updated_config=$(echo $config | jq '.CustomErrorResponses = { "Quantity": 1, "Items": [{ "ErrorCode": 403, "ResponsePagePath": "/error.html", "ResponseCode": "404", "ErrorCachingMinTTL": 300 }] }')

    aws cloudfront update-distribution \
        --id $distribution_id \
        --if-match $etag \
        --distribution-config "$updated_config" \
        --profile $aws_profile

    echo "Updated CloudFront custom error response."
}

# Restrict public access to S3 bucket
restrict_bucket_access() {
    aws s3api put-bucket-policy --bucket $bucket_name --policy '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Deny",
                "Principal": "*",
                "Action": "s3:GetObject",
                "Resource": "arn:aws:s3:::'$bucket_name'/*",
                "Condition": {
                    "Bool": {
                        "aws:Referer": false
                    }
                }
            }
        ]
    }' --profile $aws_profile
    echo "Public access to the S3 bucket is now restricted."
}

# Grant OAI read permissions on S3 bucket
grant_oai_s3_permissions() {
    aws s3api put-bucket-policy --bucket $bucket_name --policy '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "AWS": "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity '$oai_id'"
                },
                "Action": "s3:GetObject",
                "Resource": "arn:aws:s3:::'$bucket_name'/*"
            }
        ]
    }' --profile $aws_profile
    echo "OAI granted permissions to read from the S3 bucket."
}

# Health check on CloudFront
check_cloudfront_access() {
    cloudfront_domain=$(aws cloudfront get-distribution --id $distribution_id --query 'Distribution.DomainName' --output text --profile $aws_profile)
    echo "Performing health check on CloudFront..."

    curl -I "https://$cloudfront_domain/index.html"
    curl -I "https://$cloudfront_domain/$nonexistent_page"
}

# Block all public access to the S3 bucket
block_all_public_access() {
    aws s3api put-public-access-block \
        --bucket $bucket_name \
        --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true \
        --profile $aws_profile
    echo "Blocked all public access to the S3 bucket."
}

# Main logic
aws_profile_config
get_oai_id
get_distribution_id
attach_oai_to_distribution
update_cloudfront_error_page
restrict_bucket_access
block_all_public_access
grant_oai_s3_permissions
check_cloudfront_access
