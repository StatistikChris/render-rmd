#!/bin/bash

# deploy-minimal.sh - Deploy minimal version without R authentication issues

set -e

PROJECT_ID="${GOOGLE_CLOUD_PROJECT_ID:-your-project-id}"
REGION="${REGION:-europe-west1}"
SERVICE_NAME="${SERVICE_NAME:-rmd-to-pdf-service}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if project ID is set
if [ "$PROJECT_ID" = "your-project-id" ]; then
    print_error "Please set the GOOGLE_CLOUD_PROJECT_ID environment variable"
    exit 1
fi

print_status "Deploying minimal version (using gsutil instead of R auth)..."
print_status "Project: $PROJECT_ID"
print_status "Service: $SERVICE_NAME"
print_status "Region: $REGION"

# Build the image
print_status "Building Docker image with gsutil support..."
gcloud builds submit --tag gcr.io/$PROJECT_ID/$SERVICE_NAME .

# Deploy with optimized settings
print_status "Deploying to Cloud Run..."
gcloud run deploy $SERVICE_NAME \
    --image gcr.io/$PROJECT_ID/$SERVICE_NAME \
    --region $REGION \
    --platform managed \
    --allow-unauthenticated \
    --memory 2Gi \
    --cpu 2 \
    --timeout 900 \
    --max-instances 10 \
    --concurrency 10 \
    --execution-environment gen2 \
    --cpu-boost \
    --set-env-vars "GOOGLE_CLOUD_PROJECT=${PROJECT_ID}"

# Get service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --format 'value(status.url)')
print_status "Service deployed successfully!"
print_status "Service URL: $SERVICE_URL"

echo ""
echo "Testing the minimal version:"
echo "curl $SERVICE_URL/health"

# Test health endpoint
print_status "Testing health endpoint..."
curl -s "$SERVICE_URL/health" | jq '.'

echo ""
echo "This version uses gsutil directly instead of R authentication"
echo "Check logs: gcloud logs read --project=$PROJECT_ID --limit=20 --filter='resource.type=cloud_run_revision AND resource.labels.service_name=\"$SERVICE_NAME\"'"