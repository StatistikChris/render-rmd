#!/usr/bin/env Rscript

# process_rmd_minimal.R - RMD processing with minimal dependencies

# Load only essential libraries
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

# Download file using gsutil (works with Cloud Run service account)
download_from_gcs <- function(bucket, object, local_path) {
  cmd <- sprintf("gsutil cp gs://%s/%s %s", bucket, object, local_path)
  cat(sprintf("Running command: %s\n", cmd))
  result <- system(cmd, intern = FALSE)  # Use intern = FALSE to see errors
  cat(sprintf("Command exit code: %d\n", result))
  return(result == 0)
}

# Upload file using gsutil
upload_to_gcs <- function(local_path, bucket, object) {
  cmd <- sprintf("gsutil cp %s gs://%s/%s", local_path, bucket, object)
  cat(sprintf("Running command: %s\n", cmd))
  result <- system(cmd, intern = FALSE)  # Use intern = FALSE to see errors
  cat(sprintf("Command exit code: %d\n", result))
  return(result == 0)
}

# Main processing function using gsutil
process_rmd_to_pdf_minimal <- function() {
  tryCatch({
    log_message("Starting RMD to PDF conversion process (minimal version)")
    
    # Download the RMD file from Google Cloud Storage using gsutil
    log_message(paste("Downloading", input_file, "from bucket", bucket_name, "using gsutil"))
    
    if (!download_from_gcs(bucket_name, input_file, local_rmd_file)) {
      stop("Failed to download RMD file from Cloud Storage using gsutil")
    }
    
    # Check if file was downloaded successfully
    if (!file.exists(local_rmd_file)) {
      stop("RMD file not found after download")
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
    
    # Upload the PDF back to Google Cloud Storage using gsutil
    log_message(paste("Uploading", output_file, "to bucket", bucket_name, "using gsutil"))
    
    if (!upload_to_gcs(local_pdf_file, bucket_name, output_file)) {
      stop("Failed to upload PDF file to Cloud Storage using gsutil")
    }
    
    log_message(paste("Successfully uploaded", output_file, "to Cloud Storage"))
    
    # Clean up temporary files
    if (file.exists(local_rmd_file)) file.remove(local_rmd_file)
    if (file.exists(local_pdf_file)) file.remove(local_pdf_file)
    
    log_message("Process completed successfully")
    return(list(status = "success", message = "PDF generated and uploaded successfully using gsutil"))
    
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
  result <- process_rmd_to_pdf_minimal()
  
  # Exit with appropriate code
  if (result$status == "success") {
    cat("SUCCESS: ", result$message, "\n")
    quit(status = 0)
  } else {
    cat("ERROR: ", result$message, "\n")
    quit(status = 1)
  }
}