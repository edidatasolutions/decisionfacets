# Synthetic oral-examination data shipped as `oral_exam`. Entirely simulated:
# no real candidates, examiners or examination are represented.
# 300 candidates, 12 cases, 48 examiners (8 qualified per case); each case is
# scored by one examiner on a 0-100 scale, with no examiner scoring the same
# candidate twice.
library(decisionfacets)
sim <- df_simulate(n_persons = 300, n_items = 12, n_raters = 48, design = "per_item",
                   raters_per_item = 8, scale = "continuous",
                   continuous = list(center = 72, theta_sd = 7, item_sd = 4,
                                     severity_sd = 4.5, sigma = 8),
                   seed = 20261009)
d <- sim$data
oral_exam <- data.frame(
  candidate = sub("^P", "C", d$person),
  case = sub("^I", "Case", d$item),
  examiner = sub("^R", "E", d$rater),
  score = d$score,
  stringsAsFactors = FALSE
)
oral_exam <- oral_exam[order(oral_exam$candidate, oral_exam$case), ]
rownames(oral_exam) <- NULL
save(oral_exam, file = "data/oral_exam.rda", compress = "xz")
