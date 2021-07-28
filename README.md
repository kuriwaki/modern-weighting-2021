
<!-- README.md is generated from README.Rmd. Please edit that file -->

# An Introduction to Modern Weighting

**Shiro Kuriwaki**

**July 28, 2021 Workshop**

<!-- badges: start -->
<!-- badges: end -->

Reweighting to make a dataset representative is a core operation in data
science and survey research, with equally fundamental connection to
classical statistical theory. Moreover, the connection between survey
inference to causal inference is resurging as selection bias has become
a more prominent problem in opt-in surveys, and traditional approaches
that focus on researcher-designed sampling become somewhat irrelevant.
However, survey weighting is not taught in standard political science
graduate training. Here I walk through the core concepts by drawing
connections to concepts that are more frequently covered in political
science training, like causal inference or machine learning. I presume a
level of familiarity with a 1st year PhD methods class covering
bias-variance, OLS, and a bit of research design.

------------------------------------------------------------------------

## Setup

Download this repo as a **Rstudio Project** (From Remote Repository,
Github, `"kuriwaki/modern-weighting-workshop-2021"`).

Load libraries

``` r
library(tidyverse) # Easily Install and Load the 'Tidyverse'
library(scales) # Scale Functions for Visualization

library(survey) # Analysis of Complex Survey Samples
library(autumn) # Fast, Modern, and Tidy-Friendly Iterative Raking
library(lme4) # Linear Mixed-Effects Models using 'Eigen' and S4
```

Read in data as

``` r
poll <- read_rds("data/poll.rds")
pop_micro <- read_rds("data/pop_microdata.rds")
```

# Poststratification

Q: What is the distributon of education in the sample? In the
population?

``` r
poll %>% count(educ) %>% mutate(frac = percent(n / sum(n), accuracy = 1))
#> # A tibble: 4 x 3
#>               educ     n frac 
#>          <dbl+lbl> <int> <chr>
#> 1 1 [HS or Less]     166 17%  
#> 2 2 [Some College]   309 31%  
#> 3 3 [4-Year]         313 31%  
#> 4 4 [Post-Grad]      212 21%
pop_micro %>% count(educ) %>% mutate(frac = percent(n / sum(n), accuracy = 1))
#> # A tibble: 4 x 3
#>               educ     n frac 
#>          <dbl+lbl> <int> <chr>
#> 1 1 [HS or Less]    2717 27%  
#> 2 2 [Some College]  3548 35%  
#> 3 3 [4-Year]        2323 23%  
#> 4 4 [Post-Grad]     1412 14%
```

Q: What are the weights that correct for this imbalance?

``` r
edu_tgt <- pop_micro %>% count(educ) %>% transmute(educ, pop_frac = n / sum(n))

poll_strat <- poll %>% 
  count(educ) %>% 
  mutate(samp_frac = n / sum(n)) %>% 
  left_join(edu_tgt, by = "educ") %>% 
  mutate(weight0 = pop_frac / samp_frac)

poll_wt <- poll %>% 
  left_join(poll_strat, by = "educ")

poll_wt %>% 
  count(educ, wt = weight0) %>% 
  mutate(wt_frac = n / sum(n))
#> # A tibble: 4 x 3
#>               educ     n wt_frac
#>          <dbl+lbl> <dbl>   <dbl>
#> 1 1 [HS or Less]    272.   0.272
#> 2 2 [Some College]  355.   0.355
#> 3 3 [4-Year]        232.   0.232
#> 4 4 [Post-Grad]     141.   0.141
```

Q: Extension: do the same reweighting but for education and race.

``` r
xtabs(~ as_factor(educ) + as_factor(race), pop_micro) %>% 
  addmargins()
#>                as_factor(race)
#> as_factor(educ) White Black Hispanic Asian All Other   Sum
#>    HS or Less    2137   275      182    36        87  2717
#>    Some College  2468   538      296    74       172  3548
#>    4-Year        1611   280      216   122        94  2323
#>    Post-Grad     1071   106       64   114        57  1412
#>    Sum           7287  1199      758   346       410 10000
```

# Raking

Q: What is the distribution of race and education in the survey.

Now suppose you did NOT know the population *joint* distribution of race
x education, but you knew the *marginals*. Suppose that

-   White: 70%
-   Black: 12%
-   Hispanic: 8%
-   Asian: 4%
-   Other 6%

and

-   HS or Less (1): 40%
-   Some College (2): 35%
-   4-Year (3): 15%
-   Post-grad (4): 10%

``` r
target_rake <- list(
  race = c(`1` = 0.70, `2` = 0.12, `3` = 0.08, `4` = 0.04, `5` = 0.06),
  educ = c(`1` = 0.40, `2` = 0.35, `3` = 0.15, `4` = 0.10)
)

poll_rake <- harvest(poll,  target_rake, weight_column = "rake_weight")
```

![](README_files/figure-gfm/cces_rake_weights-1.png)<!-- -->

Q: What are some issues with doing poststratiifcation everywhere?

# Increased Variance Due to Weighting / Design Effect

Mean Square Error formula

Q: What do you need to compute the MSE (or RMSE) of an estimate? What
are the components?

Q: Does weighting tend to increase or decrease the standard error of the
estimator? The effective sample size? The design effect? Why?

Kish’s design effect

``` r
rwt <- poll_rake$rake_weight

sum(rwt)^2 / sum(rwt^2)
#> [1] 627.6017

nrow(poll_rake) / (sum(rwt)^2 / sum(rwt^2))
#> [1] 1.593367

var(rwt)
#> [1] 0.5939613

design_effect(rwt)
#> [1] 1.593367
```

# MRP

``` r
poll_fct <- poll %>% 
  mutate(educ = as_factor(educ), race = as_factor(race))

pop_fct <- pop_micro %>% 
  mutate(educ = as_factor(educ), race = as_factor(race)) 

tgt_fct <- pop_fct %>% 
  count(educ, race)
```

Many cells problem

``` r
fit_logit <- glm(Y ~ educ*race, data = poll_fct, family = binomial)


cells_Ypred <- tgt_fct %>% 
  mutate(Ypred = predict(fit_logit, ., type = "response"))

cells_Ypred
#> # A tibble: 20 x 4
#>    educ         race          n      Ypred
#>    <fct>        <fct>     <int>      <dbl>
#>  1 HS or Less   White      2137 0.451     
#>  2 HS or Less   Black       275 0.500     
#>  3 HS or Less   Hispanic    182 0.400     
#>  4 HS or Less   Asian        36 0.00000349
#>  5 HS or Less   All Other    87 0.250     
#>  6 Some College White      2468 0.375     
#>  7 Some College Black       538 0.394     
#>  8 Some College Hispanic    296 0.526     
#>  9 Some College Asian        74 0.333     
#> 10 Some College All Other   172 0.286     
#> 11 4-Year       White      1611 0.391     
#> 12 4-Year       Black       280 0.438     
#> 13 4-Year       Hispanic    216 0.621     
#> 14 4-Year       Asian       122 0.538     
#> 15 4-Year       All Other    94 0.250     
#> 16 Post-Grad    White      1071 0.422     
#> 17 Post-Grad    Black       106 0.533     
#> 18 Post-Grad    Hispanic     64 0.300     
#> 19 Post-Grad    Asian       114 0.250     
#> 20 Post-Grad    All Other    57 0.500
```

``` r
cells_Ypred %>% 
  summarize(Ypred = weighted.mean(Ypred, w = n))
#> # A tibble: 1 x 1
#>   Ypred
#>   <dbl>
#> 1 0.412
```

Shrinkage

# Propensity Score (IPW) vs. Balancing Score

Q: Using the population data and matching on ID, create a propensity
score.

``` r
pop_sel <- left_join(
  pop_fct,
  transmute(poll_fct, ID, S = 1),
  by = "ID"
) %>% 
  mutate(S = replace_na(S, 0))

fit_sel <- glm(S ~ race + educ + state, pop_sel, family = binomial)

pop_sel %>% 
  mutate(Spred = predict(fit_sel, ., type = "response")) %>% 
  select(ID, race, educ, Spred) %>% 
  sample_n(10)
#> # A tibble: 10 x 4
#>    ID     race     educ          Spred
#>    <chr>  <fct>    <fct>         <dbl>
#>  1 275052 White    Post-Grad    0.117 
#>  2 307820 White    HS or Less   0.0689
#>  3 314979 White    Some College 0.0993
#>  4 278490 White    HS or Less   0.0727
#>  5 300603 Hispanic HS or Less   0.0506
#>  6 317244 White    HS or Less   0.0950
#>  7 312610 White    Some College 0.102 
#>  8 274760 Black    4-Year       0.117 
#>  9 323001 White    Post-Grad    0.168 
#> 10 273101 Black    4-Year       0.134
```

Q: What are the issues in Propensity Score

Links to Causal Inference and the Weighting vs. Matching Distinction

-   Coarsened Exact Matching
-   Balance Test Fallacy

Balancing Scores: Entropy Balancing / CBPS

# Takeaways

1.  **Survey inference is causal inference** where the treatment is
    selection
2.  Total Error is **Bias^2 + Variance**
3.  Many things work “in theory” (asymptotically) but cause **variance
    problems** in practice: post-stratification, inverse propensity
    score weighting
4.  **Shrinkage** and regularization (random effects, ML) reduces
    variance at the cost of minimal variance
5.  **Balancing scores** guarantees balance on some marginals, while
    minimizing distance on others.

# References

-   Devin Caughey, Adam Berinsky, Susan Chatfield, Erin Hartman, Eric
    Schickler, and Jas Sekhon. 2020. “Target Estimation and Adjustment
    Weighting for Survey Nonresponse and Sampling Bias”. *Elements in
    Quantitative and Computational Methods for the Social Sciences*

-   Andrew Gelman.
    [2007](http://www.stat.columbia.edu/~gelman/research/published/STS226.pdf).
    “Struggles with Survey Weighting and Regression Modeling”,
    *Statistical Science*

-   Paul Rosenbaum, Donald Rubin. \[1983\]. “The central role of the
    propensity score in observational studies for causal effects”.
    *Biometrika*

-   Kosuke Imai, Gary King, Elizabeth A Stuart.
    [2008](https://imai.fas.harvard.edu/research/files/matchse.pdf).
    “Misunderstandings between experimentalists and observationalists
    about causal inference”, *JRSS A.*

    -   Also see: Gary King.
        [2007](https://www.youtube.com/watch?v=rBv39pK1iEs). “Why
        Propensity Scores Should Not Be Used for Matching”, *Methods
        Colloquium Talk*. (Article with Rich Nielsen).

-   Kosuke Imai, Marc Ratkovic.
    [2014](https://imai.fas.harvard.edu/research/files/CBPS.pdf).
    “Covariate balancing propensity score”, *JRSS B*.

-   Jens Hainmueller.
    [2012](https://web.stanford.edu/~jhain/Paper/PA2012.pdf). “Entropy
    Balancing for Causal Effects: A Multivariate Reweighting Method to
    Produce Balanced Samples in Observational Studies”. *Political
    Analysis*
