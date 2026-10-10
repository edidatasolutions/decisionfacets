# Standardize rater-mediated score data

Standardize rater-mediated score data

## Usage

``` r
df_data(
  x,
  person = "person",
  item = "item",
  rater = "rater",
  score = "score",
  scale = c("auto", "ordinal", "continuous")
)
```

## Arguments

- x:

  A data frame in long format, one row per person x item x rater score.

- person, item, rater, score:

  Column names in \`x\`.

- scale:

  \`"ordinal"\` for rating categories (integers, analyzed with the
  many-facet Rasch rating scale model), \`"continuous"\` for scores such
  as 0-100 (analyzed with the linear many-facet model), or \`"auto"\`:
  continuous when scores are not all integers or take more than 20
  distinct values.

## Value

A \`df_data\` data frame with character ids and scores. Ordinal scores
are 0-based integers and attribute \`K\` is the highest category;
continuous scores are kept as they are. Attribute \`scale\` records the
choice.

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

# Scores on a 0-100 scale
pct <- data.frame(cand = c("A", "B", "C"), case = "C1", examiner = "E1",
                  score = c(72.5, 64, 88))
df_data(pct, person = "cand", item = "case", rater = "examiner",
        scale = "continuous")
#>   person item rater score
#> 1      A   C1    E1  72.5
#> 2      B   C1    E1  64.0
#> 3      C   C1    E1  88.0
```
