# install.R - Install required R packages for the Docker container

# Set CRAN mirror
options(repos = c(CRAN = "https://cran.rstudio.com/"))

# List of required packages
required_packages <- c(
  "rmarkdown",     # For rendering R Markdown documents
  "knitr",         # Required by rmarkdown
  "tinytex",       # Lightweight LaTeX distribution for PDF generation
  "googleCloudStorageR",  # Google Cloud Storage client
  "googleAuthR",   # Google authentication (required for GCS auth)
  "httr",          # HTTP requests (dependency for googleCloudStorageR)
  "jsonlite",      # JSON parsing (dependency for googleCloudStorageR)
  "curl",          # URL handling
  "openssl",       # Cryptographic functions
  "base64enc",     # Base64 encoding/decoding
  "httpuv"         # HTTP server for Cloud Run
)

# Function to install packages if not already installed
install_if_missing <- function(package_name) {
  if (!require(package_name, character.only = TRUE, quietly = TRUE)) {
    cat(paste("Installing package:", package_name, "\n"))
    install.packages(package_name, dependencies = TRUE)
    
    # Verify installation
    if (!require(package_name, character.only = TRUE, quietly = TRUE)) {
      stop(paste("Failed to install package:", package_name))
    }
  } else {
    cat(paste("Package already installed:", package_name, "\n"))
  }
}

# Install TinyTeX for LaTeX support (required for PDF generation)
install_tinytex <- function() {
  cat("Installing TinyTeX for PDF generation...\n")
  if (!tinytex::is_tinytex()) {
    tinytex::install_tinytex(force = TRUE)
  }
  cat("TinyTeX installation completed.\n")
}

# Main installation process
cat("Starting package installation...\n")

# Install required packages
for (package in required_packages) {
  install_if_missing(package)
}

# Install TinyTeX after installing the tinytex package
install_tinytex()

cat("All packages installed successfully!\n")

# Verify installations by loading key packages
cat("Verifying package installations...\n")
library(rmarkdown)
library(googleCloudStorageR)
library(knitr)

cat("Package verification completed successfully!\n")