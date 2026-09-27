# Classify candidates from their observed scores

Classify candidates from their observed scores

## Usage

``` r
df_classify(object, cut)
```

## Arguments

- object:

  A \`df_fit\` or \`df_sim\`.

- cut:

  A \`df_cut\`.

## Value

Data frame: \`person\`, \`panel\`, \`total\`, \`raw_cut\` (the raw total
this candidate's panel had to reach), \`pass\`.

## Examples

``` r
sim <- df_simulate(n_persons = 100, n_items = 3, n_raters = 6, seed = 1)
head(df_classify(sim, df_cut(0, "measure")))
#>   person   panel total raw_cut  pass
#> 1  P0001 R01|R02    11      15 FALSE
#> 2  P0002 R02|R04    17      14  TRUE
#> 3  P0003 R02|R04     9      14 FALSE
#> 4  P0004 R01|R05    21      13  TRUE
#> 5  P0005 R05|R06    13      12  TRUE
#> 6  P0006 R04|R05    10      12 FALSE
```
