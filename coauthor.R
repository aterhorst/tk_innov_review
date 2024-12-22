###################################
#
#     Citation Network Analysis
#       Terhorst & Krumpholz
#
###################################


# Load necessary libraries
library(dplyr)
library(tidyr)
library(tidygraph)
library(ggraph)
library(igraph)
library(ggplot2)

# --- Utility function to normalize centrality metrics ---
normalize <- function(x) {
  if (max(x) == min(x)) return(rep(0, length(x))) # Avoid division by zero
  (x - min(x)) / (max(x) - min(x))
}

load("citation_network_data.Rds")

# --- Step 1: Extract Co-Author Nodes and Apply Contribution Weights ---
authors <- article_details_filtered %>%
  filter(cited_by_count > 0, publication_date > 2015) %>%
  unnest(author) %>%
  mutate(au_id = str_remove(au_id, "https://openalex.org/")) %>%
  distinct(article_id, au_id, .keep_all = TRUE) %>%  
  group_by(article_id) %>%
  mutate(
    num_authors = n(), 
    relative_position = if_else(num_authors > 1, (row_number() - 1) / (num_authors - 1), 0), 
    initial_weight = if_else(num_authors == 1, 1, 1 - (relative_position * 0.5)), 
    weight = if_else(num_authors == 1, 1, initial_weight), 
    normalized_weight = weight / sum(weight, na.rm = TRUE)
  ) %>%
  ungroup() %>%
  select(article_id, au_id, au_display_name, institution_display_name, institution_country_code, weight, normalized_weight) 

# --- Optional Check: Ensure all articles have total weight = 1 ---
weight_check <- authors %>%
  group_by(article_id) %>%
  summarise(total_weight = sum(normalized_weight, na.rm = TRUE)) %>%
  filter(abs(total_weight - 1) > 0.001)

if(nrow(weight_check) > 0) {
  warning("Some article weights do not sum to 1.")
  print(weight_check)  
  problematic_articles <- authors %>% filter(article_id %in% weight_check$article_id)
  print(problematic_articles) 
}

# --- Step 2: Create Co-Author Edges with **Weighted Contributions** ---
coauthor_edges <- authors %>%
  group_by(article_id) %>%
  filter(n_distinct(au_id) > 1) %>% 
  summarise(pairs = list(tidyr::expand_grid(from = unique(au_id), to = unique(au_id)))) %>%
  unnest(pairs) %>%
  filter(from != to) %>% 
  mutate(from = pmin(from, to), to = pmax(from, to)) %>% 
  left_join(authors %>% select(article_id, au_id, normalized_weight), 
            by = c("article_id", "from" = "au_id")) %>%
  rename(weight_from = normalized_weight) %>%
  left_join(authors %>% select(article_id, au_id, normalized_weight), 
            by = c("article_id", "to" = "au_id")) %>%
  rename(weight_to = normalized_weight) %>%
  group_by(from, to) %>%
  summarise(
    weight = sum(weight_from * weight_to, na.rm = TRUE), 
    .groups = "drop"
  )

# --- Step 3: Extract Co-Author Nodes ---
coauthor_nodes <- coauthor_edges %>%
  pivot_longer(c(from, to), values_to = "au_id") %>%
  distinct(au_id) %>%
  left_join(authors, by = "au_id") 

# --- Step 4: Build Co-Author Network and Calculate Centrality ---
coauthor_net <- tbl_graph(edges = coauthor_edges, nodes = coauthor_nodes, directed = FALSE) %>%
  activate(nodes) %>%
  filter(!node_is_isolated()) %>%
  mutate(
    degree = centrality_degree(weights = weight),
    betweenness = centrality_betweenness(weights = weight),
    eigenvector = centrality_eigen(weights = weight),
    pagerank = centrality_pagerank(weights = weight)
  )

# --- Step 5: Calculate Influence Metrics and Composite Score ---
influential_authors <- coauthor_net %>%
  as_tibble() %>%
  mutate(
    norm_degree = normalize(degree),
    norm_betweenness = normalize(betweenness),
    norm_pagerank = normalize(pagerank),
    norm_eigenvector = normalize(eigenvector),
    composite_score = rowMeans(cbind(norm_degree, norm_betweenness, norm_pagerank, norm_eigenvector), na.rm = TRUE)
  ) %>%
  arrange(desc(composite_score)) %>%
  select(au_display_name, institution_display_name, institution_country_code, norm_degree, norm_betweenness, norm_pagerank, norm_eigenvector, composite_score)

# --- Step 16: Save Results ---
save(
  authors, 
  coauthor_edges, 
  coauthor_nodes, 
  coauthor_net, 
  influential_authors, 
  file = "coauthor_network_data.Rds"
)

# --- View Top 20 Most Influential Authors ---
top_20_authors <- influential_authors %>%
  slice_head(n = 20) 

print(top_20_authors)

# --- Optional Visualization of Top Authors ---
top_20_authors %>%
  ggplot(aes(x = reorder(au_display_name, composite_score), y = composite_score)) +
  geom_col(fill = "steelblue") +
  coord_flip() +
  labs(
    #title = "Top 20 Influential Authors",
    x = "Author",
    y = "Composite Score"
  ) +
  theme_minimal()

# --- Latex table of Top Authors ---

print(xtable(
  top_20_authors %>%
    select(au_display_name, institution_display_name, institution_country_code, composite_score),
  caption = "Top 20 influential authors.", 
  label = "tab:influential_authors"
),
type = "latex", 
include.rownames = FALSE, 
booktabs = TRUE, 
caption.placement = "top"
)

