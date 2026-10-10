# Simulate a rater-mediated administration with known truth

Two scoring designs are available. In the \`"crossed"\` design each
candidate is scored on every item by a panel of \`raters_per_person\`
raters drawn at random from the pool. In the \`"per_item"\` design each
item (for example an oral-examination case) has its own set of
\`raters_per_item\` qualified examiners, and each of a candidate's items
is scored by one examiner drawn from that item's set, with no examiner
scoring the same candidate twice when it can be avoided.

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
  design = c("crossed", "per_item"),
  raters_per_item = NULL,
  scale = c("ordinal", "continuous"),
  continuous = list(),
  seed = NULL
)
```

## Arguments

- n_persons, n_items, n_raters:

  Facet sizes.

- raters_per_person:

  Panel size per candidate (crossed design).

- n_cat:

  Number of score categories (ordinal scores 0..n_cat-1).

- theta_mean, theta_sd:

  Candidate ability distribution (ordinal: logits).

- item_sd, severity_sd:

  SDs of item difficulty and rater severity (both centered). For
  continuous scores they are on the score scale.

- tau:

  Category thresholds; defaults to equally spaced on \[-1.5, 1.5\].

- design:

  \`"crossed"\` or \`"per_item"\`.

- raters_per_item:

  Qualified examiners per item in the per-item design (default: all
  raters).

- scale:

  \`"ordinal"\` or \`"continuous"\`.

- continuous:

  Settings for continuous scores: \`center\` (mean score), \`theta_sd\`,
  \`item_sd\`, \`severity_sd\` and \`sigma\` (residual SD), all on the
  score scale, \`bounds\` (scores are truncated to this range) and
  \`round\` (round to whole points). They replace \`theta_mean\`,
  \`theta_sd\`, \`item_sd\` and \`severity_sd\` when \`scale =
  "continuous"\`.

- seed:

  Optional RNG seed.

## Value

A \`df_sim\` object: \`\$data\` (a \`df_data\`) and \`\$par\`, the true
parameters (\`theta\`, \`delta\`, \`lambda\`, and \`tau\` or \`sigma\`
and \`model = "linear"\`, all named).

## Details

Scores are ordinal (many-facet Rasch rating scale model) or continuous
(linear many-facet model on a score scale such as 0-100).

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

# Oral examination: 8 cases, one examiner per case, scores 0-100
oral <- df_simulate(n_persons = 100, n_items = 8, n_raters = 24,
                    design = "per_item", raters_per_item = 6,
                    scale = "continuous", seed = 1)
head(oral$data)
#>   person item rater score
#> 1  P0001  I01   R24    63
#> 2  P0001  I02   R10    79
#> 3  P0001  I03   R08    60
#> 4  P0001  I04   R17    48
#> 5  P0001  I05   R04    69
#> 6  P0001  I06   R03    66
```
