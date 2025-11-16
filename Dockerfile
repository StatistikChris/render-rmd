# Use the official R base image with Ubuntu
FROM rocker/r-ver:4.3.2

# Set the working directory
WORKDIR /app

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV R_LIBS_USER=/usr/local/lib/R/site-library

# Install system dependencies required for R packages and PDF generation
RUN apt-get update && apt-get install -y \
    # System dependencies for R packages
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    # Additional dependencies for PDF generation
    pandoc \
    pandoc-citeproc \
    # System utilities
    wget \
    curl \
    ca-certificates \
    # Clean up
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Copy the install script and run it
COPY install.R /app/install.R
RUN Rscript /app/install.R

# Copy the main processing script
COPY process_rmd.R /app/process_rmd.R

# Make the script executable
RUN chmod +x /app/process_rmd.R

# Create a simple HTTP server script for Cloud Run
RUN echo '#!/usr/bin/env Rscript\n\
library(httpuv)\n\
library(jsonlite)\n\
\n\
# Initialize libraries early to catch any loading issues\n\
cat("Loading required libraries...\\n")\n\
library(googleCloudStorageR)\n\
library(rmarkdown)\n\
library(knitr)\n\
cat("Libraries loaded successfully\\n")\n\
\n\
# Source the main processing script\n\
cat("Loading processing script...\\n")\n\
source("/app/process_rmd.R")\n\
cat("Processing script loaded\\n")\n\
\n\
# Track server readiness\n\
server_ready <- FALSE\n\
\n\
# Simple HTTP handler\n\
handle_request <- function(req) {\n\
  if (req$REQUEST_METHOD == "GET" && req$PATH_INFO == "/health") {\n\
    # Health check endpoint - always respond quickly\n\
    if (server_ready) {\n\
      list(\n\
        status = 200L,\n\
        headers = list("Content-Type" = "application/json"),\n\
        body = jsonlite::toJSON(list(status = "healthy", ready = TRUE))\n\
      )\n\
    } else {\n\
      list(\n\
        status = 200L,\n\
        headers = list("Content-Type" = "application/json"),\n\
        body = jsonlite::toJSON(list(status = "starting", ready = FALSE))\n\
      )\n\
    }\n\
  } else if (req$REQUEST_METHOD == "POST" && req$PATH_INFO == "/process") {\n\
    if (!server_ready) {\n\
      list(\n\
        status = 503L,\n\
        headers = list("Content-Type" = "application/json"),\n\
        body = jsonlite::toJSON(list(message = "Server is still starting up", status = "unavailable"))\n\
      )\n\
    } else {\n\
      # Run the PDF processing\n\
      result <- process_rmd_to_pdf()\n\
      \n\
      if (result$status == "success") {\n\
        list(\n\
          status = 200L,\n\
          headers = list("Content-Type" = "application/json"),\n\
          body = jsonlite::toJSON(list(message = result$message, status = "success"))\n\
        )\n\
      } else {\n\
        list(\n\
          status = 500L,\n\
          headers = list("Content-Type" = "application/json"),\n\
          body = jsonlite::toJSON(list(message = result$message, status = "error"))\n\
        )\n\
      }\n\
    }\n\
  } else {\n\
    # Default response\n\
    list(\n\
      status = 200L,\n\
      headers = list("Content-Type" = "application/json"),\n\
      body = jsonlite::toJSON(list(\n\
        message = "RMD to PDF Service",\n\
        ready = server_ready,\n\
        endpoints = list(\n\
          "POST /process" = "Process RMD file to PDF",\n\
          "GET /health" = "Health check"\n\
        )\n\
      ))\n\
    )\n\
  }\n\
}\n\
\n\
# Get port from environment variable (Cloud Run provides this)\n\
port <- as.integer(Sys.getenv("PORT", "8080"))\n\
\n\
cat("Starting server on port", port, "\\n")\n\
\n\
# Start the server with a callback to mark it as ready\n\
cat("Server initialization complete, marking as ready\\n")\n\
server_ready <<- TRUE\n\
\n\
# Start the server\n\
runServer("0.0.0.0", port, list(call = handle_request))' > /app/server.R

# Make the server script executable
RUN chmod +x /app/server.R

# Expose the port
EXPOSE 8080

# Copy the enhanced server script
COPY server-with-logging.R /app/server-with-logging.R
RUN chmod +x /app/server-with-logging.R

# Set the default command to run the HTTP server with enhanced logging
CMD ["Rscript", "/app/server-with-logging.R"]