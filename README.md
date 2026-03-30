
<!-- README.md is generated from README.Rmd. Please edit that file -->

# plottwist

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

The goal of plottwist is to measure LLMs’ ability to detect and fix
plotting issues.

First, a data analysis agent with a semi-random prompt and harness is
generated. The agent will always have the same high-level advice and a
tool to run R code, with a set of perturbations to prevent memorization.

That agent will be asked a couple of questions to load in and plot some
data. At some point, a synthetic turn will be interjected with a known
plotting issue, like overlapping text or a bad geom.

The eval measures how well the agent can detect and fix the issue. If
the agent detects the issue and fixes it (or suggests doing so) without
a nudge from the user, it’s given a passing grade. If it can identify
and fix the issue (or suggest doing so) after a vague nudge (e.g. “fix
the axis labels”), it receives partial credit.

## Installation

You can install the development version of plottwist like so:

``` r
pak::pak("simonpcouch/plottwist")
```
