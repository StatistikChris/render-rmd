# Container Exit Issue Fix

## Problem
The PDF processing works perfectly, but the container exits after processing instead of staying alive as a web server.

**Symptoms:**
- ✅ "SUCCESS: PDF generated and uploaded successfully using gsutil"
- ❌ "Container called exit(0)" 
- ❌ "Default STARTUP TCP probe failed" (because container isn't running)

## Root Cause
The processing script had `quit(status = 0)` calls that could cause the container to exit when the job completes.

## Fix Applied
1. **Removed direct execution** from `process_rmd_minimal.R` - this script should only be sourced by the server
2. **Added debug logging** to track server lifecycle
3. **Ensured server keeps running** after processing requests

## Expected Behavior After Fix
1. Container starts and runs the HTTP server continuously  
2. Server handles `/health` and `/process` requests
3. After processing a PDF, server remains alive for future requests
4. No more container exit issues

## Files Modified
- `process_rmd_minimal.R` - Removed quit() calls
- `server-minimal.R` - Added debug logging

The server should now stay alive permanently, processing requests as they come in.