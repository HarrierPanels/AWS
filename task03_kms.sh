#!/bin/bash

# Get AWS Configuration Variables
source_file=".env"
. "$source_file"

# Resource Variables
iam_role="cmtr-79e2b04a-iam-sewk-iam_role"
s3_bucket_1="cmtr-79e2b04a-iam-sewk-bucket-7799810-1"
s3_bucket_2="cmtr-79e2b04a-iam-sewk-bucket-7799810-2"
kms_key_arn="arn:aws:kms:us-east-1:242201266106:key/d01c7f83-6d01-45e1-aa3f-c945427a0ee9"
s3_file="confidential_credentials.csv"
iam_role_policy_name="AllowAccessToKMSKey"

# Function to configure AWS profile
aws_profile_config() {
    aws configure set aws_access_key_id $2 --profile $1
    aws configure set aws_secret_access_key $3 --profile $1
    aws configure set region $4 --profile $1
}

# Function to update IAM role policy
update_iam_role_policy() {
    cat <<EOF > iam-role-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "kms:Encrypt",
                "kms:Decrypt",
                "kms:ReEncrypt*",
                "kms:GenerateDataKey*",
                "kms:DescribeKey"
            ],
            "Resource": "${kms_key_arn}"
        }
    ]
}
EOF
    aws iam put-role-policy --role-name $iam_role --policy-name $iam_role_policy_name --policy-document file://iam-role-policy.json --profile $aws_profile
}

# Function to enable server-side encryption for the bucket
enable_server_side_encryption() {
    aws s3api put-bucket-encryption --bucket $s3_bucket_2 --server-side-encryption-configuration \
    '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "aws:kms",
                    "KMSMasterKeyID": "'"$kms_key_arn"'"
                },
                "BucketKeyEnabled": false
            }
        ]
    }' --profile $aws_profile
}

# Function to copy file from one bucket to another
copy_file_between_buckets() {
    aws s3 cp s3://$s3_bucket_1/$s3_file s3://$s3_bucket_2/$s3_file \
    --sse aws:kms \
    --sse-kms-key-id $kms_key_arn \
    --profile $aws_profile
}

# Health check function
health_check() {
    # Verify the object encryption
    local encryption_info=$(aws s3api head-object --bucket $s3_bucket_2 --key $s3_file --profile $aws_profile)
    local encryption_type=$(echo $encryption_info | jq -r '.ServerSideEncryption')
    local kms_key_id=$(echo $encryption_info | jq -r '.SSEKMSKeyId')

    echo "Object Encryption Type: $encryption_type"
    echo "KMS Key ID: $kms_key_id"

    # Extract Key ID from the KMS Key ARN
    local kms_key_id_from_arn="${kms_key_arn##*:}"

    if [[ "$encryption_type" =~ "aws:kms" ]] && [[ "$kms_key_id" =~ "$kms_key_id_from_arn" ]]; then
        echo "Encryption verification passed."
    else
        echo "Encryption verification failed."
    fi
    # Check KMS permissions
    assume_role $iam_role
    aws kms list-keys --profile $aws_profile
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

# Main script
aws_profile_config $aws_profile $aws_access_key_id $aws_secret_access_key $aws_region
echo "AWS profile $aws_profile configured ..."

echo "Updating IAM role policy..."
update_iam_role_policy

echo "Enabling server-side encryption for the bucket..."
enable_server_side_encryption

echo "Copying file between buckets..."
copy_file_between_buckets

echo "Running health check..."
health_check
