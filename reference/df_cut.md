# Define a pass/fail cut under an explicit decision rule

The decision rule determines how rater severity can reach the decision:

- \`raw_total\`:

  Pass if the summed observed ratings reach \`value\`. Severity passes
  straight through to the decision.

- \`measure\`:

  Pass if the severity-adjusted Rasch measure (logits) reaches
  \`value\`. Severity is modeled out; only its effect on measurement
  precision remains.

- \`fair_average\`:

  Pass if the FACETS-style fair average (expected mean rating per cell
  for an average rater) reaches \`value\`. It is monotone in the
  measure, so it behaves like \`measure\` with a transformed cut.

## Usage

``` r
df_cut(value, decision_rule = c("raw_total", "fair_average", "measure"))
```

## Arguments

- value:

  The cut score on the scale implied by \`decision_rule\`.

- decision_rule:

  One of \`"raw_total"\`, \`"fair_average"\`, \`"measure"\`.

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
df_cut(2, "fair_average")      # pass if the fair average reaches 2
#> $value
#> [1] 2
#> 
#> $decision_rule
#> [1] "fair_average"
#> 
#> attr(,"class")
#> [1] "df_cut"
df_cut(0.25, "measure")        # pass if the Rasch measure reaches 0.25 logits
#> $value
#> [1] 0.25
#> 
#> $decision_rule
#> [1] "measure"
#> 
#> attr(,"class")
#> [1] "df_cut"
```
