library(tidyverse)
library(svysim)


cc16 <- filter(pop_cces, year == 2016)

set.seed(02138)

smallpop <- cc16 %>% sample_n(1e4) %>% select(-Y) %>% rename(Y = Z)
poll     <- smallpop %>% samp_highed(1000)


write_rds(select(smallpop, -Y), "data/pop_microdata.rds", compress = "xz")
write_rds(poll, "data/poll.rds", compress = "xz")
