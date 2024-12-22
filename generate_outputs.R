###################################
#
#     Citation Network Analysis
#       Terhorst & Krumpholz
#
###################################

# Load necessary libraries
require(tidyverse)
require(xtable)
require(jsonlite)
require(tidygraph)

# Retrieve pre-processed data
load("citation_network_data.Rds")
load("coauthor_network_data.Rds")

# --- Network statistics

citation_network_summary <- data.frame(
  total_nodes = g %>% activate(nodes) %>% as_tibble() %>% nrow(),
  total_edges = g %>% activate(edges) %>% as_tibble() %>% nrow(),
  density = igraph::edge_density(as.igraph(g)),  
  components = g %>% activate(nodes) %>% pull(component) %>% n_distinct(),  
  largest_component_size = g %>% 
    activate(nodes) %>%
    filter(component == 1) %>%
    as_tibble() %>% 
    nrow(),  
  average_degree = g %>% activate(nodes) %>% mutate(degree = centrality_degree()) %>% as_tibble() %>% pull(degree) %>% mean(),
  average_clustering_coefficient = igraph::transitivity(as.igraph(g), type = "global"),  
  diameter = igraph::diameter(as.igraph(g), directed = TRUE, unconnected = TRUE),  
  average_path_length = igraph::mean_distance(as.igraph(g), directed = TRUE, unconnected = TRUE)
) %>%
  pivot_longer(1:9,names_to = "Metric", values_to =  "Value")

coauthor_network_summary <- data.frame(
  total_nodes = coauthor_net %>% activate(nodes) %>% as_tibble() %>% nrow(),
  total_edges = coauthor_net %>% activate(edges) %>% as_tibble() %>% nrow(),
  density = igraph::edge_density(as.igraph(coauthor_net)),  
  components = coauthor_net %>% activate(nodes) %>% mutate(component = group_components(type = "weak")) %>% pull(component) %>% n_distinct(),
  largest_component_size = coauthor_net %>% 
    activate(nodes) %>%
    mutate(component = group_components(type = "weak")) %>%
    filter(component == 1) %>%
    as_tibble() %>% 
    nrow(), 
  average_degree = coauthor_net %>% activate(nodes) %>% mutate(degree = centrality_degree()) %>% as_tibble() %>% pull(degree) %>% mean(),
  average_clustering_coefficient = igraph::transitivity(as.igraph(coauthor_net), type = "global"), 
  diameter = igraph::diameter(as.igraph(coauthor_net), directed = TRUE, unconnected = TRUE),  
  average_path_length = igraph::mean_distance(as.igraph(coauthor_net), directed = TRUE, unconnected = TRUE)  
) %>%
  pivot_longer(1:9,names_to = "Metric", values_to =  "Value")

network_summary_clean <- network_summary %>% select(-Network)
coauthor_network_summary_clean <- coauthor_network_summary %>% select(-Network)

combined_stats <- full_join(network_summary_clean, coauthor_network_summary_clean, by = "Metric")

print(xtable(combined_stats %>%
               mutate(
                 Citation_Network_Value = formatC(Citation_Network_Value, format = "f", digits = 4),
                 Coauthor_Network_Value = formatC(Coauthor_Network_Value, format = "f", digits = 4)
               ), 
             caption = "Basic graph statistics for the citation and co-author networks", 
             label = "tab:top_20_articles"),
      type = "latex", 
      caption.placement = "top", 
      include.rownames = FALSE,  # Exclude row names
      booktabs = TRUE
)

# --- Top 20 articles

top_20_articles <- articles_filtered %>%
  slice_max(order_by = cited_by_count, n = 20, with_ties = F) %>%
  unnest(author) %>%
  group_by(title, source, publication_date, cited_by_count) %>%
  summarise(authors = paste(au_display_name, collapse = ", "), .groups = "drop") %>%
  arrange(desc(cited_by_count)) %>%
  select(title, source, authors, cited_by_count)

print(xtable(top_20_articles, 
             caption = "Top 20 most-cited articles on tacit knowledge and innovation", 
             label = "tab:top_20_articles"),
      type = "latex", 
      caption.placement = "top", 
      include.rownames = FALSE,  # Exclude row names
      booktabs = TRUE
      )

# --- Top 20 venues ---

print(xtable(
  articles_filtered %>%
    group_by(source) %>%
    count() %>%
    ungroup() %>%
    drop_na() %>%
    slice_max(n = 20, order_by = n, with_ties = FALSE),
  caption = "Top publication venues", 
  label = "tab:top_pubs"
),
type = "latex", 
include.rownames = FALSE,  
booktabs = TRUE,           
caption.placement = "top"
)

# --- Top 50 articles from the CNA

top_cna_articles <- top_articles %>%
  unnest(author) %>%
  group_by(title, source, publication_date, cited_by_count, composite_score) %>%
  summarise(authors = paste(au_display_name, collapse = ", "), .groups = "drop") %>%
  arrange(desc(composite_score)) %>%
  select(title, authors, cited_by_count, composite_score)

print(xtable(top_cna_articles, 
             caption = "Top 50 most-influential articles according to centrality measures", 
             label = "tab:top_articles"),
      type = "latex", 
      caption.placement = "top", 
      include.rownames = FALSE,  # Exclude row names
      booktabs = TRUE
)

# --- Generate citations per year plot ---

ggplot(articles %>%
         mutate(year = lubridate::year(publication_date)) %>%
         filter(year >= 1990 & year < 2024) %>%
         group_by(year) %>%
         count()) +
  geom_col(aes(x = year, y = n, fill = ifelse(year < 2015, "grey", "darkorange"))) +
  theme_minimal() + 
  xlab("Publication year") +
  ylab("Article count") +
  scale_fill_identity() +
  scale_x_continuous(breaks = as.numeric(seq(1990, 2024, by = 2))) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        axis.title.x = element_text(margin = margin(t = 10)))

ggsave("citation_year.pdf", height = 4, width = 7, units = "in")

# --- Definitions

definitions <- fromJSON("/Users/ter053/PycharmProjects/tacit_innovation/definitions_innovation_output.json") %>%
  select(json_definition) %>%
  unnest(cols = c(json_definition)) %>%
  filter(!str_detect(`Source of definition`, "No source")) %>%
  select(-c(Title, `Source of definition`))

print(xtable(definitions %>% select(Authors, Year = `Publication Year`, Definition),
             caption = "Definitions of tacit knowledge extracted from the top 50 articles.", # Add caption
             label = "tab:definition"),
      type = "latex", 
      include.rownames = F,  
      booktabs = TRUE,       
      caption.placement = "top") 

# --- Summaries

summaries <- fromJSON("/Users/ter053/PycharmProjects/tacit_innovation/synthesized_innovation_with_titles_and_authors.json") %>%
  as_tibble() %>%
  unnest(Themes)

# --- Definitions

definitions <- fromJSON("/Users/ter053/PycharmProjects/tacit_innovation/definitions_innovation_output.json") %>%
  select(json_definition) %>%
  unnest(cols = c(json_definition)) %>%
  filter(!str_detect(`Source of definition`, "No source")) %>%
  select(-c(Title))

definitions_table <- xtable(definitions)

print(definitions_table, 
      type = "latex", 
      include.rownames = F,  # Exclude row names
      booktabs = TRUE,           # Use booktabs style
      caption.placement = "top", # Place the caption above the table
      caption = "Definitions of tacit knowledge extracted from the top 50 articles.", # Add caption
      label = "tab:definition") # Add label

# cluster analysis

test <- article_details %>
