# Standardize rater-mediated score data

Standardize rater-mediated score data

## Usage

``` r
df_data(x, person = "person", item = "item", rater = "rater", score = "score")
```

## Arguments

- x:

  A data frame in long format, one row per person x item x rater score.

- person, item, rater, score:

  Column names in \`x\`.

## Value

A \`df_data\` data frame with character ids and 0-based integer scores;
attribute \`K\` is the highest category.

## Examples

``` r
raw <- data.frame(cand = c("A", "A", "B", "B"), task = "T1",
                  examiner = c("R1", "R2", "R1", "R2"), rating = c(3, 4, 2, 2))
df_data(raw, person = "cand", item = "task", rater = "examiner", score = "rating")
#> Shifting scores so the lowest category is 0 (was 2).
#>   person item rater score
#> 1      A   T1    R1     1
#> 2      A   T1    R2     2
#> 3      B   T1    R1     0
#> 4      B   T1    R2     0
```
