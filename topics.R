require(tidyverse)
require(openalexR)
require(ggsci)

articles_with_topics <- oa_fetch(
  entity = "works",
  abstract.search = '("tacit knowledge" AND "innovation")',
  verbose = TRUE
)  %>%
  distinct(id, .keep_all = TRUE) %>%
  select(
    article_id = id, 
    concepts,
    topics
    ) %>%
  unnest(topics) 

articles_with_topics_filtered <-
  articles_with_topics %>%
  mutate(article_id = str_remove(article_id, "https://openalex.org/")) %>%
  filter(name == "field") %>%
  inner_join(article_details_filtered %>% select(article_id)) %>%
  select(article_id, field = display_name)

field_counts <- articles_with_topics_filtered %>%
  distinct(article_id, field) %>% 
  group_by(field) %>%
  summarise(total_articles = n(), .groups = 'drop') %>%
  arrange(desc(total_articles))

# --- Plotting

mypal <- rev(pal_d3("category20")(20))

ggplot(field_counts, aes(x = reorder(field, total_articles), y = total_articles, fill = field)) +
  geom_bar(stat = "identity", show.legend = FALSE) +
  coord_flip() +  
  labs(
    #title = "Number of Articles Addressing Field",
    x = "",
    y = "No. of articles"
  ) +
  theme_minimal() +
  
  scale_fill_d3("category20c") +
  theme(
    axis.text.x = element_text(angle = 0, hjust = 0.5),
    axis.text.y = element_text(size = 10)
  )

ggsave("cna_article_fields.pdf", height = 5, width = 7, units = "in")
