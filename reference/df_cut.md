# Define a pass/fail cut under an explicit decision rule

The decision rule determines how rater severity can reach the decision:

- \`raw_total\`:

  Pass if the summed observed ratings reach \`value\`. Severity passes
  straight through to the decision.

- \`raw_mean\`:

  Pass if the mean observed rating reaches \`value\` (for example 70 on
  a 0-100 scale). Equivalent to \`raw_total\` with a cut of \`value\`
  times the number of ratings, which is convenient when candidates have
  different numbers of ratings.

- \`measure\`:

  Pass if the severity-adjusted measure reaches \`value\` (logits for
  ordinal scores; score points for continuous scores). Severity is
  modeled out; only its effect on measurement precision remains.

- \`fair_average\`:

  Pass if the FACETS-style fair average (expected mean rating per cell
  for an average rater) reaches \`value\`. It is monotone in the
  measure, so it behaves like \`measure\` with a transformed cut. For
  continuous scores it equals the measure.

## Usage

``` r
df_cut(
  value,
  decision_rule = c("raw_total", "raw_mean", "fair_average", "measure")
)
```

## Arguments

- value:

  The cut score on the scale implied by \`decision_rule\`.

- decision_rule:

  One of \`"raw_total"\`, \`"raw_mean"\`, \`"fair_average"\`,
  \`"measure"\`.

## Value

A \`df_cut\` object (a list with \`value\` and \`decision_rule\`).

## Examples

``` r
df_cut(16, "raw_total")        # pass if the summed ratings reach 16
#> $value
#> [1] 16
#> 
#> $decision_rule
#> [1] "raw_total"
#> 
#> attr(,"class")
#> [1] "df_cut"
df_cut(70, "raw_mean")         # pass if the mean rating reaches 70
#> $value
#> [1] 70
#> 
#> $decision_rule
#> [1] "raw_mean"
#> 
#> attr(,"class")
#> [1] "df_cut"
df_cut(2, "fair_average")      # pass if the fair average reaches 2
#> $value
#> [1] 2
#> 
#> $decision_rule
#> [1] "fair_average"
#> 
#> attr(,"class")
#> [1] "df_cut"
df_cut(0.25, "measure")        # pass if the measure reaches 0.25
#> $value
#> [1] 0.25
#> 
#> $decision_rule
#> [1] "measure"
#> 
#> attr(,"class")
#> [1] "df_cut"
```
