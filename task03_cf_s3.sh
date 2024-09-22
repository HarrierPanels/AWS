#!/bin/bash

# Variables
aws_profile=$1
aws_access_key=$2
aws_secret_key=$3
aws_region=$4
s3_bucket="cmtr-79e2b04a-cloudfront-sswo-bucket-179026"
cloudfront_dist="cmtr-79e2b04a-cloudfront-sswo-distribution"
oai_id="cmtr-79e2b04a-cloudfront-sswo-oai"
nonexistent_page="database.html"
error_page="error.html"

# Function to configure AWS profile
aws_profile_config() {
    aws configure set aws_access_key_id $aws_access_key --profile $aws_profile
    aws configure set aws_secret_access_key $aws_secret_key --profile $aws_profile
    aws configure set region $aws_region --profile $aws_profile
}

# Function to add OAI to CloudFront distribution
add_oai_to_distribution() {
    echo "Adding OAI to CloudFront distribution..."
    aws cloudfront update-distribution --id $cloudfront_dist --profile $aws_profile --default-root-object index.html --distribution-config '{
        "Origins": {
            "Items": [
                {
                    "Id": "S3-origin",
                    "DomainName": "'"$s3_bucket"'.s3.amazonaws.com",
                    "S3OriginConfig": {
                        "OriginAccessIdentity": "origin-access-identity/cloudfront/'"$oai_id"'"
                    }
                }
            ],
            "Quantity": 1
        }
    }'
}

# Function to configure error page for CloudFront distribution
configure_error_page() {
    echo "Configuring CloudFront error page..."
    aws cloudfront update-distribution --id $cloudfront_dist --profile $aws_profile --distribution-config '{
        "CustomErrorResponses": {
            "Items": [
                {
                    "ErrorCode": 403,
                    "ResponsePagePath": "/'"$error_page"'",
                    "ResponseCode": "404",
                    "ErrorCachingMinTTL": 300
                }
            ],
            "Quantity": 1
        }
    }'
}

# Function to restrict public access to the S3 bucket
restrict_s3_bucket_access() {
    echo "Restricting public access to S3 bucket..."
    aws s3api put-bucket-policy --bucket $s3_bucket --policy '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "AllowCloudFrontAccess",
                "Effect": "Allow",
                "Principal": {
                    "AWS": "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity '"$oai_id"'"
                },
                "Action": "s3:GetObject",
                "Resource": "arn:aws:s3:::'"$s3_bucket"'/*"
            }
        ]
    }' --profile $aws_profile
}

# Function to verify health checks
verify_healthchecks() {
    echo "Verifying health checks..."

    # Check S3 bucket access
    s3_website_url=$(aws s3api get-bucket-website --bucket $s3_bucket --query 'WebsiteConfiguration.IndexDocument.Suffix' --output text --profile $aws_profile)
    echo "S3 Website URL: $s3_website_url"
    s3_test=$(curl -s -o /dev/null -w "%{http_code}" "http://$s3_bucket.s3-website.$aws_region.amazonaws.com/")

    if [ "$s3_test" == "403" ]; then
        echo "S3 bucket access is correctly restricted!"
    else
        echo "S3 bucket is publicly accessible, check the configuration."
    fi

    # Get CloudFront domain
    cloudfront_domain=$(aws cloudfront get-distribution --id $cloudfront_dist --query 'Distribution.DomainName' --output text --profile $aws_profile)
    echo "CloudFront Domain: $cloudfront_domain"

    # Check CloudFront access to index.html
    cloudfront_test=$(curl -s -o /dev/null -w "%{http_code}" "https://$cloudfront_domain/")
    if [ "$cloudfront_test" == "200" ]; then
        echo "CloudFront distribution serves index.html successfully!"
    else
        echo "CloudFront access to index.html failed."
    fi

    # Check CloudFront custom error page
    error_test=$(curl -s -o /dev/null -w "%{http_code}" "https://$cloudfront_domain/$nonexistent_page")
    if [ "$error_test" == "404" ]; then
        echo "Custom error page (error.html) is returned successfully for non-existent pages!"
    else
        echo "Error page configuration failed."
    fi
}

# Execute all tasks
aws_profile_config
add_oai_to_distribution
configure_error_page
restrict_s3_bucket_access
verify_healthchecks

echo "Task completed successfully!"
