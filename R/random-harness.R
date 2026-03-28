# Assembles a random set of btw tools for use as a solver harness. The run R
# code tool is always included; other tool groups are sampled randomly. Each
# tool is renamed to one of 4 synonymous aliases.
random_harness <- function() {
  tools <- btw::btw_tools("run")

  optional <- c("docs", "files", "env", "sessioninfo", "cran")
  chosen <- sample(optional, sample(length(optional), 1))
  for (group in chosen) {
    tools <- c(tools, btw::btw_tools(group))
  }

  for (i in seq_along(tools)) {
    aliases <- tool_name_aliases[[tools[[i]]@name]]
    if (!is.null(aliases)) {
      new_name <- sample(aliases, 1)
      tools[[i]]@name <- new_name
      names(tools)[i] <- new_name
    }
  }

  tools
}

tool_name_aliases <- list(
  btw_tool_run_r =
    c("run_r", "run_r_code", "execute_r", "execute_r_code"),
  btw_tool_cran_search =
    c("cran_search", "search_cran", "find_cran_package", "lookup_cran"),
  btw_tool_cran_package =
    c("cran_package", "describe_cran_package", "get_cran_package", "cran_package_info"),
  btw_tool_docs_package_news =
    c("package_news", "get_package_news", "read_package_news", "package_changelog"),
  btw_tool_docs_package_help_topics =
    c("package_help_topics", "list_help_topics", "get_help_topics", "package_topics"),
  btw_tool_docs_help_page =
    c("help_page", "get_help_page", "read_help", "lookup_help"),
  btw_tool_docs_available_vignettes =
    c("available_vignettes", "list_vignettes", "get_vignettes", "package_vignettes"),
  btw_tool_docs_vignette =
    c("read_vignette", "get_vignette", "vignette_content", "fetch_vignette"),
  btw_tool_env_describe_data_frame =
    c("describe_data_frame", "inspect_data_frame", "data_frame_info", "summarize_data_frame"),
  btw_tool_env_describe_environment =
    c("describe_environment", "list_environment", "inspect_environment", "environment_info"),
  btw_tool_files_list =
    c("list_files", "files_list", "ls_files", "directory_listing"),
  btw_tool_files_read =
    c("read_file", "files_read", "get_file_contents", "fetch_file"),
  btw_tool_files_search =
    c("search_files", "files_search", "grep_files", "find_in_files"),
  btw_tool_files_write =
    c("write_file", "files_write", "save_file", "create_file"),
  btw_tool_sessioninfo_is_package_installed =
    c("is_package_installed", "check_package_installed", "package_installed", "verify_package"),
  btw_tool_sessioninfo_platform =
    c("session_platform", "get_platform_info", "platform_info", "r_platform"),
  btw_tool_sessioninfo_package =
    c("session_package", "package_session_info", "get_package_info", "package_info")
)
