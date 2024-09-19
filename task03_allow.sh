#!/bin/bash

# Get AWS Configuration Variables
source_file=".env"
. "$source_file"

# Resource Variables
iam_role="cmtr-79e2b04a-iam-pela-iam_role"
s3_bucket_1="cmtr-79e2b04a-iam-pela-bucket-1-951900"
s3_bucket_2="cmtr-79e2b04a-iam-pela-bucket-2-951900"
iam_role_policy_name="allow_list_buckets"

# Function to configure AWS profile
aws_profile_config() {
    aws configure set aws_access_key_id $2 --profile $1
    aws configure set aws_secret_access_key $3 --profile $1
    aws configure set region $4 --profile $1
}

# Configuring AWS profile
aws_profile_config $aws_profile $aws_access_key_id $aws_secret_access_key $aws_region
echo "Profile $aws_profile configured ..."

# Get IAM role ARN
iam_role_arn=$(aws iam get-role --role-name $iam_role --query 'Role.Arn' --output text --profile $aws_profile)
echo "Getting IAM role ARN: $iam_role_arn"

# Create IAM policy for listing buckets
echo "Creating IAM policy JSON file for listing buckets"

cat <<EOF > policy.json
{
    "Version": "2012-10-17",
    "Statement": {
        "Effect": "Allow",
        "Action": ["s3:ListAllMyBuckets"],
        "Resource": "*"
    }
}
EOF

# Attach policy to IAM role
aws iam put-role-policy --role-name $iam_role --policy-name $iam_role_policy_name --policy-document file://policy.json --profile $aws_profile
echo "Policy attached ..."

# Create S3 bucket policy
cat <<EOF > bucket-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "allowGetPutList",
            "Principal": {
                "AWS": "$iam_role_arn"
            },
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::$s3_bucket_1",
                "arn:aws:s3:::$s3_bucket_1/*"
            ]
        }
    ]
}
EOF
echo "S3 bucket policy JSON file created"

# Apply bucket policy to S3 bucket
aws s3api put-bucket-policy --bucket $s3_bucket_1 --policy file://bucket-policy.json --profile $aws_profile
echo "Bucket policy applied to S3 bucket"

# Health Check Functions (Conceptual)

# Function to assume role
assume_role() {
    local role_arn=$(aws iam get-role --role-name $iam_role --query 'Role.Arn' --output text --profile $aws_profile)

    local assume_role_output=$(aws sts assume-role \
        --role-arn $role_arn \
        --role-session-name "AssumeRoleSession" \
        --profile $aws_profile)

    export AWS_ACCESS_KEY_ID=$(echo $assume_role_output | jq -r '.Credentials.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo $assume_role_output | jq -r '.Credentials.SecretAccessKey')
}

# Function to list all buckets
list_all_buckets() {
    aws s3 ls --profile $aws_profile
}

# Function to check access to bucket 1
check_bucket_1_access() {

    # Attempt to delete a test file
    local test_file="test-file.txt"
    local test_file_dwnld="test-file-downloaded.txt"
    echo "This is a test file." > $test_file

    aws s3 ls s3://$s3_bucket_1 --profile $aws_profile
    aws s3 cp $test_file s3://$s3_bucket_1/$test_file --profile $aws_profile
    aws s3 cp s3://$s3_bucket_1/$test_file $test_file_dwnld --profile $aws_profile
}

# Function to check access to bucket 2
check_bucket_2_access() {

    # Attempt to delete a test file
    local test_file="test-file.txt"
    local test_file_dwnld="test-file-downloaded.txt"
    echo "This is a test file." > $test_file

    aws s3 ls s3://$s3_bucket_2 --profile $aws_profile
    aws s3 cp $test_file s3://$s3_bucket_2/$test_file --profile $aws_profile
    aws s3 cp s3://$s3_bucket_2/$test_file $test_file_dwnld --profile $aws_profile
}

# Main script
echo "Assuming role..."
assume_role

# echo "Checking list buckets permission..."
list_all_buckets

# echo "Checking access to bucket 1..."
check_bucket_1_access

# echo "Checking access to bucket 2..."
check_bucket_2_access

# Clean up test file
rm -f $test_file $test_file_dwnld

echo "Health checks completed."
