# Manual Deployment Instructions

Since gcloud CLI is not available locally, you'll need to deploy using Google Cloud Console or Cloud Shell.

## Option 1: Deploy using Cloud Shell

1. Open [Google Cloud Shell](https://shell.cloud.google.com)

2. Clone your repository:
```bash
git clone https://github.com/StatistikChris/render-rmd.git
cd render-rmd
```

3. Set your project ID:
```bash
export GOOGLE_CLOUD_PROJECT_ID=rapid-gadget-477511-n7
```

4. Deploy the minimal version:
```bash
./deploy-minimal.sh
```

## Option 2: Deploy using existing build (Quick Fix)

If you want to quickly test without rebuilding, you can deploy just a new revision using the existing image but with updated environment variables:

```bash
gcloud run deploy rmd-to-pdf-service \
    --image gcr.io/rapid-gadget-477511-n7/rmd-to-pdf-service \
    --region europe-west1 \
    --platform managed \
    --allow-unauthenticated \
    --memory 2Gi \
    --cpu 2 \
    --timeout 900 \
    --max-instances 10 \
    --execution-environment gen2 \
    --cpu-boost \
    --set-env-vars "GOOGLE_CLOUD_PROJECT=rapid-gadget-477511-n7,USE_MINIMAL_AUTH=true"
```

## Option 3: Manual Docker Build (if you have Docker locally)

If you have Docker installed locally:

1. Build the image:
```bash
docker build -t gcr.io/rapid-gadget-477511-n7/rmd-to-pdf-service .
```

2. Push to Google Container Registry (requires gcloud auth):
```bash
docker push gcr.io/rapid-gadget-477511-n7/rmd-to-pdf-service
```

3. Then deploy using Option 2 above.

## Current Issue Analysis

The logs show the service is still trying to use R authentication:
- "No .httr-oauth file exists" - indicates googleCloudStorageR is trying to authenticate
- "Invalid token" - authentication is failing

This suggests the current deployment is using the old server version, not the minimal version that uses gsutil.

## Immediate Fix Needed

You need to rebuild and redeploy with the minimal server that avoids R authentication entirely. The minimal version:

1. Uses `gsutil` commands directly instead of R packages
2. Installs Google Cloud SDK in the container  
3. Bypasses all R authentication complexity
4. Should work automatically with Cloud Run's service account

Use Cloud Shell (Option 1) for the easiest deployment.