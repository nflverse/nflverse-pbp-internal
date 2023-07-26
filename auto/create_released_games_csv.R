# CODE TO CREATE THE RELEASED GAMES CSV
# ONLY RUN IF YOU KNOW WHAT YOU ARE DOING
# written by Seb, 2023-07-26

# Set Data Repo -----------------------------------------------------------
datarepo <- "nflverse/nflverse-data"


# Query all Releases ------------------------------------------------------
releases <- piggyback::pb_releases(datarepo)

# filter down to raw_pbp release tags
raw_pbp_releases <- releases |>
  dplyr::filter(grepl("raw_pbp_", tag_name))


# List all files in raw pbp releases --------------------------------------
datalist <- piggyback::pb_list(datarepo, raw_pbp_releases$tag_name)

# extract game ids from released files
# this is going to be the released games csv
games <- datalist |>
  dplyr::filter(!grepl("timestamp", file_name), grepl(".rds", file_name)) |>
  dplyr::mutate(
    game_id = tools::file_path_sans_ext(file_name, compression = TRUE)
  ) |>
  dplyr::distinct(game_id, .keep_all = FALSE) |>
  dplyr::arrange(dplyr::desc(game_id))


# Save Released Games csv -------------------------------------------------
data.table::fwrite(games, "released_games.csv")


# Checks ------------------------------------------------------------------
# This section doesn't need to run to create the file. Just some checks what's
# missing
released_games <- nflreadr::load_schedules() |>
  dplyr::filter(game_id %in% games$game_id)

# The only game IDs that should be missing are
# 2000_03_SD_KC and 2000_06_BUF_MIA. We never managed to get those.
# nflfastR skips these IDs
missing_games <- nflreadr::load_schedules() |>
  dplyr::filter(!game_id %in% games$game_id, !is.na(result))

missing_games |> dplyr::count(season)

released_games |> dplyr::count(season)
