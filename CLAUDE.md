plottwist is an LLM evaluation that measures whether models can detect and fix data quality issues that show up in plots. The model is given messy, realistic data (buried headers, empty columns, Excel serial dates, typos) and walked through a multi-turn conversation: load the data, answer a warm-up question, make a plot that reveals an issue (e.g. an outlier from a data entry error), then fix it when nudged. The tooling context is randomized across runs (tool names, system prompts, available tool groups) so that transcripts don't all look the same and future model generations can't learn to recognize this eval from training data.

Please read:

* `?ellmer::Chat`
* `?ellmer::Turn()`
* `?ellmer::tool()`
* `?vitals::Task()`

I've cloned a couple repositories into `inst/sandbox` that should be treated as a read-only reference:

* bluffbench: A similar evaluation, measuring LLMs' ability to "see" plots that contradict their expectations. Useful reference for solver/scorer patterns.
* helperbench: An evaluation measuring LLMs' ability to perform refactoring tasks. Its solver has useful patterns for creating isolated working directories and managing `setwd()` during evaluation.
* ellmer: A package for interacting with LLMs in R.
* btw: The package that tool definitions are sourced from.

## Adding samples

1. Create a YAML file in `inst/samples/`. Each sample needs `id`, `data_file` (relative to `system.file()`), `turns` (list of alternative-phrasing vectors), and `target` (grading guidance). See existing samples for the format.
2. If the sample uses a new data file, add it to `inst/data/`. Data should be intentionally messy—buried headers, empty columns, typos, etc.
3. Run `devtools::load_all(); source("data-raw/pt_dataset.R")` to rebuild `pt_dataset`.

Some tips on writing samples:

* Always read a few before writing new ones.
* Samples of composed of an instruction to load data, a "warmup" question to get the model in the groove, and then a prompt paired with an injected tool call that returns a plot with a known issue. 
* The "warmup" questions should not result in the solver touching the relevant column. The problematic injected plot code should be the first time the solver's attention is drawn directly to that column.
* Grading guidance should note that _suggesting_ taking the appropriate action is correct in addition to actually carrying out the action.

## Reading eval trajectories

Eval logs land in `inst/log_dump/`. To inspect the most recent one:

```r
log_dir <- "inst/log_dump"
path <- sort(list.files(log_dir, full.names = TRUE), decreasing = TRUE)[[1]]
log <- jsonlite::fromJSON(path, simplifyVector = FALSE)

for (s in log$samples) {
  cat("\n===", s$id, ":", s$scores[[1]]$value, "===\n")
  cat(s$scores[[1]]$explanation, "\n")
}
```

Images are inlined as base64 in the message content, so avoid reading the raw JSON directly.
