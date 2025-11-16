#!/bin/bash

# deploy-with-probes.sh - Deploy with proper startup probe configuration

set -e

# Configuration
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

print_status "Deploying with enhanced startup probe configuration..."

# Create a temporary service file with the correct project ID
TEMP_SERVICE_FILE="/tmp/service-${SERVICE_NAME}.yaml"
sed "s/PROJECT_ID/${PROJECT_ID}/g" cloud-run-service.yaml > "$TEMP_SERVICE_FILE"

# Deploy using the service configuration file
gcloud run services replace "$TEMP_SERVICE_FILE" \
    --region "$REGION" \
    --platform managed

# Clean up temporary file
rm "$TEMP_SERVICE_FILE"

# Get the service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --format 'value(status.url)')
print_status "Service deployed successfully!"
print_status "Service URL: $SERVICE_URL"
print_status "Health check: curl $SERVICE_URL/health"

echo ""
echo "The service now has enhanced startup probe configuration:"
echo "- Startup probe: 30s initial delay, 10s period, 30 failures allowed (5 minutes total)"
echo "- CPU boost enabled for faster startup"
echo "- Optimized resource allocation"