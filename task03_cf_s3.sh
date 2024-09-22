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

# Step 1: Retrieve OAI ID for the given OAI name
get_oai_id() {
    oai_id=$(aws cloudfront list-cloud-front-origin-access-identities --query "CloudFrontOriginAccessIdentityList.Items[?Comment=='$oai_name'].Id" --output text --profile $aws_profile)
    if [ -z "$oai_id" ]; then
        echo "Error: Unable to retrieve OAI ID for $oai_name"
        exit 1
    fi
    echo "Retrieved OAI ID: $oai_id"
}

# Step 2: Retrieve CloudFront distribution ID based on the description
get_distribution_id() {
    distribution_id=$(aws cloudfront list-distributions --query "DistributionList.Items[?Comment=='$cloudfront_desc'].Id" --output text --profile $aws_profile)
    if [ -z "$distribution_id" ]; then
        echo "Error: Unable to retrieve CloudFront distribution ID for $cloudfront_desc"
        exit 1
    fi
    echo "Retrieved CloudFront Distribution ID: $distribution_id"
}

# Step 3: Attach OAI to CloudFront distribution
attach_oai_to_distribution() {
    aws cloudfront update-distribution \
        --id $distribution_id \
        --default-root-object index.html \
        --origins Items=[{Id=S3Origin,DomainName=$bucket_name.s3.amazonaws.com,S3OriginConfig={OriginAccessIdentity=origin-access-identity/cloudfront/$oai_id}}] \
        --profile $aws_profile
    echo "OAI attached to CloudFront distribution."
}

# Step 4: Update CloudFront error page response
update_cloudfront_error_page() {
    aws cloudfront update-distribution \
        --id $distribution_id \
        --default-root-object index.html \
        --custom-error-responses Quantity=1,Items=[{ErrorCode=403,ResponsePagePath=/error.html,ResponseCode=404,ErrorCachingMinTTL=300}] \
        --profile $aws_profile
    echo "Updated CloudFront custom error response."
}

# Step 5: Restrict public access to the S3 bucket
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

# Step 6: Grant OAI read permissions on the S3 bucket
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

# Step 7: Health check - ensure S3 URLs return AccessDenied
check_s3_access() {
    s3_website_url=$(aws s3api get-bucket-website --bucket $bucket_name --query "[WebsiteConfiguration.IndexDocument.Suffix]" --output text --profile $aws_profile)
    echo "Performing health check on S3 bucket..."
    curl -I $s3_website_url
}

# Step 8: Health check - ensure CloudFront delivers content via OAI
check_cloudfront_access() {
    cloudfront_domain=$(aws cloudfront list-distributions --query "DistributionList.Items[?Comment=='$cloudfront_desc'].DomainName" --output text --profile $aws_profile)
    echo "Performing health check on CloudFront..."
    curl -I "https://$cloudfront_domain/$nonexistent_page"
}

# Main Execution
aws_profile_config
get_oai_id
get_distribution_id
attach_oai_to_distribution
update_cloudfront_error_page
restrict_bucket_access
grant_oai_s3_permissions
check_s3_access
check_cloudfront_access
