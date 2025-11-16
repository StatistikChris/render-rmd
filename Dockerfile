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

# Copy all processing scripts
COPY simple_auth.R /app/simple_auth.R
COPY auth_helper.R /app/auth_helper.R  
COPY minimal_auth.R /app/minimal_auth.R
COPY process_rmd.R /app/process_rmd.R
COPY process_rmd_minimal.R /app/process_rmd_minimal.R
COPY process_rmd_http.R /app/process_rmd_http.R

# Make the scripts executable
RUN chmod +x /app/*.R

# Copy all server scripts
COPY server-with-logging.R /app/server-with-logging.R
COPY server-minimal.R /app/server-minimal.R
COPY server-simple.R /app/server-simple.R
RUN chmod +x /app/server-*.R

# Expose the port
EXPOSE 8080

# Set the default command to run the simple server (avoids build issues)
CMD ["Rscript", "/app/server-simple.R"]