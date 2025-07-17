# AWS Setup for TaskChamp

## Step 1: Get AWS Credentials from AWS Console
1. Go to https://console.aws.amazon.com/
2. Go to IAM > Users > Create User
3. Name: taskchamp-sync
4. Attach AmazonS3FullAccess policy
5. Create access key for CLI
6. Copy Access Key ID and Secret Access Key

## Step 2: Configure AWS CLI
Run: aws configure

Enter:
- AWS Access Key ID: <your-access-key>
- AWS Secret Access Key: <your-secret-key>
- Default region: us-west-2
- Default output format: json

## Step 3: Create S3 Bucket
I'll help create this once configured!

