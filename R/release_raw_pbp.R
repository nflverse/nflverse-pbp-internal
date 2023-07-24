#' Title
#'
#' @param season
#' @param file_df
#' @param .token
#'
#' @return
#' @export
#'
#' @examples
release_raw_pbp <- function(season, file_df, .token = gh::gh_token()){
  # FILTER file_df DOWN TO FILES OF season
  file_names <- file_df[season == season, c("rds_path", "json_path")] |>
    unlist(use.names = FALSE)

  # CREATE RELEASE TAG BASED OFF SEASON.
  # WE NEED THIS BECAUSE WE SPLIT RELEASES BY SEASON
  release_tag <- paste("raw_pbp", season, sep = "_")

  # UPLOAD DATA TO RELEASE
  nflversedata::nflverse_upload(
    file_names,
    tag = release_tag,
    .token = .token
  )
}
