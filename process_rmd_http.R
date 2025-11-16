#!/usr/bin/env Rscript

# process_rmd_http.R - RMD processing using HTTP APIs instead of gsutil

# Load only essential libraries
library(rmarkdown)
library(knitr)
library(httr)
library(jsonlite)

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

# Get access token from metadata server (Cloud Run)
get_access_token <- function() {
  tryCatch({
    response <- GET(
      "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token",
      add_headers("Metadata-Flavor" = "Google")
    )
    if (status_code(response) == 200) {
      token_data <- content(response, "parsed")
      return(token_data$access_token)
    }
    return(NULL)
  }, error = function(e) {
    log_message(paste("Token fetch error:", e$message))
    return(NULL)
  })
}

# Download file using Google Cloud Storage HTTP API
download_from_gcs_http <- function(bucket, object, local_path) {
  token <- get_access_token()
  if (is.null(token)) {
    log_message("No access token available")
    return(FALSE)
  }
  
  url <- sprintf("https://storage.googleapis.com/storage/v1/b/%s/o/%s?alt=media", bucket, URLencode(object))
  
  tryCatch({
    response <- GET(
      url,
      add_headers("Authorization" = paste("Bearer", token)),
      write_disk(local_path, overwrite = TRUE)
    )
    return(status_code(response) == 200)
  }, error = function(e) {
    log_message(paste("Download error:", e$message))
    return(FALSE)
  })
}

# Upload file using Google Cloud Storage HTTP API
upload_to_gcs_http <- function(local_path, bucket, object) {
  token <- get_access_token()
  if (is.null(token)) {
    log_message("No access token available")
    return(FALSE)
  }
  
  url <- sprintf("https://storage.googleapis.com/upload/storage/v1/b/%s/o?uploadType=media&name=%s", bucket, URLencode(object))
  
  tryCatch({
    response <- POST(
      url,
      add_headers(
        "Authorization" = paste("Bearer", token),
        "Content-Type" = "application/pdf"
      ),
      body = upload_file(local_path)
    )
    return(status_code(response) %in% c(200, 201))
  }, error = function(e) {
    log_message(paste("Upload error:", e$message))
    return(FALSE)
  })
}

# Main processing function using HTTP APIs
process_rmd_to_pdf_http <- function() {
  tryCatch({
    log_message("Starting RMD to PDF conversion process (HTTP API version)")
    
    # Download the RMD file from Google Cloud Storage using HTTP API
    log_message(paste("Downloading", input_file, "from bucket", bucket_name, "using HTTP API"))
    
    if (!download_from_gcs_http(bucket_name, input_file, local_rmd_file)) {
      stop("Failed to download RMD file from Cloud Storage using HTTP API")
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
    
    # Upload the PDF back to Google Cloud Storage using HTTP API
    log_message(paste("Uploading", output_file, "to bucket", bucket_name, "using HTTP API"))
    
    if (!upload_to_gcs_http(local_pdf_file, bucket_name, output_file)) {
      stop("Failed to upload PDF file to Cloud Storage using HTTP API")
    }
    
    log_message(paste("Successfully uploaded", output_file, "to Cloud Storage"))
    
    # Clean up temporary files
    if (file.exists(local_rmd_file)) file.remove(local_rmd_file)
    if (file.exists(local_pdf_file)) file.remove(local_pdf_file)
    
    log_message("Process completed successfully")
    return(list(status = "success", message = "PDF generated and uploaded successfully using HTTP API"))
    
  }, error = function(e) {
    log_message(paste("Error occurred:", e$message))
    
    # Clean up temporary files in case of error
    if (file.exists(local_rmd_file)) file.remove(local_rmd_file)  
    if (file.exists(local_pdf_file)) file.remove(local_pdf_file)
    
    return(list(status = "error", message = e$message))
  })
}

# This script is designed to be sourced by server
# The main function process_rmd_to_pdf_http() will be called by the HTTP server