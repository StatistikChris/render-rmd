#!/usr/bin/env Rscript

# emergency_fix.R - Emergency fix for current deployment

# This script tries to work around authentication issues without rebuilding

library(rmarkdown)
library(knitr)

# Configuration
bucket_name <- "keine_panik_bucket"
input_file <- "output.rmd"
output_file <- "output.pdf"
local_rmd_file <- "/tmp/output.rmd"
local_pdf_file <- "/tmp/output.pdf"

# Function to log messages with timestamp
log_message <- function(message) {
  cat(paste(Sys.time(), "-", message, "\n"))
}

# Try multiple authentication approaches
try_gcs_auth <- function() {
  # Method 1: Skip authentication entirely and rely on Cloud Run default
  tryCatch({
    Sys.setenv("GARGLE_OAUTH_CACHE" = "FALSE")
    Sys.setenv("GARGLE_QUIET" = "TRUE")
    options(gargle_oauth_cache = FALSE, gargle_quiet = TRUE)
    
    library(googleCloudStorageR)
    # Don't call gcs_auth() - let it use default credentials
    log_message("Attempting to use default credentials without explicit auth")
    return(TRUE)
  }, error = function(e) {
    log_message(paste("Default credential setup failed:", e$message))
    return(FALSE)
  })
}

# Alternative download using system curl if GCS fails
download_with_curl <- function(bucket, object, local_path) {
  # Try to get a signed URL or use public access if possible
  # This is a fallback method
  log_message("Attempting alternative download methods...")
  return(FALSE)  # Placeholder - would need specific implementation
}

# Main processing function with better error handling
process_rmd_emergency <- function() {
  tryCatch({
    log_message("Starting emergency RMD processing")
    
    # Try to set up authentication
    auth_ok <- try_gcs_auth()
    
    if (auth_ok) {
      # Try normal GCS download
      log_message(paste("Downloading", input_file, "from bucket", bucket_name))
      tryCatch({
        gcs_get_object(
          object_name = input_file,
          bucket = bucket_name,
          saveToDisk = local_rmd_file,
          overwrite = TRUE
        )
        log_message("GCS download successful")
      }, error = function(e) {
        log_message(paste("GCS download failed:", e$message))
        stop("Cannot download RMD file")
      })
    } else {
      stop("Authentication setup failed")
    }
    
    # Check if file was downloaded
    if (!file.exists(local_rmd_file)) {
      stop("RMD file not found after download")
    }
    
    # Render PDF
    log_message("Rendering PDF...")
    rmarkdown::render(
      input = local_rmd_file,
      output_file = local_pdf_file,
      output_format = "pdf_document",
      quiet = FALSE
    )
    
    if (!file.exists(local_pdf_file)) {
      stop("PDF rendering failed")
    }
    
    # Upload PDF
    log_message("Uploading PDF...")
    gcs_upload(
      file = local_pdf_file,
      bucket = bucket_name,
      name = output_file
    )
    
    # Cleanup
    if (file.exists(local_rmd_file)) file.remove(local_rmd_file)
    if (file.exists(local_pdf_file)) file.remove(local_pdf_file)
    
    log_message("Emergency processing completed successfully")
    return(list(status = "success", message = "PDF processed successfully (emergency mode)"))
    
  }, error = function(e) {
    log_message(paste("Emergency processing failed:", e$message))
    
    # Cleanup
    if (file.exists(local_rmd_file)) file.remove(local_rmd_file)
    if (file.exists(local_pdf_file)) file.remove(local_pdf_file)
    
    return(list(status = "error", message = paste("Emergency processing failed:", e$message)))
  })
}

# Override the main function if this script is sourced
if (exists("process_rmd_to_pdf")) {
  process_rmd_to_pdf <- process_rmd_emergency
}