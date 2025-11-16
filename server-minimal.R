#!/usr/bin/env Rscript

# server-minimal.R - Minimal server without authentication complexity

library(httpuv)
library(jsonlite)

# Function to log with timestamps
log_msg <- function(msg) {
  cat(sprintf("[%s] %s\n", Sys.time(), msg))
  flush.console()
}

log_msg("=== R Server Starting (Minimal Version) ===")
log_msg(sprintf("R version: %s", R.version.string))

# Check port configuration
port <- as.integer(Sys.getenv("PORT", "8080"))
log_msg(sprintf("Port configured: %d", port))

# Track startup progress
startup_steps <- list(
  packages_loaded = FALSE,
  processing_script_loaded = FALSE,
  server_ready = FALSE
)

# Load packages with logging
log_msg("Loading required packages...")
tryCatch({
  library(rmarkdown)
  log_msg("✓ rmarkdown loaded")
  
  library(knitr)
  log_msg("✓ knitr loaded")
  
  startup_steps$packages_loaded <- TRUE
  log_msg("All packages loaded successfully")
}, error = function(e) {
  log_msg(sprintf("ERROR loading packages: %s", e$message))
  quit(status = 1)
})

# Load minimal processing script (no authentication issues)
log_msg("Loading minimal processing script...")
tryCatch({
  source("/app/process_rmd_minimal.R")
  startup_steps$processing_script_loaded <- TRUE
  log_msg("✓ Minimal processing script loaded")
}, error = function(e) {
  log_msg(sprintf("ERROR loading processing script: %s", e$message))
  quit(status = 1)
})

# Test gsutil availability
log_msg("Testing gsutil availability...")
gsutil_test <- system("which gsutil", intern = TRUE)
if (length(gsutil_test) > 0) {
  log_msg("✓ gsutil is available for GCS operations")
} else {
  log_msg("⚠ gsutil not found - GCS operations may fail")
}

# HTTP request handler
handle_request <- function(req) {
  request_time <- Sys.time()
  log_msg(sprintf("Request: %s %s", req$REQUEST_METHOD, req$PATH_INFO))
  
  if (req$REQUEST_METHOD == "GET" && req$PATH_INFO == "/health") {
    # Detailed health check
    health_status <- list(
      status = "healthy",
      timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S UTC"),
      startup_steps = startup_steps,
      server_ready = startup_steps$server_ready,
      uptime_seconds = as.numeric(difftime(Sys.time(), server_start_time, units = "secs")),
      r_version = R.version.string,
      port = port,
      auth_method = "gsutil_minimal"
    )
    
    list(
      status = 200L,
      headers = list("Content-Type" = "application/json"),
      body = jsonlite::toJSON(health_status, auto_unbox = TRUE)
    )
    
  } else if (req$REQUEST_METHOD == "POST" && req$PATH_INFO == "/process") {
    if (!startup_steps$server_ready) {
      list(
        status = 503L,
        headers = list("Content-Type" = "application/json"),
        body = jsonlite::toJSON(list(
          message = "Server is still starting up",
          status = "unavailable",
          startup_steps = startup_steps
        ), auto_unbox = TRUE)
      )
    } else {
      log_msg("Processing RMD to PDF request (minimal version)...")
      result <- tryCatch({
        process_rmd_to_pdf_minimal()
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
    }
    
  } else {
    # Default endpoint
    list(
      status = 200L,
      headers = list("Content-Type" = "application/json"),
      body = jsonlite::toJSON(list(
        message = "RMD to PDF Service (Minimal Version)",
        server_ready = startup_steps$server_ready,
        auth_method = "gsutil_minimal",
        endpoints = list(
          "GET /health" = "Health check with detailed status",
          "POST /process" = "Process RMD file to PDF using gsutil"
        )
      ), auto_unbox = TRUE)
    )
  }
}

# Record server start time
server_start_time <- Sys.time()

# Mark server as ready
startup_steps$server_ready <- TRUE
log_msg("=== Server initialization complete (minimal version) ===")
log_msg(sprintf("Server ready on http://0.0.0.0:%d", port))

# Start the HTTP server
tryCatch({
  runServer("0.0.0.0", port, list(call = handle_request))
}, error = function(e) {
  log_msg(sprintf("FATAL: Server failed to start: %s", e$message))
  quit(status = 1)
})