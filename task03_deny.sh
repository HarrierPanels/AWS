#!/bin/bash

# Get AWS Configuration Variables
source_file=".env"
. "$source_file"

# Resource Variables
iam_role="cmtr-79e2b04a-iam-peld-iam_role"
s3_bucket="cmtr-79e2b04a-iam-peld-bucket-5830567"
iam_role_policy_name="AmazonS3FullAccess"

# Function to configure AWS CLI profile
aws_profile_config() {
    aws configure --profile $1 set aws_access_key_id $2
    aws configure --profile $1 set aws_secret_access_key $3
    aws configure --profile $1 set region $4
}

# Function to assume role and set AWS credentials
assume_role() {
    local role_arn=$(aws iam get-role --role-name $iam_role --query 'Role.Arn' --output text --profile $aws_profile)

    local assume_role_output=$(aws sts assume-role \
        --role-arn $role_arn \
        --role-session-name "AssumeRoleSession" \
        --profile $aws_profile)

    export AWS_ACCESS_KEY_ID=$(echo $assume_role_output | jq -r '.Credentials.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo $assume_role_output | jq -r '.Credentials.SecretAccessKey')
}

# Function to attach full access policy to IAM role
attach_full_access_policy() {
    local role_arn=$(aws iam get-role --role-name $iam_role --query 'Role.Arn' --output text --profile $aws_profile)
    aws iam attach-role-policy --role-name $iam_role --policy-arn arn:aws:iam::aws:policy/$iam_role_policy_name --profile $aws_profile
}

# Function to update S3 bucket policy with deny delete
update_s3_bucket_policy() {
    local role_arn=$(aws iam get-role --role-name $iam_role --query 'Role.Arn' --output text --profile $aws_profile)

    local new_policy=$(jq -n --arg role_arn "$role_arn" --arg bucket "arn:aws:s3:::$s3_bucket/*" '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "DenyDeleteObjects",
                "Effect": "Deny",
                "Principal": {
                    "AWS": $role_arn
                },
                "Action": "s3:DeleteObject",
                "Resource": [$bucket]
            }
        ]
    }')

    aws s3api put-bucket-policy --bucket $s3_bucket --policy "$new_policy" --profile $aws_profile
}

# Function to check if the IAM role can delete objects in the bucket
health_check() {
    assume_role

    # Attempt to delete a test file
    local test_file="test-file.txt"
    echo "This is a test file." > $test_file
    aws s3 cp $test_file s3://$s3_bucket/ --profile $aws_profile
    aws s3 rm s3://$s3_bucket/$test_file --profile $aws_profile
}

# Main script
echo "Configuring AWS Profile $aws_profile ..."
aws_profile_config $aws_profile $aws_access_key_id $aws_secret_access_key $aws_session_token $aws_region

echo "Attaching full access policy to IAM role..."
attach_full_access_policy

echo "Updating S3 bucket policy to deny delete objects..."
update_s3_bucket_policy

# echo "Running health check..."
health_check
