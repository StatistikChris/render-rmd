#!/usr/bin/env Rscript

# process_working.R - Back to the approach that was working

# Load required libraries
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
  flush.console()
}

# Download file using gsutil (this was working before)
download_with_gsutil <- function(bucket, object, local_path) {
  cmd <- sprintf("gsutil cp gs://%s/%s %s", bucket, object, local_path)
  log_message(sprintf("Running: %s", cmd))
  result <- system(cmd, intern = FALSE)
  log_message(sprintf("Download command exit code: %d", result))
  return(result == 0)
}

# Upload file using gsutil (this was working before)
upload_with_gsutil <- function(local_path, bucket, object) {
  cmd <- sprintf("gsutil cp %s gs://%s/%s", local_path, bucket, object)
  log_message(sprintf("Running: %s", cmd))
  result <- system(cmd, intern = FALSE)
  log_message(sprintf("Upload command exit code: %d", result))
  return(result == 0)
}

# Check if gsutil is available
check_gsutil <- function() {
  log_message("Checking if gsutil is available...")
  result <- system("which gsutil", intern = TRUE)
  if (length(result) > 0) {
    log_message(sprintf("✓ gsutil found at: %s", result[1]))
    return(TRUE)
  } else {
    log_message("❌ gsutil not found")
    return(FALSE)
  }
}

# Test gsutil authentication
test_gsutil_auth <- function() {
  log_message("Testing gsutil authentication...")
  result <- system("gsutil ls", intern = FALSE)
  if (result == 0) {
    log_message("✓ gsutil authentication working")
    return(TRUE)
  } else {
    log_message("❌ gsutil authentication failed")
    return(FALSE)
  }
}

# Main processing function using the working gsutil method
process_rmd_working <- function() {
  log_message("=== Starting RMD to PDF processing (working method) ===")
  
  tryCatch({
    # Check if gsutil is available
    if (!check_gsutil()) {
      stop("gsutil is not available")
    }
    
    # Test authentication
    if (!test_gsutil_auth()) {
      log_message("Warning: gsutil auth test failed, but continuing...")
    }
    
    # Step 1: Download RMD file using gsutil
    log_message(paste("Downloading", input_file, "from bucket", bucket_name, "using gsutil"))
    
    if (!download_with_gsutil(bucket_name, input_file, local_rmd_file)) {
      stop("Failed to download RMD file using gsutil")
    }
    
    # Check if file was downloaded successfully
    if (!file.exists(local_rmd_file)) {
      stop("RMD file not found after download")
    }
    
    file_size <- file.info(local_rmd_file)$size
    log_message(sprintf("✓ Downloaded %s (%d bytes)", input_file, file_size))
    
    # Step 2: Render the RMD file to PDF
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
    
    pdf_size <- file.info(local_pdf_file)$size
    log_message(sprintf("✓ PDF rendered successfully (%d bytes)", pdf_size))
    
    # Step 3: Upload the PDF back to Google Cloud Storage using gsutil
    log_message(paste("Uploading", output_file, "to bucket", bucket_name, "using gsutil"))
    
    if (!upload_with_gsutil(local_pdf_file, bucket_name, output_file)) {
      stop("Failed to upload PDF file using gsutil")
    }
    
    log_message(sprintf("✓ Successfully uploaded %s to Cloud Storage", output_file))
    
    # Clean up temporary files
    if (file.exists(local_rmd_file)) file.remove(local_rmd_file)
    if (file.exists(local_pdf_file)) file.remove(local_pdf_file)
    
    log_message("=== Processing completed successfully ===")
    return(list(status = "success", message = "PDF generated and uploaded successfully using gsutil"))
    
  }, error = function(e) {
    log_message(paste("Error occurred:", e$message))
    
    # Clean up temporary files in case of error
    if (file.exists(local_rmd_file)) file.remove(local_rmd_file)
    if (file.exists(local_pdf_file)) file.remove(local_pdf_file)
    
    return(list(status = "error", message = e$message))
  })
}