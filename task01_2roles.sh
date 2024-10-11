#!/bin/bash

# Get AWS Configuration Variables
source_file=".env"
. "$source_file"

# Resource Variables
iam_role_readonly="iam_role_readonly"
iam_role_administrator="iam_role_administrator"
trust_policy_file="trust-policy.json"

# Function to configure AWS profile
aws_profile_config() {
    aws configure set aws_access_key_id $2 --profile $1
    aws configure set aws_secret_access_key $3 --profile $1
    aws configure set region $4 --profile $1
    echo "Profile $1 configured ..."
}

# Function to create trust policy file
create_trust_policy_file() {
    cat <<EOF > $trust_policy_file
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
    echo "Trust policy file created."
}

# Function to delete trust policy file
delete_trust_policy_file() {
    rm -f $trust_policy_file
    echo "Trust policy file deleted."
}

# Function to create IAM roles
create_iam_roles() {
    create_trust_policy_file

    # Create Read-Only Role
    aws iam create-role --role-name $iam_role_readonly --assume-role-policy-document file://$trust_policy_file
    aws iam attach-role-policy --role-name $iam_role_readonly --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess
    echo "Read-Only Role $iam_role_readonly created and policy attached."

    # Create Administrator Role
    aws iam create-role --role-name $iam_role_administrator --assume-role-policy-document file://$trust_policy_file
    aws iam attach-role-policy --role-name $iam_role_administrator --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
    echo "Administrator Role $iam_role_administrator created and policy attached."
}

# Function to perform health check on IAM roles
healthcheck_iam_roles() {
    local retries=5
    local count=0

    while [ $count -lt $retries ]; do
        echo "Performing health check, attempt $((count+1))..."

        readonly_check=$(aws iam get-role --role-name $iam_role_readonly)
        admin_check=$(aws iam get-role --role-name $iam_role_administrator)

        if [[ -n "$readonly_check" && -n "$admin_check" ]]; then
            echo "Health check successful for both roles."
            return 0
        fi

        echo "Health check failed. Retrying in 5 seconds..."
        sleep 5
        count=$((count+1))
    done

    echo "Health check failed after $retries attempts."
    return 1
}

# Function to delete IAM roles
delete_iam_roles() {
    echo "Sleeping for 300 seconds before deleting roles..."
    sleep 300

    aws iam detach-role-policy --role-name $iam_role_readonly --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess
    aws iam delete-role --role-name $iam_role_readonly
    echo "Read-Only Role $iam_role_readonly deleted."

    aws iam detach-role-policy --role-name $iam_role_administrator --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
    aws iam delete-role --role-name $iam_role_administrator
    echo "Administrator Role $iam_role_administrator deleted."

    delete_trust_policy_file
}

# Configuring AWS profile
aws_profile_config $aws_profile $aws_access_key_id $aws_secret_access_key $aws_region

# Create IAM roles
create_iam_roles

# Perform health check
if healthcheck_iam_roles; then
    # Delete IAM roles after health check success
    delete_iam_roles
else
    echo "Health check failed. Exiting script."
    exit 1
fi
