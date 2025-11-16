#!/bin/bash

# test-auth-fix.sh - Test the authentication fix locally

set -e

PROJECT_ID="${GOOGLE_CLOUD_PROJECT_ID:-your-project-id}"
SERVICE_NAME="${SERVICE_NAME:-rmd-to-pdf-service}"
REGION="${REGION:-europe-west1}"

echo "Testing authentication fix..."
echo "Project: $PROJECT_ID"
echo "Service: $SERVICE_NAME"
echo "Region: $REGION"

if [ "$PROJECT_ID" = "your-project-id" ]; then
    echo "ERROR: Please set GOOGLE_CLOUD_PROJECT_ID environment variable"
    exit 1
fi

echo ""
echo "Building and deploying with authentication fix..."

# Build the image
echo "Building Docker image..."
gcloud builds submit --tag gcr.io/$PROJECT_ID/$SERVICE_NAME .

# Deploy with the enhanced configuration
echo "Deploying to Cloud Run..."
./deploy-with-probes.sh

echo ""
echo "Deployment complete! Testing the service..."

# Get service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --format 'value(status.url)')

echo "Service URL: $SERVICE_URL"
echo ""

# Test health endpoint
echo "Testing health endpoint..."
curl -s "$SERVICE_URL/health" | jq '.'

echo ""
echo "Check the logs for authentication status:"
echo "gcloud logs read --project=$PROJECT_ID --limit=50 --filter='resource.type=cloud_run_revision AND resource.labels.service_name=\"$SERVICE_NAME\"'"