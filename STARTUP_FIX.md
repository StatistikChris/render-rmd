# Cloud Run Startup & Authentication Fix

## Problems Solved

### 1. Startup Probe Failure
```
Default STARTUP TCP probe failed 1 time consecutively for container "placeholder-1" on port 8080.
The instance was not started. Connection failed with status CANCELLED.
```

### 2. Authentication Error  
```
Error: Non-interactive session and no authentication email selected.
Setup JSON service email auth or specify email in gar_auth(email='me@preauthenticated.com')
Execution halted
```

## Root Causes
1. **Startup Probe**: R applications with heavy dependencies take a long time to initialize
2. **Authentication**: `googleCloudStorageR` was trying to authenticate interactively, which fails in Cloud Run's non-interactive environment

## Solutions Applied

### 1. Enhanced Startup Probe Configuration
- **Before**: Default TCP probe with ~10 second timeout
- **After**: HTTP probe with 5-minute startup window
  - Initial delay: 30 seconds
  - Check interval: 10 seconds  
  - Max failures: 30 (allows 5 minutes total)

### 2. Fixed Authentication for Cloud Run
- **Before**: Interactive authentication that fails in Cloud Run
- **After**: Cloud Run service account authentication
  - Disabled interactive OAuth flows
  - Configured environment for Application Default Credentials
  - Added fallback authentication methods
  - Proper error handling for auth failures

### 3. Improved Server Startup
- Added detailed startup logging to diagnose issues
- Implemented proper readiness tracking
- Enhanced health check endpoint with startup status
- Early library loading to catch initialization problems

### 4. Cloud Run Optimizations
- Enabled CPU boost for faster startup
- Optimized memory allocation (2Gi limit, 1Gi request)
- Reduced concurrency to handle resource-intensive R processes
- Used Gen2 execution environment

## Files Modified

### Core Authentication & Startup Fixes
1. **`simple_auth.R`** - New Cloud Run authentication helper
2. **`auth_helper.R`** - Advanced authentication fallback methods
3. **`process_rmd.R`** - Updated with proper Cloud Run authentication
4. **`server-with-logging.R`** - Enhanced server with auth setup
5. **`install.R`** - Added required authentication packages

### Deployment & Configuration
6. **`service.yaml`** - Added comprehensive probe configuration
7. **`cloud-run-service.yaml`** - New optimized service definition
8. **`deploy.sh`** - Added CPU boost and Gen2 environment
9. **`deploy-with-probes.sh`** - New deployment script using service.yaml
10. **`Dockerfile`** - Updated with auth helpers and enhanced server
11. **`test-auth-fix.sh`** - New script to test the complete fix

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