#' Launch the HAI Shiny app
#' @export
run_app <- function() {
  app_dir <- system.file("app", "hai", package = "assignment4.xinlei.luo")
  shiny::runApp(app_dir, display.mode = "normal")
}
