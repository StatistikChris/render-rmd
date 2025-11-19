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

# Install Google Cloud SDK (gsutil) - this was working before
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    apt-get update -y && apt-get install google-cloud-cli -y

# Copy the install script and run it
COPY install.R /app/install.R
RUN Rscript /app/install.R

# Copy the processing script and server
COPY process_working.R /app/process_working.R
COPY server.R /app/server.R

# Make the scripts executable
RUN chmod +x /app/*.R

# Expose the port
EXPOSE 8080

# Set the default command to run the server
CMD ["Rscript", "/app/server.R"]