#!/bin/bash

# deploy.sh - Script to build and deploy the Docker image to Google Cloud Run

set -e  # Exit on any error

# Configuration
PROJECT_ID="${GOOGLE_CLOUD_PROJECT_ID:-your-project-id}"
REGION="${REGION:-us-central1}"
SERVICE_NAME="${SERVICE_NAME:-rmd-to-pdf-service}"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_requirements() {
    print_status "Checking requirements..."
    
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install it first."
        exit 1
    fi
    
    print_status "All requirements met."
}

# Check if user is authenticated with gcloud
check_auth() {
    print_status "Checking Google Cloud authentication..."
    
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        print_error "Not authenticated with Google Cloud. Please run 'gcloud auth login' first."
        exit 1
    fi
    
    print_status "Google Cloud authentication verified."
}

# Set the project ID
set_project() {
    if [ "$PROJECT_ID" = "your-project-id" ]; then
        print_error "Please set the GOOGLE_CLOUD_PROJECT_ID environment variable or update the script with your project ID."
        exit 1
    fi
    
    print_status "Setting Google Cloud project to: $PROJECT_ID"
    gcloud config set project $PROJECT_ID
}

# Enable required APIs
enable_apis() {
    print_status "Enabling required Google Cloud APIs..."
    
    gcloud services enable cloudbuild.googleapis.com
    gcloud services enable run.googleapis.com
    gcloud services enable storage.googleapis.com
    
    print_status "APIs enabled successfully."
}

# Build the Docker image
build_image() {
    print_status "Building Docker image: $IMAGE_NAME"
    
    # Build using Cloud Build for better performance and caching
    gcloud builds submit --tag $IMAGE_NAME .
    
    print_status "Docker image built successfully."
}

# Deploy to Cloud Run
deploy_service() {
    print_status "Deploying to Cloud Run..."
    
    gcloud run deploy $SERVICE_NAME \
        --image $IMAGE_NAME \
        --region $REGION \
        --platform managed \
        --allow-unauthenticated \
        --memory 2Gi \
        --cpu 2 \
        --timeout 900 \
        --max-instances 10 \
        --set-env-vars "GOOGLE_CLOUD_PROJECT=${PROJECT_ID}" \
        --service-account "${SERVICE_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" || {
            print_warning "Deployment with custom service account failed. Trying with default service account..."
            gcloud run deploy $SERVICE_NAME \
                --image $IMAGE_NAME \
                --region $REGION \
                --platform managed \
                --allow-unauthenticated \
                --memory 2Gi \
                --cpu 2 \
                --timeout 900 \
                --max-instances 10 \
                --set-env-vars "GOOGLE_CLOUD_PROJECT=${PROJECT_ID}"
        }
    
    print_status "Service deployed successfully."
}

# Get the service URL
get_service_url() {
    SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --format 'value(status.url)')
    print_status "Service URL: $SERVICE_URL"
    echo ""
    echo "Test endpoints:"
    echo "  Health check: curl $SERVICE_URL/health"
    echo "  Process RMD:  curl -X POST $SERVICE_URL/process"
}

# Create service account (optional)
create_service_account() {
    print_status "Creating service account for Cloud Storage access..."
    
    SERVICE_ACCOUNT_EMAIL="${SERVICE_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
    
    # Create service account
    gcloud iam service-accounts create $SERVICE_NAME \
        --display-name="RMD to PDF Service Account" \
        --description="Service account for RMD to PDF conversion service" || {
        print_warning "Service account already exists or creation failed."
    }
    
    # Grant Storage Object Admin role
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
        --role="roles/storage.objectAdmin"
    
    print_status "Service account configured."
}

# Main deployment process
main() {
    print_status "Starting deployment process..."
    
    check_requirements
    check_auth
    set_project
    enable_apis
    
    # Ask if user wants to create a service account
    read -p "Do you want to create a service account for Cloud Storage access? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        create_service_account
    fi
    
    build_image
    deploy_service
    get_service_url
    
    print_status "Deployment completed successfully!"
    print_status "Your RMD to PDF service is now running on Google Cloud Run."
}

# Parse command line arguments
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "build")
        check_requirements
        check_auth
        set_project
        build_image
        ;;
    "service-account")
        check_requirements
        check_auth
        set_project
        create_service_account
        ;;
    "help")
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  deploy          Full deployment (default)"
        echo "  build           Build Docker image only"
        echo "  service-account Create service account only"
        echo "  help            Show this help"
        echo ""
        echo "Environment variables:"
        echo "  GOOGLE_CLOUD_PROJECT_ID  Your Google Cloud Project ID (required)"
        echo "  REGION                   Deployment region (default: us-central1)"
        echo "  SERVICE_NAME             Cloud Run service name (default: rmd-to-pdf-service)"
        ;;
    *)
        print_error "Unknown command: $1"
        echo "Use '$0 help' for usage information."
        exit 1
        ;;
esac