# Deployment Fix - Authentication Issues Resolved

## What's Fixed in This Commit:

✅ **Authentication Issue**: 
- Switched to minimal server using `gsutil` directly
- Removes R authentication complexity that was causing "Invalid token" errors
- Uses Cloud Run service account automatically

✅ **Startup Probe Issue**: 
- Already fixed with 5-minute startup window
- Enhanced logging for better debugging

✅ **Deployment Configuration**:
- Updated `cloudbuild.yaml` to use correct region (europe-west1)
- Added CPU boost and Gen2 execution environment
- Optimized Cloud Run settings

## Files Changed:
- `Dockerfile` → Uses minimal server by default
- `cloudbuild.yaml` → Updated deployment configuration  
- `server-minimal.R` → Server without R auth issues
- `process_rmd_minimal.R` → Processing using gsutil

## Expected Result:
After automatic deployment, the service should:
1. Start successfully (no more startup probe failures)
2. Authenticate automatically using Cloud Run service account
3. Process RMD files using gsutil instead of R packages

## Test After Deployment:
```
curl https://your-service-url/health
```

Should return:
```json
{
  "status": "healthy",
  "auth_method": "gsutil_minimal",
  "server_ready": true
}
```