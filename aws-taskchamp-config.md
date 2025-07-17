# TaskChamp AWS S3 Configuration

## ✅ Resources Created:
- AWS Account ID: 242650470301
- S3 Bucket Name: taskchamp-sync-242650470301
- Region: us-east-1
- Bucket ARN: arn:aws:s3:::taskchamp-sync-242650470301

## 📱 For TaskChamp App - AWS Sync Settings:

**S3 Bucket Name:** taskchamp-sync-242650470301
**Region:** us-east-1
**Access Key ID:** (from your AWS CLI configuration)
**Secret Access Key:** (from your AWS CLI configuration)

## 🔧 Environment Variables (for testing):
export AWS_REGION=us-east-1
export AWS_S3_BUCKET=taskchamp-sync-242650470301
export AWS_ACCESS_KEY_ID=<your-access-key>
export AWS_SECRET_ACCESS_KEY=<your-secret-key>

## 📝 GitHub Secrets (for CI/CD):
Add these to your GitHub repository secrets:
- AWS_REGION: us-east-1
- AWS_S3_BUCKET: taskchamp-sync-242650470301
- AWS_ACCESS_KEY_ID: <your-access-key>
- AWS_SECRET_ACCESS_KEY: <your-secret-key>

## 🧪 Test Commands:
# List bucket contents
aws s3 ls s3://taskchamp-sync-242650470301/

# Upload test file
echo 'test' > test.txt && aws s3 cp test.txt s3://taskchamp-sync-242650470301/

# Download test file
aws s3 cp s3://taskchamp-sync-242650470301/test.txt downloaded.txt

