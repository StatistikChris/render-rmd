# RMD to PDF Converter - Google Cloud Run Service

This project creates a Docker container that runs on Google Cloud Run to automatically download R Markdown files from Google Cloud Storage, render them to PDF, and upload the results back to the bucket.

## Overview

The service performs the following workflow:
1. Downloads `output.rmd` from the Google Cloud Storage bucket `keine_panik_bucket`
2. Renders the R Markdown file to PDF using `rmarkdown::render()`
3. Uploads the generated `output.pdf` back to the same bucket
4. Provides HTTP endpoints for triggering the process and health checks

## Prerequisites

- Google Cloud Platform account with billing enabled
- Google Cloud CLI (`gcloud`) installed and configured
- Docker installed (for local testing)
- R Markdown file (`output.rmd`) uploaded to your Cloud Storage bucket

## Setup Instructions

### Option A: Automatic Deployment via GitHub (Recommended)

This method sets up continuous deployment from your GitHub repository to Google Cloud Run.

#### 1. Fork or Clone the Repository

```bash
git clone https://github.com/StatistikChris/render-pdf-from-bucket-rmd.git
cd render_pdf_from_bucket_rmd
```

#### 2. Set up Google Cloud Build GitHub Integration

1. **Enable Required APIs:**
   ```bash
   gcloud services enable cloudbuild.googleapis.com
   gcloud services enable run.googleapis.com
   gcloud services enable storage.googleapis.com
   ```

2. **Connect GitHub Repository:**
   - Go to [Google Cloud Console > Cloud Build > Triggers](https://console.cloud.google.com/cloud-build/triggers)
   - Click "Connect Repository"
   - Select "GitHub" and authorize access
   - Choose your repository: `StatistikChris/render-pdf-from-bucket-rmd`

3. **Create Build Trigger:**
   - Click "Create Trigger"
   - Name: `deploy-rmd-to-pdf`
   - Event: Push to a branch
   - Branch: `^master$`
   - Configuration: Cloud Build configuration file (yaml or json)
   - Cloud Build configuration file location: `cloudbuild.yaml`
   - Click "Create"

4. **Set Required IAM Permissions:**
   ```bash
   # Get the Cloud Build service account
   PROJECT_ID=$(gcloud config get-value project)
   BUILD_SA="${PROJECT_ID}@cloudbuild.gserviceaccount.com"
   
   # Grant Cloud Run Developer role
   gcloud projects add-iam-policy-binding $PROJECT_ID \
     --member="serviceAccount:${BUILD_SA}" \
     --role="roles/run.developer"
   
   # Grant Service Account User role
   gcloud projects add-iam-policy-binding $PROJECT_ID \
     --member="serviceAccount:${BUILD_SA}" \
     --role="roles/iam.serviceAccountUser"
   
   # Grant Storage Object Admin role for the service
   gcloud projects add-iam-policy-binding $PROJECT_ID \
     --member="serviceAccount:${PROJECT_ID}-compute@developer.gserviceaccount.com" \
     --role="roles/storage.objectAdmin"
   ```

#### 3. Deploy by Pushing to GitHub

Simply push changes to the `master` branch to trigger automatic deployment:

```bash
git add .
git commit -m "Deploy RMD to PDF service"
git push origin master
```

The service will be automatically built and deployed to Cloud Run!

#### CI/CD Workflow

The automatic deployment follows this workflow:

1. **Code Push**: Developer pushes code to `master` branch
2. **Trigger**: Cloud Build trigger detects the push
3. **Build**: Docker image is built using `Dockerfile`
4. **Push**: Image is pushed to Google Container Registry
5. **Deploy**: New revision is deployed to Cloud Run
6. **Traffic**: 100% traffic is routed to the new revision

**Build Steps in Detail:**
- `build-image`: Build Docker image with commit SHA tag
- `push-image`: Push tagged image to Container Registry  
- `push-latest`: Push latest tag for convenience
- `deploy-service`: Deploy new revision to Cloud Run

### Option B: Manual Deployment

For manual deployment or local testing, use the provided deployment script:

```bash
# Configure Google Cloud
gcloud auth login
export GOOGLE_CLOUD_PROJECT_ID="your-project-id-here"

# Full deployment (recommended for first time)
./deploy.sh

# Or deploy with custom environment variables
GOOGLE_CLOUD_PROJECT_ID="your-project-id" ./deploy.sh
```

### Alternative Manual Deployment Options

```bash
# Build Docker image only
./deploy.sh build

# Create service account only
./deploy.sh service-account

# Show help
./deploy.sh help
```

## File Structure

```
├── process_rmd.R      # Main R script for processing
├── install.R          # R package dependencies
├── Dockerfile         # Docker container configuration
├── cloudbuild.yaml    # Google Cloud Build configuration for CI/CD
├── service.yaml       # Cloud Run service configuration
├── deploy.sh          # Manual deployment script (optional)
├── .dockerignore      # Docker build optimization
├── .gcloudignore      # Cloud Build optimization
└── README.md          # This documentation
```

## Key Components

### `process_rmd.R`
- Main processing logic
- Downloads RMD files from Cloud Storage
- Renders PDFs using rmarkdown
- Uploads results back to the bucket
- Includes error handling and logging

### `install.R`
- Defines required R packages
- Installs TinyTeX for LaTeX support
- Sets up the R environment in the container

### `Dockerfile`
- Based on `rocker/r-ver:4.3.2`
- Installs system dependencies
- Sets up R packages and TinyTeX
- Creates HTTP server for Cloud Run

### `cloudbuild.yaml`
- Google Cloud Build configuration for CI/CD
- Automatic deployment from GitHub repository
- Multi-step build: Docker build → Push → Deploy to Cloud Run
- Configurable via substitutions

### `service.yaml`
- Declarative Cloud Run service configuration
- Defines resource limits, health checks, and scaling
- Can be used for advanced deployment scenarios

### `deploy.sh`
- Manual deployment script (alternative to CI/CD)
- Handles authentication and project setup
- Builds and deploys the Docker image locally

## API Endpoints

Once deployed, your service will have the following endpoints:

### `GET /health`
Health check endpoint
```bash
curl https://your-service-url/health
```

### `POST /process`
Trigger the RMD to PDF conversion
```bash
curl -X POST https://your-service-url/process
```

### `GET /` (Root)
Service information and available endpoints
```bash
curl https://your-service-url/
```

## Configuration

### Environment Variables

The service uses the following environment variables:

- `GOOGLE_CLOUD_PROJECT`: Your Google Cloud project ID (auto-set by Cloud Run)
- `PORT`: Port for the HTTP server (auto-set by Cloud Run, default: 8080)

### Cloud Storage Configuration

The service is currently configured to work with:
- Bucket: `keine_panik_bucket`
- Input file: `output.rmd`
- Output file: `output.pdf`

To change these settings, modify the variables in `process_rmd.R`:

```r
bucket_name <- "your-bucket-name"
input_file <- "your-input-file.rmd"
output_file <- "your-output-file.pdf"
```

## Authentication

The service uses Google Cloud's default service account for authentication. For production use, consider creating a dedicated service account with minimal required permissions:

```bash
# Create service account
gcloud iam service-accounts create rmd-pdf-service \
  --display-name="RMD to PDF Service Account"

# Grant Storage Object Admin permissions
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:rmd-pdf-service@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin"
```

## Local Testing

### Build and Test Docker Container Locally

```bash
# Build the Docker image
docker build -t rmd-to-pdf .

# Run the container locally
docker run -p 8080:8080 \
  -e GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json \
  -v /path/to/service-account.json:/path/to/service-account.json \
  rmd-to-pdf

# Test the endpoints
curl http://localhost:8080/health
curl -X POST http://localhost:8080/process
```

### Run R Script Directly

```bash
# Install R dependencies locally
Rscript install.R

# Run the processing script
Rscript process_rmd.R
```

## Monitoring and Logging

### Cloud Build Logs

Monitor automatic deployments in the Google Cloud Console:
- Go to [Cloud Build > History](https://console.cloud.google.com/cloud-build/builds)
- View build logs and deployment status
- Get notified of build failures via email

### Cloud Run Logs

View service logs in the Google Cloud Console or using gcloud:

```bash
# View logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=rmd-to-pdf-service" --limit 50

# Follow logs in real-time
gcloud logging tail "resource.type=cloud_run_revision AND resource.labels.service_name=rmd-to-pdf-service"
```

### Monitoring

The service includes:
- Structured logging with timestamps
- Error handling and reporting
- Health check endpoint for monitoring
- Automatic cleanup of temporary files

## Troubleshooting

### Common Issues

1. **Authentication Errors**
   - Ensure service account has Storage Object Admin permissions
   - Verify the bucket name and file names are correct

2. **PDF Generation Errors**
   - Check that the RMD file is valid R Markdown
   - Ensure all required R packages are available
   - Verify LaTeX dependencies are installed (handled by TinyTeX)

3. **Memory Issues**
   - Cloud Run service is configured with 2GB RAM
   - For larger documents, consider increasing memory allocation

4. **Timeout Issues**
   - Service timeout is set to 900 seconds (15 minutes)
   - Adjust if processing takes longer

### Debug Mode

To enable more detailed logging, modify the R scripts to increase verbosity:

```r
# In process_rmd.R, change:
rmarkdown::render(..., quiet = FALSE)
# To:
rmarkdown::render(..., quiet = FALSE, verbose = TRUE)
```

## Security Considerations

- Service allows unauthenticated requests (suitable for internal use)
- For production, consider adding authentication
- Service account follows principle of least privilege
- Temporary files are automatically cleaned up

## Cost Optimization

- Service scales to zero when not in use
- Uses efficient R base image
- Configurable memory and CPU allocation
- Consider setting max instances based on usage

## Support and Contributing

For issues or contributions:
1. Check the logs for error details
2. Verify all prerequisites are met
3. Test with a simple RMD file first
4. Submit issues with full error messages and logs