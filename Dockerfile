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
\n\
# Source the main processing script\n\
source("/app/process_rmd.R")\n\
\n\
# Simple HTTP handler\n\
handle_request <- function(req) {\n\
  if (req$REQUEST_METHOD == "POST" && req$PATH_INFO == "/process") {\n\
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
  } else if (req$REQUEST_METHOD == "GET" && req$PATH_INFO == "/health") {\n\
    # Health check endpoint\n\
    list(\n\
      status = 200L,\n\
      headers = list("Content-Type" = "application/json"),\n\
      body = jsonlite::toJSON(list(status = "healthy"))\n\
    )\n\
  } else {\n\
    # Default response\n\
    list(\n\
      status = 200L,\n\
      headers = list("Content-Type" = "application/json"),\n\
      body = jsonlite::toJSON(list(\n\
        message = "RMD to PDF Service",\n\
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
# Start the server\n\
runServer("0.0.0.0", port, list(call = handle_request))' > /app/server.R

# Make the server script executable
RUN chmod +x /app/server.R

# Expose the port
EXPOSE 8080

# Set the default command to run the HTTP server
CMD ["Rscript", "/app/server.R"]