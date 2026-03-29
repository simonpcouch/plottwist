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

## Adding samples

1. Create a YAML file in `inst/samples/`. Each sample needs `id`, `data_file` (relative to `system.file()`), `turns` (list of alternative-phrasing vectors), and `target` (grading guidance). See existing samples for the format.
2. If the sample uses a new data file, add it to `inst/data/`. Data should be intentionally messy—buried headers, empty columns, typos, etc.
3. Run `devtools::load_all(); source("data-raw/pt_dataset.R")` to rebuild `pt_dataset`.
