# Rater severity estimates

Rater severity estimates

## Usage

``` r
df_rater_effects(object)
```

## Arguments

- object:

  A \`df_fit\` or \`df_sim\`.

## Value

A data frame of rater ids and severities (logits, centered at 0;
positive = harsher).

## Examples

``` r
sim <- df_simulate(n_persons = 100, n_items = 3, n_raters = 6, seed = 1)
df_rater_effects(sim)
#>   rater    severity
#> 1   R01 -0.19446882
#> 2   R02 -0.60077553
#> 3   R03  0.61016043
#> 4   R04  0.08487053
#> 5   R05  0.18160391
#> 6   R06 -0.08139053
```
