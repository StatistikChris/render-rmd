#!/usr/bin/env Rscript

# simple_auth.R - Simplified Cloud Run authentication

# Set environment variables for Cloud Run authentication
setup_cloud_run_auth <- function() {
  cat("Setting up Cloud Run authentication...\n")
  
  # Set Google Application Default Credentials environment
  Sys.setenv("GOOGLE_APPLICATION_CREDENTIALS" = "")
  
  # Disable interactive authentication
  Sys.setenv("GARGLE_OAUTH_CACHE" = FALSE)
  Sys.setenv("GARGLE_QUIET" = TRUE)
  
  # Set authentication to use service account
  options(
    gargle_oauth_cache = FALSE,
    gargle_quiet = TRUE,
    googleAuthR.scopes.selected = "https://www.googleapis.com/auth/cloud-platform"
  )
  
  cat("✓ Authentication environment configured for Cloud Run\n")
}