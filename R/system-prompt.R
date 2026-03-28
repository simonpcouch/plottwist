random_system_prompt <- function() {
  prompts_dir <- system.file("prompts/system", package = "plottwist")
  sections <- list.dirs(prompts_dir, full.names = TRUE, recursive = FALSE)

  sections <- c(sections[1], sample(sections[-1]))

  paragraphs <- vapply(
    sections,
    function(section) {
      files <- list.files(section, full.names = TRUE, pattern = "\\.md$")
      chosen <- sample(files, 1)
      paste(readLines(chosen, warn = FALSE), collapse = "\n")
    },
    character(1)
  )

  paste(paragraphs, collapse = "\n\n")
}
