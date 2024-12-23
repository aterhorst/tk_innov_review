###################################
#
#     Citation Network Analysis
#       Terhorst & Krumpholz
#
###################################

# Load necessary libraries
library(openalexR)
library(tidyverse)
library(tidygraph)
library(ggraph)
library(ggsci)
library(lubridate)
library(httr)
library(jsonlite)

# --- Utility function to normalize centrality metrics ---
normalize <- function(x) {
  if (max(x, na.rm = TRUE) == min(x, na.rm = TRUE)) return(rep(0, length(x))) # Avoid division by zero
  (x - min(x, na.rm = TRUE)) / (max(x, na.rm = TRUE) - min(x, na.rm = TRUE))
}

# --- Step 1: Fetch Initial Articles ---
articles <- oa_fetch(
  entity = "works",
  abstract.search = '("tacit knowledge" AND "innovation")',
  verbose = TRUE
) %>%
  distinct(id, .keep_all = TRUE) %>%
  select(
    article_id = id, 
    title, 
    abstract = ab, 
    publication_date, 
    source = so, 
    author,
    cited_by_count, 
    language
  ) %>%
  mutate(
    article_id = str_remove(article_id, "https://openalex.org/"),
    publication_date = as.Date(publication_date)
  )

# --- Step 2: Filter Articles ---
articles_filtered <- articles %>%
  filter(
    publication_date > as.Date("2015-01-01") & 
      cited_by_count > 0 & 
      language == "en"
  )

# --- Step 3: Function to fetch citing articles with retry logic ---
fetch_citing_articles <- function(article_id) {
  cited_by_api_url <- paste0("https://api.openalex.org/works?filter=cites:", article_id)
  all_results <- list()
  page <- 1
  max_retries <- 5
  
  repeat {
    paginated_url <- paste0(cited_by_api_url, "&page=", page)
    tryCatch({
      response <- RETRY("GET", paginated_url, times = max_retries, pause_min = 1, pause_cap = 5)
      
      if (status_code(response) == 200) {
        parsed <- fromJSON(content(response, "text", encoding = "UTF-8"), flatten = TRUE)
        if (length(parsed$results) == 0) break
        all_results <- c(all_results, parsed$results$id)
        page <- page + 1
      } else if (status_code(response) == 429) {
        retry_after <- as.numeric(headers(response)$`retry-after`)
        retry_time <- ifelse(is.na(retry_after), 5, retry_after)
        message(paste("Rate limit hit. Retrying after", retry_time, "seconds..."))
        Sys.sleep(retry_time)
      } else {
        warning(paste0("Failed to fetch citing articles for ID: ", article_id))
        break
      }
    }, error = function(e) {
      warning(paste0("Error fetching citing articles for ID: ", article_id, " - ", e$message))
      break
    })
  }
  
  return(all_results)
}

# --- Step 4: Fetch citing articles ---
articles_filtered <- articles_filtered %>%
  rowwise() %>%
  mutate(citing_article_ids = list(fetch_citing_articles(article_id))) %>%
  ungroup()

# --- Step 5: Create Edge List ---
edge_list <- articles_filtered %>%
  filter(!is.na(citing_article_ids)) %>%
  unnest(citing_article_ids) %>%
  select(from = citing_article_ids, to = article_id) %>%
  mutate(
    from = str_remove(from, "https://openalex.org/"),
    to = str_remove(to, "https://openalex.org/")
  ) %>%
  count(from, to, name = "weight")

# --- Step 6: Fetch metadata for all articles in the edge list ---
all_article_ids <- edge_list %>%
  pivot_longer(c(from, to), values_to = "article_id") %>%
  distinct(article_id)

# Get details for all articles in the edge list (both from and to)
article_details <- oa_fetch(
  entity = "works",
  identifier = all_article_ids$article_id,
  verbose = TRUE
) %>%
  select(
    id,
    title = display_name,
    abstract = ab,
    source = so,
    url,
    publication_date,
    cited_by_count,
    author,
    type,
    language
  ) %>%
  mutate(article_id = gsub("https://openalex.org/", "", id))

# --- Step 7: **Filter Citing Articles** ---
# Filter articles where the abstract mentions "tacit" or "innov"
article_details_filtered <- article_details %>%
  filter(!is.na(abstract) & str_detect(abstract, "(?i)tacit|innov") & cited_by_count > 0)

# Get list of **filtered citing article_ids** (for "from" column)
all_article_ids_from <- article_details_filtered %>%
  select(article_id) %>%
  distinct()

# --- Step 8: Filter edge list to include only filtered citing articles ---
# Retain only the "from" articles that match the filtered list
edge_list_filtered <- edge_list %>%
  inner_join(all_article_ids_from, by = c("from" = "article_id")) # Filter "from" citing articles

# Check edge consistency
if (nrow(edge_list_filtered) == 0) {
  stop("No valid edges found after filtering. Verify data consistency.")
}

nodes_filtered <- edge_list_filtered %>%
  pivot_longer(c(to, from), values_to = "article_id") %>%
  distinct(article_id) %>%
  left_join(article_details_filtered)

# --- Step 9: Create Citation Network and Calculate Centrality Metrics ---
g <- tbl_graph(nodes = nodes_filtered, edges = edge_list_filtered, directed = TRUE) %>%
  activate(nodes) %>%
  filter(cited_by_count > 0 & publication_date >= 2015 & language == "en") %>%
  mutate(
    in_degree = centrality_degree(mode = "in"),
    pagerank = centrality_pagerank(),
    betweenness = centrality_betweenness(),
    eigenvector = centrality_eigen(),
    component = group_components(type = "weak")
  )

# --- Step 10: Identify Top 50 Influential Articles ---
top_articles <- g %>%
  activate(nodes) %>%
  as_tibble() %>%
  # filter out non-English articles
  filter(article_id != "W3022073608") %>% 
  mutate(
    composite_score = rowMeans(cbind(
      normalize(in_degree),
      normalize(pagerank),
      normalize(betweenness),
      normalize(eigenvector)
    ), na.rm = TRUE)
  ) %>%
  filter(component == 1) %>%
  slice_max(order_by = composite_score, n = 50, with_ties = FALSE)

# --- Step 11: Plot Citation Network ---
mypal <- rev(pal_flatui()(10))

ggraph(g %>% activate(nodes) %>% 
         filter(component == 1) %>%
         mutate(
           year = as.factor(year(publication_date)),
           composite_score = rowMeans(cbind(
             normalize(in_degree),
             normalize(pagerank),
             normalize(betweenness),
             normalize(eigenvector)
           ), na.rm = TRUE)
         ), 
       layout = "kk") +
  geom_edge_link(color = "grey", alpha = 0.5) +
  geom_node_point(aes(size = composite_score, colour = year)) +
  scale_color_manual(values = mypal, name = "Publication year") +
  theme_void() +
  guides(size = "none") 

ggsave("citation_network.pdf", height = 7, width = 9, units = "in")

# --- Step 12: Save Results ---
save(
  articles, 
  articles_filtered, 
  edge_list, 
  article_details, 
  article_details_filtered, 
  edge_list_filtered, 
  g, 
  top_articles, 
  file = "citation_network_data.Rds"
)



