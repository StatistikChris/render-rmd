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
    
    # First, let's check if we can reach the metadata server
    metadata_url <- "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token"
    log_message(sprintf("Requesting token from: %s", metadata_url))
    
    response <- GET(
      metadata_url,
      add_headers("Metadata-Flavor" = "Google"),
      timeout(10)
    )
    
    log_message(sprintf("Token response status: %d", status_code(response)))
    
    if (status_code(response) == 200) {
      token_data <- content(response, "parsed")
      if (!is.null(token_data$access_token)) {
        log_message(sprintf("✓ Access token obtained (length: %d chars)", nchar(token_data$access_token)))
        log_message(sprintf("Token type: %s", token_data$token_type %||% "unknown"))
        log_message(sprintf("Expires in: %s seconds", token_data$expires_in %||% "unknown"))
        return(token_data$access_token)
      } else {
        log_message("ERROR: Token response contains no access_token")
        return(NULL)
      }
    } else {
      log_message(sprintf("Token request failed with status: %d", status_code(response)))
      response_text <- content(response, "text", encoding = "UTF-8")
      log_message(sprintf("Response body: %s", response_text))
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
    log_message("Making download request...")
    response <- GET(
      download_url,
      add_headers("Authorization" = paste("Bearer", token)),
      write_disk(local_rmd_file, overwrite = TRUE),
      timeout(30)
    )
    
    status <- status_code(response)
    log_message(sprintf("Download response status: %d", status))
    
    if (status == 200) {
      if (file.exists(local_rmd_file)) {
        file_size <- file.info(local_rmd_file)$size
        log_message(sprintf("✓ RMD file downloaded successfully (%d bytes)", file_size))
        return(TRUE)
      } else {
        log_message("ERROR: Download appeared successful but file doesn't exist")
        return(FALSE)
      }
    } else {
      log_message(sprintf("Download failed with HTTP status: %d", status))
      response_text <- content(response, "text", encoding = "UTF-8")
      log_message(sprintf("Error response: %s", response_text))
      
      if (status == 403) {
        log_message("ERROR: Access denied - check if service account has Storage Object Viewer role")
      } else if (status == 404) {
        log_message("ERROR: File not found - check if 'output.rmd' exists in 'keine_panik_bucket'")
      }
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
    file_size <- file.info(local_pdf_file)$size
    log_message(sprintf("Uploading PDF file (%d bytes)...", file_size))
    
    response <- POST(
      upload_url,
      add_headers(
        "Authorization" = paste("Bearer", token),
        "Content-Type" = "application/pdf"
      ),
      body = upload_file(local_pdf_file),
      timeout(60)
    )
    
    status <- status_code(response)
    log_message(sprintf("Upload response status: %d", status))
    
    if (status %in% c(200, 201)) {
      log_message("✓ PDF uploaded successfully to bucket")
      response_content <- content(response, "parsed")
      if (!is.null(response_content$name)) {
        log_message(sprintf("Uploaded as: %s", response_content$name))
      }
      return(TRUE)
    } else {
      log_message(sprintf("Upload failed with HTTP status: %d", status))
      response_text <- content(response, "text", encoding = "UTF-8")
      log_message(sprintf("Error response: %s", response_text))
      
      if (status == 403) {
        log_message("ERROR: Access denied - check if service account has Storage Object Creator role")
      } else if (status == 400) {
        log_message("ERROR: Bad request - check upload parameters")
      }
      return(FALSE)
    }
  }, error = function(e) {
    log_message(paste("Upload error:", e$message))
    return(FALSE)
  })
}

# Diagnostic function to check all prerequisites
check_prerequisites <- function() {
  log_message("=== Checking Prerequisites ===")
  
  # Check if we can get a token
  token <- get_token()
  if (is.null(token)) {
    log_message("❌ Cannot obtain access token")
    return(FALSE)
  } else {
    log_message("✓ Access token obtained")
  }
  
  # Check if we can reach the bucket
  log_message(sprintf("Checking if bucket '%s' is accessible...", bucket_name))
  bucket_url <- sprintf("https://storage.googleapis.com/storage/v1/b/%s", bucket_name)
  
  tryCatch({
    response <- GET(
      bucket_url,
      add_headers("Authorization" = paste("Bearer", token))
    )
    
    if (status_code(response) == 200) {
      log_message("✓ Bucket is accessible")
    } else {
      log_message(sprintf("❌ Bucket check failed with status: %d", status_code(response)))
      return(FALSE)
    }
  }, error = function(e) {
    log_message(paste("Bucket check error:", e$message))
    return(FALSE)
  })
  
  # Check if the input file exists
  log_message(sprintf("Checking if '%s' exists in bucket...", input_file))
  file_url <- sprintf("https://storage.googleapis.com/storage/v1/b/%s/o/%s", bucket_name, URLencode(input_file))
  
  tryCatch({
    response <- GET(
      file_url,
      add_headers("Authorization" = paste("Bearer", token))
    )
    
    if (status_code(response) == 200) {
      file_info <- content(response, "parsed")
      log_message(sprintf("✓ File exists (size: %s bytes)", file_info$size))
    } else if (status_code(response) == 404) {
      log_message(sprintf("❌ File '%s' not found in bucket '%s'", input_file, bucket_name))
      return(FALSE)
    } else {
      log_message(sprintf("❌ File check failed with status: %d", status_code(response)))
      return(FALSE)
    }
  }, error = function(e) {
    log_message(paste("File check error:", e$message))
    return(FALSE)
  })
  
  log_message("✓ All prerequisites checked successfully")
  return(TRUE)
}

# Main processing function
process_rmd_direct <- function() {
  log_message("=== Starting RMD to PDF processing ===")
  
  tryCatch({
    # Step 0: Check prerequisites
    if (!check_prerequisites()) {
      stop("Prerequisites check failed")
    }
    
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