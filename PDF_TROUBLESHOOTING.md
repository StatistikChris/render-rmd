# PDF Creation Troubleshooting Guide

## The Goal 🎯
**Create `output.pdf` in the `keine_panik_bucket` Google Cloud Storage bucket**

## Current Status ❌
- Service runs without errors
- But no PDF file is created in the bucket

## Most Likely Issues 🔍

### 1. Service Account Permissions
The Cloud Run service account might not have the required permissions:
- **Storage Object Viewer** (to download files)
- **Storage Object Creator** (to upload files)

### 2. Missing Input File
The file `output.rmd` might not exist in `keine_panik_bucket`

### 3. Authentication Issues
Token retrieval or format might be incorrect

## Enhanced Diagnostics Added 🛠️

### New Endpoint: `GET /diagnose`
Comprehensive check of all prerequisites:
- ✅ Can obtain access token
- ✅ Can access the bucket
- ✅ Input file `output.rmd` exists
- ✅ File size and metadata

### Enhanced Logging
Every step now shows:
- HTTP status codes
- Response bodies for errors
- File sizes and existence checks
- Token information (length, type, expiry)

## Testing Steps 📋

After pushing these changes:

### 1. Run Diagnostics
```bash
curl https://your-service-url/diagnose
```

This will check:
- Access token retrieval
- Bucket accessibility  
- Input file existence

### 2. Check Logs
Look for detailed diagnostic output:
```
✓ Access token obtained (length: 1234 chars)
✓ Bucket is accessible
✓ File exists (size: 5678 bytes)
```

### 3. Try Processing
```bash
curl -X POST https://your-service-url/process
```

Watch logs for step-by-step progress.

## Fixing Permission Issues 🔧

If diagnostics show permission errors, the Cloud Run service needs these IAM roles:

1. **Storage Object Viewer** - to read `output.rmd`
2. **Storage Object Creator** - to write `output.pdf`

Or alternatively:
- **Storage Admin** - full storage access

## Expected Success Flow ✅

```
=== Checking Prerequisites ===
✓ Access token obtained (length: 1234 chars)  
✓ Bucket is accessible
✓ File exists (size: 5678 bytes)
=== Starting RMD to PDF processing ===
✓ RMD file downloaded successfully (5678 bytes)
✓ PDF rendered successfully
✓ PDF uploaded successfully to bucket
Uploaded as: output.pdf
=== Processing completed successfully ===
```

## Files Updated 📄
- `process_direct.R` - Enhanced diagnostics and error reporting
- `server-simple.R` - New `/diagnose` endpoint

The `/diagnose` endpoint will tell us exactly what's wrong! 🔍