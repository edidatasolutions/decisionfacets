# Simulate a rater-mediated administration with known truth

Each candidate is scored on every item by a panel of
\`raters_per_person\` raters drawn at random from the pool.

## Usage

``` r
df_simulate(
  n_persons = 500,
  n_items = 4,
  n_raters = 12,
  raters_per_person = 2,
  n_cat = 5,
  theta_mean = 0,
  theta_sd = 1,
  item_sd = 0.5,
  severity_sd = 0.5,
  tau = NULL,
  seed = NULL
)
```

## Arguments

- n_persons, n_items, n_raters:

  Facet sizes.

- raters_per_person:

  Panel size per candidate.

- n_cat:

  Number of score categories (scores 0..n_cat-1).

- theta_mean, theta_sd:

  Candidate ability distribution.

- item_sd, severity_sd:

  SDs of item difficulty and rater severity (both centered).

- tau:

  Category thresholds; defaults to equally spaced on \[-1.5, 1.5\].

- seed:

  Optional RNG seed.

## Value

A \`df_sim\` object: \`\$data\` (a \`df_data\`) and \`\$par\`, the true
parameters (\`theta\`, \`delta\`, \`lambda\`, \`tau\`, all named).

## Examples

``` r
sim <- df_simulate(n_persons = 100, n_items = 3, n_raters = 6, seed = 1)
head(sim$data)
#>   person item rater score
#> 1  P0001  I01   R01     1
#> 2  P0001  I02   R01     1
#> 3  P0001  I03   R01     3
#> 4  P0001  I01   R02     1
#> 5  P0001  I02   R02     2
#> 6  P0001  I03   R02     3
sim$par$lambda   # true rater severities
#>         R01         R02         R03         R04         R05         R06 
#> -0.19446882 -0.60077553  0.61016043  0.08487053  0.18160391 -0.08139053 
```
