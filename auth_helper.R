#!/usr/bin/env Rscript

# auth_helper.R - Cloud Run authentication helper

#' Set up Google Cloud Storage authentication for Cloud Run
#' This function handles authentication in the Cloud Run environment
setup_gcs_auth <- function() {
  cat("Setting up GCS authentication for Cloud Run...\n")
  
  # Method 1: Try using googleCloudStorageR with token from metadata server
  tryCatch({
    library(googleCloudStorageR)
    library(httr)
    
    # Get access token from metadata server
    metadata_url <- "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token"
    headers <- add_headers("Metadata-Flavor" = "Google")
    
    response <- GET(metadata_url, headers)
    if (status_code(response) == 200) {
      token_data <- content(response, "parsed")
      access_token <- token_data$access_token
      
      # Set up authentication with the token
      options(googleAuthR.scopes.selected = "https://www.googleapis.com/auth/cloud-platform")
      
      # Create a token object
      token <- httr::Token2.0$new(
        app = httr::oauth_app("google", key = "", secret = ""),
        endpoint = httr::oauth_endpoints("google"),
        credentials = list(access_token = access_token),
        cache = FALSE
      )
      
      # Set the token for googleAuthR
      googleAuthR::gar_auth(token = token)
      
      cat("✓ Successfully authenticated using Cloud Run metadata server\n")
      return(TRUE)
    }
  }, error = function(e) {
    cat("Metadata server authentication failed:", e$message, "\n")
  })
  
  # Method 2: Try default service account
  tryCatch({
    library(googleCloudStorageR)
    gcs_auth(json_file = NULL)
    cat("✓ Successfully authenticated using default service account\n")
    return(TRUE)
  }, error = function(e) {
    cat("Default service account authentication failed:", e$message, "\n")
  })
  
  # Method 3: Try setting environment variables for automatic auth
  tryCatch({
    Sys.setenv("GCS_AUTH_FILE" = "")
    Sys.setenv("GOOGLE_APPLICATION_CREDENTIALS" = "")
    options(googleAuthR.scopes.selected = "https://www.googleapis.com/auth/cloud-platform")
    
    library(googleCloudStorageR)
    cat("✓ Set up environment for automatic authentication\n")
    return(TRUE)
  }, error = function(e) {
    cat("Environment-based authentication setup failed:", e$message, "\n")
  })
  
  cat("WARNING: All authentication methods failed. Operations may fail.\n")
  return(FALSE)
}