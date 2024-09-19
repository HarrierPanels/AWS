#!/bin/bash

# Get AWS Configuration Variables
source_file=".env"
. "$source_file"

# Resource Variables
assume_role="cmtr-79e2b04a-iam-ar-iam_role-assume"
readonly_role="cmtr-79e2b04a-iam-ar-iam_role-readonly"
readonly_role_policy_name="ReadOnlyAccess"
assume_role_policy_name="assume_role_permissions"

# Function to configure AWS profile
aws_profile_config() {
    aws configure set aws_access_key_id $2 --profile $1
    aws configure set aws_secret_access_key $3 --profile $1
    aws configure set region $4 --profile $1
}

# Function to assume role and set AWS credentials
assume_role() {
    local role_arn=$(aws iam get-role --role-name $1 --query 'Role.Arn' --output text --profile $aws_profile)

    local assume_role_output=$(aws sts assume-role \
        --role-arn $role_arn \
        --role-session-name "AssumeRoleSession" \
        --profile $aws_profile)

    export AWS_ACCESS_KEY_ID=$(echo $assume_role_output | jq -r '.Credentials.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo $assume_role_output | jq -r '.Credentials.SecretAccessKey')
}

# Function to update the role policy
update_assume_role_policy() {
    local role_arn=$(aws iam get-role --role-name $assume_role --query 'Role.Arn' --output text --profile $aws_profile)
    cat <<EOF > assume-role-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Resource": "*"
        }
    ]
}
EOF
    aws iam put-role-policy --role-name $assume_role --policy-name $assume_role_policy_name --policy-document file://assume-role-policy.json --profile $aws_profile
    echo $role_arn
}

# Function to attach read-only access policy to IAM role
attach_readonly_policy() {
    aws iam attach-role-policy --role-name $readonly_role --policy-arn arn:aws:iam::aws:policy/$readonly_role_policy_name --profile $aws_profile
}

# Function to update trust policy for the readonly role
update_trust_policy() {
    local role_arn=$1
    cat <<EOF > trust-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "$role_arn"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
    aws iam update-assume-role-policy --role-name $readonly_role --policy-document file://trust-policy.json --profile $aws_profile
}

# Health check function
health_check() {
    assume_role $assume_role

    # Check if assume_role can assume other roles
    aws sts assume-role --role-arn $(aws iam get-role --role-name $readonly_role --query 'Role.Arn' --output text --profile $aws_profile) --role-session-name "TestAssumeRoleSession" --profile $aws_profile

    # Check if readonly_role can perform read-only actions
    assume_role $readonly_role

    # Attempt to list S3 buckets (read-only action)
    aws s3 ls --profile $aws_profile

    # Attempt to create an S3 bucket (write action, should fail)
    aws s3 mb s3://test-bucket --profile $aws_profile
}

# Main script
aws_profile_config $aws_profile $aws_access_key_id $aws_secret_access_key $aws_region
echo "AWS profile $aws_profile configured"

echo "Updating assume role policy..."
assume_role_arn=$(update_assume_role_policy)

echo "Attaching read-only access policy to readonly role..."
attach_readonly_policy

echo "Updating trust policy for readonly role..."
update_trust_policy $assume_role_arn

# echo "Running health check..."
health_check

