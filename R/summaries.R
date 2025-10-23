# ---- helpers for packaged datasets -----------------------------------------

#' List packaged HAI datasets (CSV)
#'
#' @return Character vector like c("hai_table1","hai_table2")
#' @export
list_hai_datasets <- function() {
  ext <- system.file("extdata", package = "assignment4.xinlei.luo")
  files <- list.files(ext, pattern = "^hai_table[0-9]+\\.csv$", full.names = FALSE)
  sub("\\.csv$", "", files)
}

#' Read a packaged HAI CSV dataset
#'
#' Works with two schemas:
#' 1) Wide: infection_type, [age_group], [setting], cases, deaths, daly
#'    (e.g., table1; columns may be named `hais`/`dalys` which will be mapped)
#' 2) Long: measure, sample, infection_type, value  (e.g., table2)
#'    where `measure` starts with "HAIs", "Deaths", "DALYs".
#'
#' @param name Dataset name without extension, e.g. "hai_table1" or "hai_table2".
#' @return A data frame with columns: infection_type, age_group, setting, cases, deaths, daly
#' @export
read_hai_dataset <- function(name) {
  stopifnot(is.character(name), length(name) == 1)
  ext  <- system.file("extdata", package = "assignment4.xinlei.luo")
  path <- file.path(ext, paste0(name, ".csv"))
  if (!file.exists(path)) stop("File not found: ", path, call. = FALSE)

  df <- utils::read.csv(path, check.names = FALSE)
  names(df) <- tolower(gsub("\\s+", "_", names(df)))

  # -------- case 1: already wide (table1 风格) --------
  if (all(c("infection_type") %in% names(df)) &&
      any(c("cases","hais") %in% names(df))) {

    # 列名映射
    if ("hais"  %in% names(df))  names(df)[names(df) == "hais"]  <- "cases"
    if ("dalys" %in% names(df))  names(df)[names(df) == "dalys"] <- "daly"

    # table1 没有 sample，补一个固定值，方便分组
    if (!"sample" %in% names(df)) df$sample <- "German_PPS"

    # 数值化
    for (col in c("cases","deaths","daly")) {
      if (col %in% names(df)) {
        df[[col]] <- gsub("[ ,]", "", as.character(df[[col]]))
        df[[col]] <- suppressWarnings(as.numeric(df[[col]]))
      }
    }

    # 这里只需要保证：infection_type、sample、cases、deaths、daly 五列
    needed <- c("infection_type","sample","cases","deaths","daly")
    miss <- setdiff(needed, names(df))
    if (length(miss)) stop("Missing required columns: ", paste(miss, collapse = ", "))

    return(df[, needed, drop = FALSE])
  }

  # -------- case 2: long (table2 风格) --------
  if (all(c("measure","infection_type","value") %in% names(df))) {

    # 映射成标准指标名
    df$metric <- dplyr::case_when(
      grepl("^hais",   df$measure, ignore.case = TRUE) ~ "cases",
      grepl("^deaths", df$measure, ignore.case = TRUE) ~ "deaths",
      grepl("^dalys",  df$measure, ignore.case = TRUE) ~ "daly",
      TRUE ~ NA_character_
    )
    df <- df[!is.na(df$metric), , drop = FALSE]

    # ⭐ 不要再 slice_head 去掉 sample！我们要保留每个 sample
    # 如果没有 sample 列（极少见），补一个占位
    if (!"sample" %in% names(df)) df$sample <- "All"

    # 宽化，保留 infection_type + sample 作为键
    df_w <- tidyr::pivot_wider(
      df,
      id_cols    = c("infection_type","sample"),
      names_from = "metric",
      values_from= "value"
    )

    # 数值清洗
    for (col in intersect(c("cases","deaths","daly"), names(df_w))) {
      df_w[[col]] <- gsub("[ ,]", "", as.character(df_w[[col]]))
      df_w[[col]] <- suppressWarnings(as.numeric(df_w[[col]]))
    }

    needed <- c("infection_type","sample","cases","deaths","daly")
    miss <- setdiff(needed, names(df_w))
    if (length(miss)) stop("Missing required columns after reshape: ",
                           paste(miss, collapse = ", "))

    return(df_w[, needed, drop = FALSE])
  }}


# ---- analysis helper --------------------------------------------------------

#' Summarise HAI burden
#'
#' @param df A data frame with columns infection_type, sample, cases, deaths, daly.
#' @param by One of "infection_type","sample".
#' @param metric One of "cases","deaths","daly".
#' @return A tibble with columns `group` and `value`.
#' @export
summarise_hai <- function(df,
                          by = c("infection_type","sample"),
                          metric = c("cases","deaths","daly")) {
  by <- match.arg(by)
  metric <- match.arg(metric)

  if (!all(c(by, metric) %in% names(df))) {
    stop("Columns not found in df. Got by = '", by, "', metric = '", metric, "'.")
  }

  df |>
    dplyr::group_by(.data[[by]]) |>
    dplyr::summarise(value = sum(.data[[metric]], na.rm = TRUE), .groups = "drop") |>
    dplyr::arrange(dplyr::desc(.data$value)) |>
    dplyr::rename(group = !!by)
}
