# THIS FILE IS USED BY SEB TO BULK UPLOAD RAW PBP OF COMPLETE SEASONS
# DO NOT MESS WITH THIS UNLESS YOU KNOW WHAT YOU ARE DOING

# RENEW SEASON ------------------------------------------------------------
season <- 2025

# this is where new raw pbp data is saved in. A season folder will be created
raw_dir <- "~/Documents/Analytics/_data_cache/new_raw"

# this is the season folder below the above
szn_path <- file.path(raw_dir, season)

# the release tag name
tag <- paste0("raw_pbp_", season)

# create folder so nflverseraw::save_raw_pbp doesn't have to, because we want
# to run it in parallel
if (!dir.exists(szn_path)) {
  dir.create(szn_path, recursive = TRUE)
}

# query game IDs
g <- nflapi::nflapi_games(season) |>
  nflapi::nflapi_parse_games(exclude_preseason = TRUE)

# do it in parallel
future::plan(future.mirai::mirai_multisession)
saved_files <- progressr::with_progress({
  p <- progressr::progressor(along = g$nflverse_id)
  furrr::future_map2(
    g$v1_api_id,
    g$nflverse_id,
    nflverseraw::save_raw_pbp,
    filepath = raw_dir,
    verbose = FALSE,
    p = p
  )
})

# this is mainly to check what files live in the folder
files_in_dir <- list.files(szn_path, full.names = TRUE)
files_in_dir

# the number of files should equal number of games
if (length(files_in_dir) != nrow(g)) {
  stop("Something went wrong")
}

# upload requires usage of 3 api calls per file.
# A 267 game season means: 267 files x 3 calls / file = 801 calls.
# Typical usage limit is 5000 calls per hour
nflversedata::nflverse_upload(
  files = files_in_dir,
  tag = tag,
  repo = "nflverse/nflverse-pbp",
  overwrite = TRUE
)


# Check Rate Limits -------------------------------------------------------
rate_limits <- nflversedata::gh_cli_rate_limits()
wait_time <- difftime(
  as.POSIXct(
    rate_limits$rate$reset,
    origin = "1970-01-01",
    tz = "UTC"
  ),
  Sys.time(),
  units = "secs"
)
hms::as_hms(wait_time) |> hms::round_hms(1)

# Save json Files ---------------------------------------------------------
# needed this for 2001 and 2002 seasons because API returns trash
# and nflfastR-raw only has rds files
# rds_files <- list.files(szn_path, full.names = TRUE, pattern = ".rds")
# files_in_dir <- list.files(szn_path, full.names = TRUE)
# del <- file.remove(files_in_dir[!files_in_dir %in% rds_files])
# furrr::future_walk(
#   rds_files,
#   function(file) {
#     data <- readRDS(file)
#     json_path <- paste0(tools::file_path_sans_ext(file), ".json")
#     jsonlite::write_json(data, json_path)
#     system(paste("gzip", json_path))
#     invisible(TRUE)
#   }
# )

# List All Assets ---------------------------------------------------------

# query pbp tags and remove bad data seasons
all_tags <- nflversedata::gh_cli_release_tags("nflverse/nflverse-pbp")
pbp_tags <- all_tags[grepl("raw_pbp", all_tags)]
pbp_tags <- pbp_tags[!substr(pbp_tags, 9, 12) %in% c(1999:2002)]

# query all assets of pbp tags
assets <- purrr::map(
  pbp_tags,
  nflversedata::gh_cli_release_assets,
  repo = "nflverse/nflverse-pbp",
  .progress = TRUE
) |>
  purrr::list_rbind()

# count last update by season and day
# useful when renewing raw pbp
df <- assets |>
  dplyr::filter(stringr::str_detect(name, ".rds")) |>
  dplyr::mutate(
    season = substr(name, 1, 4),
    update_day = as.Date(substr(last_update, 1, 10))
  ) |>
  dplyr::count(
    season,
    update_day
  )
df


# Remove Assets -----------------------------------------------------------
delete_from_repo <- "nflverse/nflverse-pbp"
all_tags <- nflversedata::gh_cli_release_tags(delete_from_repo)
pbp_tags <- all_tags[grepl("raw_pbp", all_tags)]
delete_from_tag <- "raw_pbp_2002"

assets <- nflversedata::gh_cli_release_assets(
  tag = delete_from_tag,
  repo = delete_from_repo
)

to_delete <- assets |>
  dplyr::filter_out(stringr::str_detect(name, ".rds")) |>
  dplyr::pull(name)

# deleting requires 2 api calls per asset to delete
future::plan(future.mirai::mirai_multisession)
progressr::with_progress({
  p <- progressr::progressor(along = to_delete)
  furrr::future_walk(
    to_delete,
    \(x, tag, repo, p) {
      nflversedata::gh_cli_release_delete_asset(x, tag = tag, repo = repo)
      p()
    },
    tag = delete_from_tag,
    repo = delete_from_repo,
    p = p
  )
})
