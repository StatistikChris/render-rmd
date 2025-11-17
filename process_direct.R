#!/usr/bin/env Rscript

# process_direct.R - Direct implementation for RMD to PDF processing

# Load required libraries
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
  flush.console()
}

# Get access token from Cloud Run metadata server
get_token <- function() {
  tryCatch({
    log_message("Getting access token from metadata server...")
    response <- GET(
      "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token",
      add_headers("Metadata-Flavor" = "Google")
    )
    
    if (status_code(response) == 200) {
      token_data <- content(response, "parsed")
      log_message("✓ Access token obtained")
      return(token_data$access_token)
    } else {
      log_message(sprintf("Token request failed with status: %d", status_code(response)))
      return(NULL)
    }
  }, error = function(e) {
    log_message(paste("Token error:", e$message))
    return(NULL)
  })
}

# Download RMD file from Google Cloud Storage
download_rmd <- function() {
  log_message("Starting download of output.rmd...")
  
  token <- get_token()
  if (is.null(token)) {
    stop("Cannot get access token")
  }
  
  # Direct download URL
  download_url <- sprintf("https://storage.googleapis.com/storage/v1/b/%s/o/%s?alt=media", 
                         bucket_name, URLencode(input_file))
  
  log_message(sprintf("Downloading from: %s", download_url))
  
  tryCatch({
    response <- GET(
      download_url,
      add_headers("Authorization" = paste("Bearer", token)),
      write_disk(local_rmd_file, overwrite = TRUE)
    )
    
    if (status_code(response) == 200) {
      log_message("✓ RMD file downloaded successfully")
      log_message(sprintf("File size: %d bytes", file.info(local_rmd_file)$size))
      return(TRUE)
    } else {
      log_message(sprintf("Download failed with status: %d", status_code(response)))
      return(FALSE)
    }
  }, error = function(e) {
    log_message(paste("Download error:", e$message))
    return(FALSE)
  })
}

# Render RMD to PDF
render_pdf <- function() {
  log_message("Starting PDF rendering...")
  
  if (!file.exists(local_rmd_file)) {
    stop("RMD file not found for rendering")
  }
  
  tryCatch({
    rmarkdown::render(
      input = local_rmd_file,
      output_file = local_pdf_file,
      output_format = "pdf_document",
      quiet = FALSE
    )
    
    if (file.exists(local_pdf_file)) {
      log_message("✓ PDF rendered successfully")
      log_message(sprintf("PDF size: %d bytes", file.info(local_pdf_file)$size))
      return(TRUE)
    } else {
      log_message("PDF file was not created")
      return(FALSE)
    }
  }, error = function(e) {
    log_message(paste("Rendering error:", e$message))
    return(FALSE)
  })
}

# Upload PDF to Google Cloud Storage  
upload_pdf <- function() {
  log_message("Starting PDF upload...")
  
  token <- get_token()
  if (is.null(token)) {
    stop("Cannot get access token for upload")
  }
  
  if (!file.exists(local_pdf_file)) {
    stop("PDF file not found for upload")
  }
  
  # Upload URL
  upload_url <- sprintf("https://storage.googleapis.com/upload/storage/v1/b/%s/o?uploadType=media&name=%s", 
                       bucket_name, URLencode(output_file))
  
  log_message(sprintf("Uploading to: %s", upload_url))
  
  tryCatch({
    response <- POST(
      upload_url,
      add_headers(
        "Authorization" = paste("Bearer", token),
        "Content-Type" = "application/pdf"
      ),
      body = upload_file(local_pdf_file)
    )
    
    if (status_code(response) %in% c(200, 201)) {
      log_message("✓ PDF uploaded successfully")
      return(TRUE)
    } else {
      log_message(sprintf("Upload failed with status: %d", status_code(response)))
      response_content <- content(response, "text")
      log_message(sprintf("Response: %s", response_content))
      return(FALSE)
    }
  }, error = function(e) {
    log_message(paste("Upload error:", e$message))
    return(FALSE)
  })
}

# Main processing function
process_rmd_direct <- function() {
  log_message("=== Starting RMD to PDF processing ===")
  
  tryCatch({
    # Step 1: Download RMD file
    if (!download_rmd()) {
      stop("Failed to download RMD file")
    }
    
    # Step 2: Render to PDF
    if (!render_pdf()) {
      stop("Failed to render PDF")
    }
    
    # Step 3: Upload PDF
    if (!upload_pdf()) {
      stop("Failed to upload PDF")
    }
    
    # Cleanup
    if (file.exists(local_rmd_file)) file.remove(local_rmd_file)
    if (file.exists(local_pdf_file)) file.remove(local_pdf_file)
    
    log_message("=== Processing completed successfully ===")
    return(list(status = "success", message = "RMD processed to PDF and uploaded successfully"))
    
  }, error = function(e) {
    log_message(paste("Processing failed:", e$message))
    
    # Cleanup on error
    if (file.exists(local_rmd_file)) file.remove(local_rmd_file)
    if (file.exists(local_pdf_file)) file.remove(local_pdf_file)
    
    return(list(status = "error", message = e$message))
  })
}