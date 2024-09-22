#!/bin/bash

# Variables
aws_profile=$1
aws_access_key_id=$2
aws_secret_access_key=$3
region=$4
s3_bucket="cmtr-79e2b04a-cloudfront-sswo-bucket-179026"
cloudfront_dist_name="cmtr-79e2b04a-cloudfront-sswo-distribution"
oai_name="cmtr-79e2b04a-cloudfront-sswo-oai"
index_file="index.html"
error_file="error.html"
nonexistent_page="database.html"

# Function to configure AWS profile
aws_profile_config() {
    aws configure set aws_access_key_id $2 --profile $1
    aws configure set aws_secret_access_key $3 --profile $1
    aws configure set region $4 --profile $1
}

# Function to get CloudFront OAI ID
get_oai_id() {
    aws cloudfront list-cloud-front-origin-access-identities --profile $aws_profile \
    --query "CloudFrontOriginAccessIdentityList.Items[?Comment=='$oai_name'].Id" --output text
}

# Function to update CloudFront with OAI
update_cloudfront_with_oai() {
    oai_id=$(get_oai_id)
    if [ -z "$oai_id" ]; then
        echo "Error: OAI not found!"
        exit 1
    fi

    # Get CloudFront distribution config
    distribution_id=$(aws cloudfront list-distributions --profile $aws_profile \
    --query "DistributionList.Items[?Aliases.Items[?contains(@, '$cloudfront_dist_name')]].Id" --output text)
    
    if [ -z "$distribution_id" ]; then
        echo "Error: CloudFront distribution not found!"
        exit 1
    fi

    # Get the current distribution config ETag
    etag=$(aws cloudfront get-distribution-config --id $distribution_id --profile $aws_profile --query 'ETag' --output text)

    # Update the distribution with OAI
    aws cloudfront update-distribution --id $distribution_id --profile $aws_profile \
    --distribution-config "$(aws cloudfront get-distribution-config --id $distribution_id --profile $aws_profile | \
    jq ".DistributionConfig.Origins.Items[0].S3OriginConfig.OriginAccessIdentity=\"origin-access-identity/cloudfront/$oai_id\"")" \
    --if-match $etag
}

# Function to configure custom error response in CloudFront
configure_custom_error_response() {
    distribution_id=$(aws cloudfront list-distributions --profile $aws_profile \
    --query "DistributionList.Items[?Aliases.Items[?contains(@, '$cloudfront_dist_name')]].Id" --output text)
    
    etag=$(aws cloudfront get-distribution-config --id $distribution_id --profile $aws_profile --query 'ETag' --output text)

    aws cloudfront update-distribution --id $distribution_id --profile $aws_profile \
    --distribution-config "$(aws cloudfront get-distribution-config --id $distribution_id --profile $aws_profile | \
    jq '.DistributionConfig.CustomErrorResponses.Items += [{"ErrorCode": 403, "ResponsePagePath": "/error.html", "ResponseCode": "404", "ErrorCachingMinTTL": 300}]')" \
    --if-match $etag
}

# Function to restrict S3 bucket access and grant OAI permissions
restrict_s3_bucket_access() {
    oai_id=$(get_oai_id)
    if [ -z "$oai_id" ]; then
        echo "Error: OAI not found!"
        exit 1
    fi

    # Block public access to the S3 bucket
    aws s3api put-bucket-policy --bucket $s3_bucket --profile $aws_profile \
    --policy "{
        \"Version\": \"2012-10-17\",
        \"Statement\": [
            {
                \"Sid\": \"AllowCloudFrontAccess\",
                \"Effect\": \"Allow\",
                \"Principal\": {
                    \"AWS\": \"arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity $oai_id\"
                },
                \"Action\": \"s3:GetObject\",
                \"Resource\": \"arn:aws:s3:::$s3_bucket/*\"
            }
        ]
    }"
}

# Function to perform health checks
perform_health_checks() {
    s3_website_url=$(aws s3api get-bucket-website --bucket $s3_bucket --profile $aws_profile --query "[WebsiteConfiguration.IndexDocument.Suffix]" --output text)
    cloudfront_domain=$(aws cloudfront list-distributions --profile $aws_profile \
    --query "DistributionList.Items[?Aliases.Items[?contains(@, '$cloudfront_dist_name')]].DomainName" --output text)
    
    echo "Checking S3 access..."
    curl -I $s3_website_url
    echo "Checking CloudFront access..."
    curl -I https://$cloudfront_domain/$index_file
    echo "Checking CloudFront error response..."
    curl -I https://$cloudfront_domain/$nonexistent_page
}

# Execute the functions
aws_profile_config $aws_profile $aws_access_key_id $aws_secret_access_key $region
update_cloudfront_with_oai
configure_custom_error_response
restrict_s3_bucket_access
perform_health_checks
