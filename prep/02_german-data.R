library(tidyverse)
library(svysim)
library(ccesMRPrun)

lbl_region <- function(state_id) {
  names <- recode(state_id, `01` = "Schleswig-Holstein",
                  `02` = "Hamburg", `03` = "Niedersachsen",
                  `04` = "Bremen", `05` = "North Rhine-Westphalia",
                  `06` = "Hesse", `07` = "Rhineland-Palatinate",
                  `08` = "Baden-Württemberg", `09` = "Bavaria",
                  `10` = "Saarland", `11` = "Berlin",
                  `12` = "Brandenburg", `13` = "Mecklenburg-Vorpommern",
                  `14` = "Saxony", `15` = "Saxony-Anhalt",
                  `16` = "Thuringia")
  return(names)
}

df_all <- read_rds("data/mz_1996_2016_clean.rds")

df_yr <- df_all %>%
  filter(year == 2012) %>%
  mutate(state = lbl_region(state_id)) %>%
  relocate(state)



set.seed(02138)
df_sel <- df_yr %>%
  filter(age >= 25) %>%
  filter(east == 1) %>%
  sample_n(1e5, replace = TRUE) %>%
  mutate(state = lbl_region(state_id)) %>%
  select(state, age, female, hhsize = n_people_in_hh,
         matches("employed(_ft|_pt|$)"),
         abitur, poly = poly_gdr,
         married, single, divorced) %>%
  mutate(
    educ = case_when(
      abitur == 1 ~ "Abitur",
      poly == 1 ~ "Vocational",
      TRUE ~ "Not HighEd"),
    marital = case_when(
      married == 1 ~ "Married",
      single == 1 ~ "Single",
      divorced == 1 ~ "Divorced",
      TRUE ~ "Other"
    )
  ) %>%
  mutate(
    educ = fct_relevel(educ, "Not HighEd", "Abitur", "Vocational"),
    marital = fct_relevel(marital, "Married", "Single", "Divorced")
  ) %>%
  relocate(state, female, age, educ, marital, employed)

N <- nrow(df_sel)
df_U <- df_sel %>%
  mutate(ID = 1:n()) %>%
  mutate(pscore = ccesMRPrun:::invlogit(-2 + 1.5*abitur + 1.2*poly*str_detect(state, "Saxony") + 1.1*married + log(age)*divorced - 1.2*(1 - employed_ft) + rnorm(N, 1, 2))) %>%
  mutate(theta = ccesMRPrun:::invlogit(-3 + 2*(1 - employed_ft) + 5*(educ == "No HighEd") - 1.5*abitur + 2*divorced*(1 - female) + rbeta(N, 0.5, 0.5)),
         Y = rbinom(N, size = 1, prob = theta)) %>%
  relocate(ID)
hist(df_U$pscore)
hist(df_U$theta)

set.seed(194301)
df_samp <- samp_pscore(df_U, varname = pscore, n = 1000) %>%
  arrange(ID)

df_pop <- df_U %>%
  mutate(D = as.integer(ID %in% df_samp$ID)) %>%
  arrange(ID) %>%
  relocate(ID, Y, D)

mean(df_pop$Y)
mean(df_samp$Y)
mean(df_pop$employed)
mean(df_samp$employed)
mean(df_pop$abitur)
mean(df_samp$abitur)
cor(df_pop$theta, df_pop$abitur)

write_rds(df_pop, "data/pop_GDR.rds")
write_rds(df_samp, "data/svy_GDR.rds")
