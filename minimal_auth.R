#!/usr/bin/env Rscript

# minimal_auth.R - Minimal authentication setup for Cloud Run

# Set up minimal environment for Cloud Run GCS access
setup_minimal_gcs <- function() {
  cat("Setting up minimal GCS configuration for Cloud Run...\n")
  
  # Ensure we're using non-interactive mode  
  options(
    gargle_oauth_cache = FALSE,
    gargle_quiet = TRUE,
    googleAuthR.tryAttempts = 1,
    googleAuthR.verbose = 0
  )
  
  # Set environment variables for Cloud Run
  Sys.setenv(
    "GARGLE_OAUTH_CACHE" = "FALSE",
    "GARGLE_QUIET" = "TRUE",
    "GOOGLE_APPLICATION_CREDENTIALS" = ""
  )
  
  cat("✓ Minimal GCS environment configured\n")
}

# Alternative GCS functions that work without explicit authentication
gcs_download_minimal <- function(object_name, bucket, local_file) {
  cat(sprintf("Downloading %s from bucket %s...\n", object_name, bucket))
  
  # Try using gsutil as fallback
  cmd <- sprintf("gsutil cp gs://%s/%s %s", bucket, object_name, local_file)
  result <- system(cmd, intern = FALSE)
  
  if (result == 0) {
    cat("✓ Download successful using gsutil\n")
    return(TRUE)
  } else {
    stop("Failed to download file using gsutil")
  }
}

gcs_upload_minimal <- function(local_file, bucket, object_name) {
  cat(sprintf("Uploading %s to bucket %s...\n", local_file, bucket))
  
  # Try using gsutil as fallback
  cmd <- sprintf("gsutil cp %s gs://%s/%s", local_file, bucket, object_name)
  result <- system(cmd, intern = FALSE)
  
  if (result == 0) {
    cat("✓ Upload successful using gsutil\n")
    return(TRUE)
  } else {
    stop("Failed to upload file using gsutil")
  }
}