[![EPAM](https://img.shields.io/badge/Cloud%20Mentor:%20AWS%20Security%20Tasks-Using%20AWS%20Managed%20Policies%20for%20IAM%20Resources-orange)](./)
<br>
---

## AWS IAM Role Management Script

This Bash script automates the creation, validation, and deletion of AWS IAM roles using managed policies. It includes functions to configure AWS profiles, create and delete trust policy files, and manage IAM roles.

### Script Overview

```bash
#!/bin/bash

# Get AWS Configuration Variables
source_file=".env"
. "$source_file"

# Resource Variables
iam_role_readonly="cmtr-79e2b04a-iam-mp-iam_role-readonly"
iam_role_administrator="cmtr-79e2b04a-iam-mp-iam_role-administrator"
trust_policy_file="trust-policy.json"
task_name="Using AWS Managed Policies for IAM Resources"
```

### Functions

#### 1. `aws_profile_config()`
Configures the AWS CLI profile with the provided access key, secret key, and region.

```bash
aws_profile_config() {
    aws configure set aws_access_key_id $2 --profile $1
    aws configure set aws_secret_access_key $3 --profile $1
    aws configure set region $4 --profile $1
    echo "Profile $1 configured ..."
}
```

#### 2. `create_trust_policy_file()`
Creates a trust policy file for the IAM roles.

```bash
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
```

#### 3. `delete_trust_policy_file()`
Deletes the trust policy file.

```bash
delete_trust_policy_file() {
    rm -f $trust_policy_file
    echo "Trust policy file deleted."
}
```

#### 4. `create_iam_roles()`
Creates the IAM roles if they do not already exist and attaches the appropriate policies.

```bash
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

    echo "Press the 'Verify' button with 'Check CLI usage' checked (located right above the 'Verify' button)!"
    sleep 10
}
```

#### 5. `healthcheck_iam_roles()`
Performs a health check on the IAM roles to ensure they exist.

```bash
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
```

#### 6. `validate_and_delete_iam_roles()`
Validates that the roles no longer exist and deletes the trust policy file. If roles still exist after retries, it deletes the IAM roles.

```bash
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
            echo "The '$task_name' task is complete! Exiting ..."
            return 0
        fi

        echo "Roles still exist. Retrying in 10 seconds..."
        sleep 10
        count=$((count+1))
    done

    echo "Out of retries. Deleting IAM roles."
    delete_iam_roles
}
```

#### 7. `delete_iam_roles()`
Deletes the IAM roles and detaches the policies.

```bash
delete_iam_roles() {
    aws iam detach-role-policy --role-name $iam_role_readonly --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess
    aws iam delete-role --role-name $iam_role_readonly
    echo "Read-Only Role $iam_role_readonly deleted."

    aws iam detach-role-policy --role-name $iam_role_administrator --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
    aws iam delete-role --role-name $iam_role_administrator
    echo "Administrator Role $iam_role_administrator deleted."

    delete_trust_policy_file
}
```

### Main Script Execution

1. **Configure AWS Profile**
2. **Create IAM Roles**
3. **Perform Health Check**
4. **Validate and Delete IAM Roles**

```bash
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
```

---

This script ensures that AWS IAM roles are managed efficiently, with checks in place to avoid redundant role creation and to validate the existence of roles before deletion. Let me know if you need any further details or adjustments!
