samples_dir <- system.file("samples", package = "plottwist")

sample_paths <- list.files(
  samples_dir,
  pattern = "\\.ya?ml$",
  full.names = TRUE
)

pt_dataset <- purrr::map(sample_paths, yaml::read_yaml) |>
  purrr::map_dfr(\(sample) {
    tibble::tibble(
      id = sample$id,
      input = list(tibble::tibble(
        turns = list(sample$turns),
        data_file = sample$data_file
      )),
      target = sample$target
    )
  }) |>
  dplyr::arrange(id)

usethis::use_data(pt_dataset, overwrite = TRUE)
