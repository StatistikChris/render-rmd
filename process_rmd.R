#!/usr/bin/env Rscript

# Load required libraries
library(rmarkdown)
library(knitr)

# Set up authentication for Cloud Run environment
cat("Configuring authentication for Cloud Run...\n")
source("/app/simple_auth.R")
setup_cloud_run_auth()

# Load googleCloudStorageR
library(googleCloudStorageR)

# Additional authentication setup - use default service account
cat("Setting up GCS authentication...\n")
options(googleAuthR.scopes.selected = "https://www.googleapis.com/auth/cloud-platform")

# Try to authenticate (will use default service account in Cloud Run)
tryCatch({
  gcs_auth(json_file = NULL)
  cat("✓ GCS authentication successful\n")
}, error = function(e) {
  cat("GCS auth error (may still work):", e$message, "\n")
  # Continue anyway - Cloud Run may handle auth automatically
})

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

# Execute the main function if script is run directly
if (!interactive()) {
  result <- process_rmd_to_pdf()
  
  # Exit with appropriate code
  if (result$status == "success") {
    cat("SUCCESS: ", result$message, "\n")
    quit(status = 0)
  } else {
    cat("ERROR: ", result$message, "\n")
    quit(status = 1)
  }
}