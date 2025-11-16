# Cloud Run Startup Probe Fix

## Problem
Your Cloud Run service was failing with this error:
```
Default STARTUP TCP probe failed 1 time consecutively for container "placeholder-1" on port 8080.
The instance was not started. Connection failed with status CANCELLED.
```

## Root Cause
R applications with heavy dependencies (like `googleCloudStorageR`, `rmarkdown`, `tinytex`) take a long time to initialize. The default Cloud Run startup probe (which expects the service to be ready in ~10 seconds) was timing out before your R server could fully start.

## Solutions Applied

### 1. Enhanced Startup Probe Configuration
- **Before**: Default TCP probe with ~10 second timeout
- **After**: HTTP probe with 5-minute startup window
  - Initial delay: 30 seconds
  - Check interval: 10 seconds  
  - Max failures: 30 (allows 5 minutes total)

### 2. Improved Server Startup
- Added detailed startup logging to diagnose issues
- Implemented proper readiness tracking
- Enhanced health check endpoint with startup status
- Early library loading to catch initialization problems

### 3. Cloud Run Optimizations
- Enabled CPU boost for faster startup
- Optimized memory allocation (2Gi limit, 1Gi request)
- Reduced concurrency to handle resource-intensive R processes
- Used Gen2 execution environment

## Files Modified

1. **`service.yaml`** - Added comprehensive probe configuration
2. **`cloud-run-service.yaml`** - New optimized service definition
3. **`deploy.sh`** - Added CPU boost and Gen2 environment
4. **`deploy-with-probes.sh`** - New deployment script using service.yaml
5. **`Dockerfile`** - Enhanced server with startup tracking
6. **`server-with-logging.R`** - New server with detailed logging

## Deployment Options

### Option 1: Quick Redeploy (Recommended)
```bash
# Set your project ID
export GOOGLE_CLOUD_PROJECT_ID=your-project-id

# Use the enhanced deployment script
./deploy-with-probes.sh
```

### Option 2: Standard Deploy with New Settings
```bash
# Set your project ID
export GOOGLE_CLOUD_PROJECT_ID=your-project-id

# Use the updated standard deployment
./deploy.sh
```

## Testing the Fix

After deployment, test the health endpoint:
```bash
# Get service URL
SERVICE_URL=$(gcloud run services describe rmd-to-pdf-service --region europe-west1 --format 'value(status.url)')

# Check detailed health status
curl $SERVICE_URL/health | jq '.'
```

The health check should now show:
- `server_ready: true`
- `startup_steps` with all steps completed
- Uptime information

## Monitoring Startup

You can monitor the startup process in Cloud Logging:
1. Go to Cloud Console > Logging
2. Filter by your Cloud Run service
3. Look for startup log messages from the R server

## Expected Startup Time
- **Cold start**: 60-120 seconds (first request after idle)
- **Warm start**: 5-15 seconds (subsequent requests)

The startup probe now allows up to 5 minutes, which should be sufficient even for the slowest cold starts.