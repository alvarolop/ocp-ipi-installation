#!/bin/sh

source ./aws-env-vars

AWS_INSTANCE_NAME=rhel9

# Red Hat Enterprise Linux 9 (HVM), SSD Volume Type
AWS_INSTANCE_AMI="ami-05f804247228852a3"

# Instance type:
# - https://aws.amazon.com/ec2/instance-types   
# - https://aws.amazon.com/ec2/pricing/on-demand
# AWS_INSTANCE_TYPE="m7i.12xlarge" # $2.95/hour in eu-west-3
# AWS_INSTANCE_TYPE="c5.metal" # $4.97/hour in eu-west-3
AWS_INSTANCE_TYPE="m7i.xlarge" # Barata

# Print environment variables
echo -e "\n=============="
echo -e "ENVIRONMENT VARIABLES:"
echo -e " * AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID"
echo -e " * AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY"
echo -e " * AWS_DEFAULT_REGION: $AWS_DEFAULT_REGION"
echo -e " * AWS_INSTANCE_NAME: $AWS_INSTANCE_NAME"
echo -e " * AWS_INSTANCE_AMI: $AWS_INSTANCE_AMI"
echo -e " * AWS_INSTANCE_TYPE: $AWS_INSTANCE_TYPE"
echo -e "==============\n"

# Check if the AWS ClI is installed
if ! which aws &> /dev/null; then 
    echo "You need the AWS CLI to run this Quickstart, please, refer to the official documentation:"
    echo -e "\thttps://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi


# The following command lists all the subnets, filtering the only one that is public and also in the availability zone A and retrieves its SubnetId.
SUBNET_ID=$(aws ec2 describe-subnets \
    --region $AWS_DEFAULT_REGION \
    --filters Name=tag:Name,Values=*-public-${AWS_DEFAULT_REGION}a \
    --query "Subnets[*].SubnetId" \
    --output text)

SECURITY_GROUP=$(aws ec2 describe-security-groups \
    --region $AWS_DEFAULT_REGION \
    --filters Name=group-name,Values=default \
    --query "SecurityGroups[*].GroupId" \
    --output text)

echo "This is the SUBNET_ID: $SUBNET_ID"
echo "This is the SECURITY_GROUP: $SECURITY_GROUP"

# Create a  SSH Key Pair and store the Private Key locally
if aws ec2 describe-key-pairs --key-names $AWS_INSTANCE_NAME --region $AWS_DEFAULT_REGION &> /dev/null; then
    echo -e "Check. Key pair $AWS_INSTANCE_NAME already exists, do nothing."
else
    echo -e "Check. Creating Key pair $AWS_INSTANCE_NAME..."
    aws ec2 create-key-pair \
    --region $AWS_DEFAULT_REGION \
    --key-name $AWS_INSTANCE_NAME \
    --query 'KeyMaterial' \
    --output text > ~/.ssh/aws-$AWS_INSTANCE_NAME.pem

    chmod 400 ~/.ssh/aws-$AWS_INSTANCE_NAME.pem
fi

# Create a VM using the previous data
# 'ResourceType=volume,Tags=[{Key=Name,Value=test01-disk1}]' \
aws ec2 run-instances \
    --region $AWS_DEFAULT_REGION \
    --tag-specifications \
    "ResourceType=instance,Tags=[{Key=Name,Value=$AWS_INSTANCE_NAME}]" \
    --image-id $AWS_INSTANCE_AMI \
    --count 1 \
    --instance-type $AWS_INSTANCE_TYPE \
    --key-name $AWS_INSTANCE_NAME \
    --security-group-ids $SECURITY_GROUP \
    --subnet-id $SUBNET_ID \
    --output text


ALLOCATION_ID=$(aws ec2 allocate-address \
    --region $AWS_DEFAULT_REGION \
    --query 'AllocationId' \
    --output text)

echo "This is the ALLOCATION_ID: $ALLOCATION_ID"

aws ec2 create-tags \
    --region $AWS_DEFAULT_REGION \
    --resources $ALLOCATION_ID \
    --tags Key=Name,Value=$AWS_INSTANCE_NAME

INSTANCE_ID=$(aws ec2 describe-instances \
    --region $AWS_DEFAULT_REGION \
    --filters "Name=tag:Name,Values=$AWS_INSTANCE_NAME" \
    --query "Reservations[*].Instances[*].{Instance:InstanceId}" \
    --output text)

aws ec2 associate-address \
    --region $AWS_DEFAULT_REGION \
    --instance-id $INSTANCE_ID \
    --allocation-id $ALLOCATION_ID 

echo -e "Connect to the vm using the following command:"
echo -e "\t ssh -i ~/.ssh/aws-$AWS_INSTANCE_NAME.pem ec2-user@<public-ip>"
