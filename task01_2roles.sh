#!/bin/bash

# Get AWS Configuration Variables
source_file=".env"
. "$source_file"

# Resource Variables
iam_role_readonly="cmtr-79e2b04a-iam-mp-iam_role-readonly"
iam_role_administrator="cmtr-79e2b04a-iam-mp-iam_role-administrator"
trust_policy_file="trust-policy.json"
task_name="Using AWS Managed Policies for IAM Resources"

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

    # Check if Read-Only Role exists
    if aws iam get-role --role-name $iam_role_readonly > /dev/null 2>&1; then
        echo "Read-Only Role $iam_role_readonly already exists, attaching policy."
        aws iam attach-role-policy --role-name $iam_role_readonly --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess
    else
        aws iam create-role --role-name $iam_role_readonly --assume-role-policy-document file://$trust_policy_file
        aws iam attach-role-policy --role-name $iam_role_readonly --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess
        echo "Read-Only Role $iam_role_readonly created and policy attached."
    fi

    # Check if Administrator Role exists
    if aws iam get-role --role-name $iam_role_administrator > /dev/null 2>&1; then
        echo "Administrator Role $iam_role_administrator already exists, attaching policy."
        aws iam attach-role-policy --role-name $iam_role_administrator --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
    else
        aws iam create-role --role-name $iam_role_administrator --assume-role-policy-document file://$trust_policy_file
        aws iam attach-role-policy --role-name $iam_role_administrator --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
        echo "Administrator Role $iam_role_administrator created and policy attached."
    fi

    echo "Press the 'Validate' button with 'Check CLI usage' checked (located above the 'Validate' button)!"
    sleep 10
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

# Function to validate and delete IAM roles
validate_and_delete_iam_roles() {
    local retries=30
    local count=0

    while [ $count -lt $retries ]; do
        echo "Checking if roles exist, attempt $((count+1))..."

        readonly_check=$(aws iam get-role --role-name $iam_role_readonly 2>/dev/null)
        admin_check=$(aws iam get-role --role-name $iam_role_administrator 2>/dev/null)

        if [[ -z "$readonly_check" && -z "$admin_check" ]]; then
            echo "Both roles do not exist. Validation successful."
            delete_trust_policy_file
            echo "The '$task_name' task complete! Exiting ..."
            return 0
        fi

        echo "Roles still exist. Retrying in 10 seconds..."
        sleep 10
        count=$((count+1))
    done

    echo "Out of retries. Deleting IAM roles."
    delete_iam_roles
}

# Function to delete IAM roles
delete_iam_roles() {
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
    # Validate and delete IAM roles after health check success
    validate_and_delete_iam_roles
else
    echo "Health check failed. Exiting script."
    exit 1
fi
