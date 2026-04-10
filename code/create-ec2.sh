#!/bin/bash


VPC_ID="vpc-0e56a55aa56188a47"
POSIT_TAGS="{Key=rs:project,Value=solutions}, \
            {Key=rs:environment,Value=development}, \
            {Key=rs:owner,Value=michael.mayer@posit.co}"

AMI_ID="ami-05a40a9d755b0f73a" 
AMI_ID="ami-09f73ba1beba9ad07"

SUBNET_ID="subnet-08a17fc2026b879b6" 

SG_ID=`aws ec2 create-security-group \
    --group-name ssh-wb-sg \
    --description "SG for Workbench (port 8787) and SSH (port 22) access" \
    --tag-specifications "ResourceType=security-group,\
        Tags=[{Key=Name,Value=ssh-wb-sg},${POSIT_TAGS}]" \
    --vpc-id "${VPC_ID}" | jq -r '.GroupId' `

aws ec2 authorize-security-group-ingress \
    --group-id "${SG_ID}" \
    --protocol tcp \
    --port 8787 \
    --cidr "10.13.128.0/18"

aws ec2 authorize-security-group-ingress \
    --group-id "${SG_ID}" \
    --protocol tcp \
    --port 22 \
    --cidr "10.13.128.0/18"


aws ec2 run-instances \
    --subnet-id $SUBNET_ID \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type g5.2xlarge \
    --key-name michael.mayer@posit.co-keypair-for-pulumi \
    --security-group-ids $SG_ID \
    --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":100,\"DeleteOnTermination\":true}}]" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=rl9-gpu},${POSIT_TAGS}]" 'ResourceType=volume,Tags=[{Key=Name,Value=rl9-gpu-disk}]' \
    --user-data file://${PWD}/user-data.sh
