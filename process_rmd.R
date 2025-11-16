#!/usr/bin/env Rscript

# Load required libraries (no authentication yet)
library(rmarkdown)
library(knitr)

# Function to initialize GCS authentication
init_gcs_auth <- function() {
  cat("Initializing GCS authentication...\n")
  
  # Set up Cloud Run authentication environment
  source("/app/simple_auth.R")
  setup_cloud_run_auth()
  
  # Load googleCloudStorageR after environment setup
  library(googleCloudStorageR)
  
  # Try to authenticate
  tryCatch({
    gcs_auth(json_file = NULL)
    cat("✓ GCS authentication successful\n")
    return(TRUE)
  }, error = function(e) {
    cat("GCS auth error:", e$message, "\n")
    cat("Will attempt operations without explicit auth (using Cloud Run default)\n")
    return(FALSE)
  })
}

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

# Main processing function
process_rmd_to_pdf <- function() {
  tryCatch({
    log_message("Starting RMD to PDF conversion process")
    
    # Initialize GCS authentication if not already done
    if (!exists("gcs_auth_initialized", envir = .GlobalEnv)) {
      init_gcs_auth()
      assign("gcs_auth_initialized", TRUE, envir = .GlobalEnv)
    }
    
    # Download the RMD file from Google Cloud Storage
    log_message(paste("Downloading", input_file, "from bucket", bucket_name))
    gcs_get_object(
      object_name = input_file,
      bucket = bucket_name,
      saveToDisk = local_rmd_file,
      overwrite = TRUE
    )
    
    # Check if file was downloaded successfully
    if (!file.exists(local_rmd_file)) {
      stop("Failed to download RMD file from Cloud Storage")
    }
    
    log_message(paste("Successfully downloaded", input_file, "to", local_rmd_file))
    
    # Render the RMD file to PDF
    log_message("Starting PDF rendering...")
    rmarkdown::render(
      input = local_rmd_file,
      output_file = local_pdf_file,
      output_format = "pdf_document",
      quiet = FALSE
    )
    
    # Check if PDF was created successfully
    if (!file.exists(local_pdf_file)) {
      stop("Failed to render PDF file")
    }
    
    log_message(paste("Successfully rendered PDF to", local_pdf_file))
    
    # Upload the PDF back to Google Cloud Storage
    log_message(paste("Uploading", output_file, "to bucket", bucket_name))
    gcs_upload(
      file = local_pdf_file,
      bucket = bucket_name,
      name = output_file
    )
    
    log_message(paste("Successfully uploaded", output_file, "to Cloud Storage"))
    
    # Clean up temporary files
    if (file.exists(local_rmd_file)) file.remove(local_rmd_file)
    if (file.exists(local_pdf_file)) file.remove(local_pdf_file)
    
    log_message("Process completed successfully")
    return(list(status = "success", message = "PDF generated and uploaded successfully"))
    
  }, error = function(e) {
    log_message(paste("Error occurred:", e$message))
    
    # Clean up temporary files in case of error
    if (file.exists(local_rmd_file)) file.remove(local_rmd_file)
    if (file.exists(local_pdf_file)) file.remove(local_pdf_file)
    
    return(list(status = "error", message = e$message))
  })
}

# This script should not be run directly when used with the HTTP server
# The main function process_rmd_to_pdf() will be called by the server
# Removing quit() calls to prevent container exit issues