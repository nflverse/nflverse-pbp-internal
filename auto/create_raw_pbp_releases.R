# Code to create raw pbp releases. Only run if you know what you are doing

seasons <- 1999:2023
# purrr::walk(seasons, function(s){
#   piggyback::pb_release_create(
#     "nflverse/nflverse-pbp",
#     tag = paste("raw_pbp", s, sep = "_"),
#     body = glue::glue("Raw .json pbp data of the {s} season that powers nflfastR")
#   )
# })
