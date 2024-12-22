# Load necessary libraries
library(tidyverse)
library(httr)
library(jsonlite)

# --- Utility Function to Download PDF ---
download_pdf <- function(pdf_url, doi) {
  if (!is.null(pdf_url)) {
    file_name <- paste0(gsub("[/:]", "_", doi), ".pdf")
    tryCatch({
      download.file(pdf_url, file_name, mode = "wb")
      message("Downloaded PDF for DOI: ", doi)
    }, error = function(e) {
      message("Failed to download: ", doi, " - ", e$message)
    })
  } else {
    message("No valid PDF link found for DOI: ", doi)
  }
}

# --- Utility Function to Get PDF Link from Different Sources ---
get_pdf_link <- function(doi, source = "unpaywall", core_api_key = NULL, email = NULL) {
  pdf_url <- NULL
  
  if (source == "unpaywall") {
    api_url <- paste0("https://api.unpaywall.org/v2/", doi, "?email=", email)
    response <- GET(api_url)
    if (status_code(response) == 200) {
      data <- content(response, as = "parsed", type = "application/json")
      if (!is.null(data$best_oa_location$url_for_pdf)) {
        pdf_url <- data$best_oa_location$url_for_pdf
      } else {
        message("No open-access PDF found for DOI (Unpaywall): ", doi)
      }
    } else {
      message("Failed to fetch data from Unpaywall for DOI: ", doi)
    }
    
  } else if (source == "core") {
    api_url <- "https://api.core.ac.uk/v3/discover"
    payload <- list(doi = doi)
    response <- POST(
      url = api_url,
      add_headers(Authorization = paste("Bearer", core_api_key)),
      body = payload,
      encode = "json"
    )
    if (status_code(response) == 200) {
      data <- content(response, as = "parsed", type = "application/json")
      if (!is.null(data$fullTextLink)) {
        pdf_url <- data$fullTextLink
      } else {
        message("No PDF found on CORE for DOI: ", doi)
      }
    } else {
      message("Failed to fetch data from CORE for DOI: ", doi)
    }
    
  } else if (source == "oab") {
    api_url <- paste0("https://api.openaccessbutton.org/find?doi=", doi)
    response <- GET(api_url)
    if (status_code(response) == 200) {
      data <- content(response, as = "parsed", type = "application/json")
      if (!is.null(data$url)) {
        pdf_url <- data$url
      } else {
        message("No PDF found on Open Access Button for DOI: ", doi)
      }
    } else {
      message("Failed to fetch data from Open Access Button for DOI: ", doi)
    }
  }
  
  return(pdf_url)
}

# --- Main Execution Section ---
# Load top articles and extract DOIs
dois <- top_articles %>%
  pull(url) %>%
  as_tibble() %>%
  mutate(file_name = paste0(gsub("[/:]", "_", value), ".pdf"))

# List of existing PDF files
pdfs <- read_lines("~/OneDrive - CSIRO/Projects/openalex/pdfs/dir_list.txt") %>%
  as_tibble() %>%
  rename(file_name = value)

# Find files to keep, discard, and those that are missing
files_to_keep <- intersect(dois$file_name, pdfs$file_name)
files_to_discard <- setdiff(pdfs$file_name, dois$file_name)
files_missing <- setdiff(dois$file_name, pdfs$file_name)

cat("Files to keep:\n", files_to_keep, "\n")
cat("Files to discard:\n", files_to_discard, "\n")
cat("Missing files:\n", files_missing, "\n")

# Extract missing DOIs for download
df_files_missing <- data.frame(file_name = files_missing) %>%
  inner_join(dois, by = "file_name")

dois_missing <- df_files_missing %>% pull(value)

# --- Download Missing PDFs from Unpaywall, CORE, and Open Access Button ---
core_api_key <- "zc5DtvknZ4HsT06KEpW2FhBMwLlXJCNV"
email <- "andrew.terhorst@csiro.au"

for (doi in dois_missing) {
  # Try to get PDF link from Unpaywall
  pdf_link <- get_pdf_link(doi, source = "unpaywall", email = email)
  if (!is.null(pdf_link)) {
    download_pdf(pdf_link, doi)
    next
  }
  
  # If Unpaywall failed, try CORE
  pdf_link <- get_pdf_link(doi, source = "core", core_api_key = core_api_key)
  if (!is.null(pdf_link)) {
    download_pdf(pdf_link, doi)
    next
  }
  
  # If CORE failed, try Open Access Button
  pdf_link <- get_pdf_link(doi, source = "oab")
  if (!is.null(pdf_link)) {
    download_pdf(pdf_link, doi)
    next
  }
  
  message("No PDF found for DOI: ", doi, " in Unpaywall, CORE, or Open Access Button.")
}
