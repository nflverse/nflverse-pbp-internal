# CURRENT SEASON
seasons <- nflreadr::most_recent_season(roster = FALSE)

# LOAD GAMES FOR API GAME IDS
g <-
  purrr::map(seasons, function(s){
    nflapi::nflapi_games(s) |>
      nflapi::nflapi_parse_games(exclude_preseason = TRUE)
  }, .progress = TRUE) |>
  purrr::list_rbind()

# FILTER DOWN TO FINISHED GAMES
finished_g <- g |>
  dplyr::filter(!is.na(home_score), grepl("FINAL", status))

# LOAD RELEASED GAMES
released_g <- data.table::fread("released_games.csv")

# COMPUTE IDs THAT NEED RELEASE
to_be_released <- finished_g |> dplyr::filter(!nflverse_id %in% released_g$game_id)

# Normally there shouldn't be more than 16 games to release. Since the code is heavy
# we check here for a large number and error to rigger manual inspection
if(nrow(to_be_released) > 50){
  cli::cli_abort("Y'all messed something up. It's better not to\
                 automatically update {nrow(to_be_released)} games.\
                 Direct your complaints to Seb!")
}

# ONLY DO SOMETHING IF THERE ARE GAMES TO BE RELEASED
if(nrow(to_be_released) > 0){
  cli::cli_alert_info("Going to release {nrow(to_be_released)} game{?s}.")

  # WE'LL SAVE IN A TEMP DIRECTORY
  temp_dir <- tempdir(check = TRUE)

  # WE NEED BOTH NFLAPI GAME ID AND NFLVERSE GAME ID 
  # to_be_released_nflapi_id <- to_be_released$gamedetail
  to_be_released_nflapi_id <- to_be_released$v1_api_id
  to_be_released_nflverse_id <- to_be_released$nflverse_id

  # LOOP OVER GAMES
  saved_files <- purrr::map2(
    to_be_released_nflapi_id,
    to_be_released_nflverse_id,
    nflverseraw::save_raw_pbp,
    filepath = temp_dir
  )

  # THIS DF LISTS NFLVERSE GAME ID, SEASON, AND RAW PBP PATHS
  file_df <- purrr::list_rbind(saved_files)
  seasons_to_release <- unique(file_df$season)

  # UPLOAD NEW FILES TO RELATED RELEASES
  purrr::walk(seasons_to_release, nflverseraw::release_raw_pbp, file_df = file_df)

  # NOW UPDATE THE RELEASED GAMES CSV
  updated_released_g <- released_g |>
    dplyr::bind_rows(c(game_id = to_be_released_nflverse_id)) |>
    dplyr::arrange(dplyr::desc(game_id))

  # COMMIT AND PUSH THE CSV IN THE GH ACTION
  data.table::fwrite(updated_released_g, "released_games.csv")

  # CLEAR TEMP DIRECTORY
  unlink(temp_dir, recursive = TRUE)
}
