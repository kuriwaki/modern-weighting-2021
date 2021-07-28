Overview of Modern Survey Weighting
================

<!-- README.md is generated from README.Rmd. Please edit that file -->

*Shiro Kuriwaki*

*Last presented July 28, 2021*

> “Survey weighting is a mess.” – Gelman (2007)

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

Download this repo by
[creating](https://support.rstudio.com/hc/en-us/articles/200526207-Using-Projects)
a **Rstudio Project** of it (From Version Control Repository, Github,
`"kuriwaki/modern-weighting-workshop-2021"`).

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

## The Power and Simplicity of Poststratification

> “The purpose of poststratification is to correct for known differences
> between sample and population.”

-   Gelman (2007)

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

Q: Extension: Explain how you would do the same reweighting but for
education and race.

-   What is the distribution of race and education in the population?

<!-- -->

    #>                as_factor(race)
    #> as_factor(educ) White Black Hispanic Asian All Other  Sum
    #>    HS or Less    0.21  0.03     0.02  0.00      0.01 0.27
    #>    Some College  0.25  0.05     0.03  0.01      0.02 0.36
    #>    4-Year        0.16  0.03     0.02  0.01      0.01 0.23
    #>    Post-Grad     0.11  0.01     0.01  0.01      0.01 0.15
    #>    Sum           0.73  0.12     0.08  0.03      0.05 1.01

-   In the survey?

<!-- -->

    #>                as_factor(race)
    #> as_factor(educ) White Black Hispanic Asian All Other  Sum
    #>    HS or Less    0.14  0.01     0.00  0.00      0.00 0.15
    #>    Some College  0.24  0.03     0.02  0.00      0.01 0.30
    #>    4-Year        0.22  0.05     0.03  0.01      0.01 0.32
    #>    Post-Grad     0.17  0.01     0.01  0.01      0.01 0.21
    #>    Sum           0.77  0.10     0.06  0.02      0.03 0.98

Q: What are some issues with doing poststratification everywhere?

## Raking as an Approximation

Q: Now suppose you did NOT know the population *joint* distribution of
race x education, but you knew the *marginals*. Suppose that

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

Q: Intuitively, what is the assumption we need to make for raking to
give the same answer as poststratification?

## The Curse of Increased Variance due to Weighting

> “It is not always clear how to use weights in estimating anything more
> complicated than a simple mean or ratios, and standard errors are
> tricky even with simple weighted means.” — Gelman (2007)

Q: What do you need to compute the MSE (or RMSE) of an estimate? What
are the components?

Q: Does weighting tend to increase or decrease the standard error of the
estimator? The effective sample size? The design effect? Why?

## How is MRP Different?

> “Regression modeling is a potentially attractive alter- native to
> weighting. In practice, however, the poten- tial for large numbers of
> interactions can make regres- sion adjustments highly variable. This
> paper reviews the motivation for hierarchical regression, combined
> with poststratification, as a strategy for correcting for differences
> between sample and population. — Gelman (2007)

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

## Why balancing score are better than inverse propensity weighting

> “Contrary to what is assumed by many theoretical statisticians, survey
> weights are not in general equal to inverse probabilities of selection
> but rather are typically constructed based on a combination of prob-
> ability calculations and nonresponse adjustments.” — Gelman (2007)

Q: Using the population data and matching on ID, create a propensity
score.

    #> # A tibble: 10 x 4
    #>    ID     race     educ          Spred
    #>    <chr>  <fct>    <fct>         <dbl>
    #>  1 314876 Hispanic Some College 0.0777
    #>  2 303445 White    4-Year       0.155 
    #>  3 287173 Black    Post-Grad    0.161 
    #>  4 278894 White    Some College 0.0817
    #>  5 298566 Asian    Post-Grad    0.0835
    #>  6 300886 White    4-Year       0.122 
    #>  7 303433 Black    Some College 0.0805
    #>  8 284030 White    Post-Grad    0.262 
    #>  9 318971 Hispanic Post-Grad    0.109 
    #> 10 273789 White    HS or Less   0.0644

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
