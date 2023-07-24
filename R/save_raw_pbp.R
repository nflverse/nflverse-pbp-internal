#' Query PBP FROM NFL API AND SAVE LOCALLY
#'
#' @param game_nflapi_id The game id of the nfl api
#' @param game_nflverse_id The game id of the nflverse
#' @param filepath A path to save raw pbp files to
#' @return The filepath where the raw pbp was saved to
#' @export
save_raw_pbp <- function(game_nflapi_id, game_nflverse_id, filepath){

  if (any(length(game_nflapi_id) > 1, length(game_nflverse_id) > 1)){
    cli::cli_abort("Can't handle more than 1 game!")
  }

  # QUERY RAW PBP FROM API (WORKS LIVE)
  raw_pbp <- nflapi::nflapi_pbp(game_nflapi_id)

  # LET'S SLEEP FOR 1 SECOND TO AVOID TO FAST QUERIES
  Sys.sleep(1)

  # NEED SEASON TO SPLIT RELEASES
  season <- substr(game_nflverse_id, 1, 4)

  # CREATE SAVE PATH
  save_path <- file.path(filepath, season)

  if(!dir.exists(save_path)) dir.create(save_path, recursive = TRUE)

  # SAVE RAW PBP AS RDS
  rds_path <- file.path(save_path, paste0(game_nflverse_id, ".rds"))
  saveRDS(raw_pbp, rds_path)

  # SAVE RAW PBP AS JSON AND GZIP IT
  json_path <- file.path(save_path, paste0(game_nflverse_id, ".json"))
  jsonlite::write_json(raw_pbp, json_path)
  system(paste("gzip", json_path))
  data.frame(
    game_id = game_nflverse_id,
    season = season,
    rds_path = rds_path,
    json_path = json_path
  )
}
