
<!-- README.md is generated from README.Rmd. Please edit that file -->

# Overview of Modern Survey Weighting

*Shiro Kuriwaki*

*July 28, 2021 Workshop*

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

## Poststratification

Q: What is the distributon of education in the sample? In the
population?

    #> # A tibble: 4 x 3
    #>               educ     n frac 
    #>          <dbl+lbl> <int> <chr>
    #> 1 1 [HS or Less]     166 17%  
    #> 2 2 [Some College]   309 31%  
    #> 3 3 [4-Year]         313 31%  
    #> 4 4 [Post-Grad]      212 21%
    #> # A tibble: 4 x 3
    #>               educ     n frac 
    #>          <dbl+lbl> <int> <chr>
    #> 1 1 [HS or Less]    2717 27%  
    #> 2 2 [Some College]  3548 35%  
    #> 3 3 [4-Year]        2323 23%  
    #> 4 4 [Post-Grad]     1412 14%

Q: What are the weights that correct for this imbalance?

    #> # A tibble: 4 x 3
    #>               educ     n wt_frac
    #>          <dbl+lbl> <dbl>   <dbl>
    #> 1 1 [HS or Less]    272.   0.272
    #> 2 2 [Some College]  355.   0.355
    #> 3 3 [4-Year]        232.   0.232
    #> 4 4 [Post-Grad]     141.   0.141

Q: Extension: do the same reweighting but for education and race.

    #>                as_factor(race)
    #> as_factor(educ) White Black Hispanic Asian All Other   Sum
    #>    HS or Less    2137   275      182    36        87  2717
    #>    Some College  2468   538      296    74       172  3548
    #>    4-Year        1611   280      216   122        94  2323
    #>    Post-Grad     1071   106       64   114        57  1412
    #>    Sum           7287  1199      758   346       410 10000

## Raking

Q: What is the distribution of race and education in the survey.

Now suppose you did NOT know the population *joint* distribution of race
x education, but you knew the *marginals*. Suppose that

-   White (1): 72%
-   Black (2): 12%
-   Hispanic (3) : 10%
-   Asian (4): 3%
-   Other (5): 3%

and

-   HS or Less (1): 40%
-   Some College (2): 35%
-   4-Year (3): 15%
-   Post-grad (4): 10%

![](README_files/figure-gfm/cces_rake_weights-1.png)<!-- -->

Q: What are some issues with doing poststratiifcation everywhere?

## Increased Variance Due to Weighting / Design Effect

Q: What do you need to compute the MSE (or RMSE) of an estimate? What
are the components?

Q: Does weighting tend to increase or decrease the standard error of the
estimator? The effective sample size? The design effect? Why?

## How is MRP Different?

Let’s treat the values as factors now

``` r
poll_fct <- poll %>% 
  mutate(educ = as_factor(educ), race = as_factor(race))

pop_fct <- pop_micro %>% 
  mutate(educ = as_factor(educ), race = as_factor(race)) 

tgt_fct <- pop_fct %>% 
  count(educ, race)
```

Q: Using a logit, what are the predicted values of the outcome in each
of the poststratification cells?

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

Q: What is the “MRP” estimate for Y in the population then?

    #> # A tibble: 1 x 1
    #>   Ypred
    #>   <dbl>
    #> 1 0.412

Q: What are the issues with a simple logit?

## Propensity Score (IPW) vs. Balancing Score

Q: Using the population data and matching on ID, create a propensity
score.

    #> # A tibble: 10 x 4
    #>    ID     race     educ          Spred
    #>    <chr>  <fct>    <fct>         <dbl>
    #>  1 268448 White    Some College 0.0986
    #>  2 303033 White    Some College 0.0817
    #>  3 281458 White    Some College 0.0993
    #>  4 305564 White    HS or Less   0.122 
    #>  5 279835 White    HS or Less   0.0896
    #>  6 319874 White    HS or Less   0.0634
    #>  7 273231 Black    Post-Grad    0.161 
    #>  8 311155 Hispanic Some College 0.0798
    #>  9 265916 White    HS or Less   0.0517
    #> 10 271471 White    Some College 0.0993

Q: What are the issues in Propensity Score?

Note: Links to Causal Inference and the Weighting vs. Matching
Distinction

-   Coarsened Exact Matching
-   Balance Test Fallacy

Note: Balancing Scores: Entropy Balancing / CBPS

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
