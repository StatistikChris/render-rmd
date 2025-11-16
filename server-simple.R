#!/usr/bin/env Rscript

# server-simple.R - Simplest possible server to avoid build issues

library(httpuv)
library(jsonlite)

# Function to log with timestamps
log_msg <- function(msg) {
  cat(sprintf("[%s] %s\n", Sys.time(), msg))
  flush.console()
}

log_msg("=== R Server Starting (Simple HTTP Version) ===")

# Check port configuration
port <- as.integer(Sys.getenv("PORT", "8080"))
log_msg(sprintf("Port configured: %d", port))

# Track startup
server_ready <- FALSE

# Load packages with minimal dependencies
log_msg("Loading required packages...")
tryCatch({
  library(rmarkdown)
  library(knitr)
  library(httr)
  log_msg("Core packages loaded successfully")
}, error = function(e) {
  log_msg(sprintf("ERROR loading packages: %s", e$message))
  quit(status = 1)
})

# Load HTTP processing script
log_msg("Loading HTTP processing script...")
tryCatch({
  source("/app/process_rmd_http.R")
  log_msg("✓ HTTP processing script loaded")
}, error = function(e) {
  log_msg(sprintf("ERROR loading processing script: %s", e$message))
  quit(status = 1)
})

# HTTP request handler
handle_request <- function(req) {
  log_msg(sprintf("Request: %s %s", req$REQUEST_METHOD, req$PATH_INFO))
  
  if (req$REQUEST_METHOD == "GET" && req$PATH_INFO == "/health") {
    list(
      status = 200L,
      headers = list("Content-Type" = "application/json"),
      body = jsonlite::toJSON(list(
        status = "healthy",
        server_ready = server_ready,
        method = "http_api",
        timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S UTC")
      ), auto_unbox = TRUE)
    )
    
  } else if (req$REQUEST_METHOD == "POST" && req$PATH_INFO == "/process") {
    if (!server_ready) {
      list(
        status = 503L,
        headers = list("Content-Type" = "application/json"),
        body = jsonlite::toJSON(list(
          message = "Server is still starting up",
          status = "unavailable"
        ), auto_unbox = TRUE)
      )
    } else {
      log_msg("Processing RMD to PDF request (HTTP API version)...")
      result <- tryCatch({
        process_rmd_to_pdf_http()
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
    list(
      status = 200L,
      headers = list("Content-Type" = "application/json"),
      body = jsonlite::toJSON(list(
        message = "RMD to PDF Service (Simple HTTP Version)",
        server_ready = server_ready,
        method = "http_api",
        endpoints = list(
          "GET /health" = "Health check",
          "POST /process" = "Process RMD file to PDF using HTTP API"
        )
      ), auto_unbox = TRUE)
    )
  }
}

# Mark server as ready
server_ready <- TRUE
log_msg("=== Server initialization complete ===")
log_msg(sprintf("Server ready on http://0.0.0.0:%d", port))

# Start the HTTP server
log_msg("Starting HTTP server...")
tryCatch({
  log_msg("HTTP server running - container will stay alive")
  runServer("0.0.0.0", port, list(call = handle_request))
  log_msg("WARNING: HTTP server stopped unexpectedly")
}, error = function(e) {
  log_msg(sprintf("FATAL: Server failed to start: %s", e$message))
  quit(status = 1)
})

log_msg("ERROR: Server exited - this should not happen")
quit(status = 1)