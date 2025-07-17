# R2 Configuration for TaskChamp

## Created Resources:
- Account ID: 57398029d3d0add95bdad89deaa41864
- Bucket Name: taskchamp
- Bucket Location: WNAM (Western North America)
- R2 Endpoint: https://57398029d3d0add95bdad89deaa41864.r2.cloudflarestorage.com

## Next Steps:
1. Go to https://dash.cloudflare.com/profile/api-tokens
2. Create Custom Token with Account:Cloudflare R2:Edit permission
3. Set these environment variables:

export R2_ACCOUNT_ID=57398029d3d0add95bdad89deaa41864
export R2_BUCKET_NAME=taskchamp
export R2_ENDPOINT=https://57398029d3d0add95bdad89deaa41864.r2.cloudflarestorage.com
export R2_ACCESS_KEY_ID=<your-token-from-step-2>
export R2_SECRET_ACCESS_KEY=<your-token-from-step-2>

