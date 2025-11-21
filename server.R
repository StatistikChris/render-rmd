#!/usr/bin/env Rscript

# server.R - Simple HTTP server for RMD to PDF conversion

library(httpuv)
library(jsonlite)

# Function to log with timestamps
log_msg <- function(msg) {
  cat(sprintf("[%s] %s\n", Sys.time(), msg))
  flush.console()
}

log_msg("=== R Server Starting ===")
log_msg(sprintf("R version: %s", R.version.string))

# Check port configuration
port <- as.integer(Sys.getenv("PORT", "8080"))
log_msg(sprintf("Port configured: %d", port))

# Load required packages
log_msg("Loading required packages...")
tryCatch({
  library(rmarkdown)
  library(knitr)
  log_msg("✓ Core packages loaded successfully")
}, error = function(e) {
  log_msg(sprintf("ERROR loading packages: %s", e$message))
  quit(status = 1)
})

# Load processing script
log_msg("Loading processing script...")
tryCatch({
  source("/app/process_working.R")
  log_msg("✓ Processing script loaded")
}, error = function(e) {
  log_msg(sprintf("ERROR loading processing script: %s", e$message))
  quit(status = 1)
})

# Test gsutil availability
log_msg("Testing gsutil availability...")
gsutil_available <- system("which gsutil", ignore.stdout = TRUE, ignore.stderr = TRUE) == 0
if (gsutil_available) {
  log_msg("✓ gsutil is available")
} else {
  log_msg("⚠ gsutil not found - operations may fail")
}

# HTTP request handler
handle_request <- function(req) {
  log_msg(sprintf("Request: %s %s", req$REQUEST_METHOD, req$PATH_INFO))
  
  if (req$REQUEST_METHOD == "GET" && req$PATH_INFO == "/health") {
    list(
      status = 200L,
      headers = list("Content-Type" = "application/json"),
      body = jsonlite::toJSON(list(
        status = "healthy",
        timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S UTC"),
        r_version = R.version.string,
        gsutil_available = gsutil_available
      ), auto_unbox = TRUE)
    )
    
  } else if (req$REQUEST_METHOD == "POST" && req$PATH_INFO == "/process") {
    log_msg("Processing RMD to PDF request...")
    result <- tryCatch({
      process_rmd_working()
    }, error = function(e) {
      log_msg(sprintf("Processing error: %s", e$message))
      list(status = "error", message = e$message)
    })
    
    status_code <- if (result$status == "success") 200L else 500L
    list(
      status = status_code,
      headers = list("Content-Type" = "application/json"),
      body = jsonlite::toJSON(result, auto_unbox = TRUE)
    )
    
  } else {
    # Default endpoint
    list(
      status = 200L,
      headers = list("Content-Type" = "application/json"),
      body = jsonlite::toJSON(list(
        message = "RMD to PDF Service",
        endpoints = list(
          "GET /health" = "Health check",
          "POST /process" = "Convert RMD to PDF"
        )
      ), auto_unbox = TRUE)
    )
  }
}

process_rmd_working()
log_msg("=== Server initialization complete ===")
log_msg(sprintf("Server ready on http://0.0.0.0:%d", port))

# Start the HTTP server
tryCatch({
  runServer("0.0.0.0", port, list(call = handle_request))
}, error = function(e) {
  log_msg(sprintf("FATAL: Server failed to start: %s", e$message))
  quit(status = 1)
})