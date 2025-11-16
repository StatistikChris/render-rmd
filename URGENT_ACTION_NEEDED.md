# Immediate Action Required - Authentication Fix

## Current Situation
Your Cloud Run service is experiencing authentication errors:
```
"Invalid token" 
"No .httr-oauth file exists"
```

This means the service is still using the old version that tries R authentication instead of the minimal gsutil version.

## Root Cause
The deployment is still using the previous Docker image that has the authentication issues. The minimal version we created (which uses gsutil directly) hasn't been deployed yet because gcloud CLI is not available locally.

## Immediate Solutions

### OPTION 1: Deploy via Google Cloud Shell (RECOMMENDED)

1. **Open Google Cloud Shell**: https://shell.cloud.google.com

2. **Clone and deploy**:
```bash
git clone https://github.com/StatistikChris/render-rmd.git
cd render-rmd
export GOOGLE_CLOUD_PROJECT_ID=rapid-gadget-477511-n7
./deploy-minimal.sh
```

This will:
- Build a new Docker image with gsutil installed
- Use the minimal server that avoids R authentication
- Deploy with proper startup probe configuration

### OPTION 2: Quick Update (if rebuild not possible)

If you can't rebuild immediately, update the existing service:

```bash
gcloud run deploy rmd-to-pdf-service \
    --image gcr.io/rapid-gadget-477511-n7/rmd-to-pdf-service \
    --region europe-west1 \
    --update-env-vars GARGLE_OAUTH_CACHE=FALSE,GARGLE_QUIET=TRUE
```

### OPTION 3: Local Docker Build (if you have Docker)

```bash
# Build locally
docker build -t gcr.io/rapid-gadget-477511-n7/rmd-to-pdf-service .

# Push (requires gcloud auth)
docker push gcr.io/rapid-gadget-477511-n7/rmd-to-pdf-service

# Deploy
gcloud run deploy rmd-to-pdf-service \
    --image gcr.io/rapid-gadget-477511-n7/rmd-to-pdf-service \
    --region europe-west1
```

## Why This Happened

1. **Startup Probe Issue**: ✅ FIXED - Extended startup time to 5 minutes
2. **Authentication Issue**: ❌ STILL OCCURRING - Need to deploy minimal version

The authentication fix requires rebuilding the Docker image because:
- Current image: Uses `googleCloudStorageR` R package (interactive auth)
- Fixed image: Uses `gsutil` command (automatic Cloud Run auth)

## Expected Result After Fix

Once the minimal version is deployed, you should see:
```json
{
  "status": "healthy",
  "auth_method": "gsutil_minimal",
  "server_ready": true
}
```

## Urgency Level: HIGH

The service cannot process files until authentication is fixed. **Please use Cloud Shell (Option 1)** for the fastest resolution.

## Files Ready for Deployment

All files are ready in your repository:
- ✅ `server-minimal.R` - Server without R auth issues
- ✅ `process_rmd_minimal.R` - Processing with gsutil
- ✅ `deploy-minimal.sh` - Deploy script
- ✅ `Dockerfile` - Updated with gsutil installation

**Next Action**: Use Google Cloud Shell to run `./deploy-minimal.sh`