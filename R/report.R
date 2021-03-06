#' Display covr results using a standalone report
#'
#' @param x a coverage dataset, defaults to running `package_coverage()`.
#' @param file The report filename.
#' @param browse whether to open a browser to view the report.
#' @examples
#' \dontrun{
#' x <- package_coverage()
#' report(x)
#' }
#' @export
# This function was originally a shiny application, but has been converted into
# a normal static document. Hence the shiny calls / dependency despite not
# actually using shiny.
report <- function(x = package_coverage(),
  file = file.path(tempdir(), paste0(get_package_name(x), "-report.html")),
  browse = interactive()) {

  loadNamespace("shiny")

  data <- to_shiny_data(x)

  ui <- shiny::fluidPage(
    shiny::includeCSS(system.file("www/shiny.css", package = "covr")),
    shiny::column(8, offset = 2,
      shiny::tabsetPanel(
        shiny::tabPanel("Files",
          DT::datatable(data$file_stats,
            escape = FALSE,
            options = list(searching = FALSE, dom = "t", paging = FALSE),
            rownames = FALSE,
            callback = DT::JS(
"table.on('click.dt', 'a', function() {
  files = $('div#files div');
  files.not('div.hidden').addClass('hidden');
  id = $(this).text();
  files.filter('div[id=\\'' + id + '\\']').removeClass('hidden');
  $('ul.nav a[data-value=Source]').text(id).tab('show');
});"))),
            shiny::tabPanel("Source", addHighlight(renderSourceTable(data$full)))
            )
          ),
    title = paste(attr(x, "package")$package, "Coverage"))

  htmltools::save_html(ui, file)
  viewer <- getOption("viewer", utils::browseURL)
  if (browse) {
      viewer(file)
  }
  invisible(file)
}

to_shiny_data <- function(x) {
  coverages <- per_line(x)

  res <- list()
  res$full <- lapply(coverages,
    function(coverage) {
      lines <- coverage$file$file_lines
      values <- coverage$coverage
      values[is.na(values)] <- ""
      data.frame(
        line = seq_along(lines),
        source = lines,
        coverage = values,
        stringsAsFactors = FALSE)
    })
  nms <- names(coverages)

  # set a temp name if it doesn't exist
  nms[nms == ""] <- "<text>"

  names(res$full) <- nms

  res$file_stats <- compute_file_stats(res$full)

  res$file_stats$File <- add_link(names(res$full))

  res$file_stats <- sort_file_stats(res$file_stats)

  res$file_stats$Coverage <- add_color_box(res$file_stats$Coverage)

  res
}

compute_file_stats <- function(files) {
  do.call("rbind",
    lapply(files,
      function(file) {
        data.frame(
          Coverage = sprintf("%.2f", sum(file$coverage > 0) / sum(file$coverage != "") * 100),
          Lines = NROW(file),
          Relevant = sum(file$coverage != ""),
          Covered = sum(file$coverage > 0),
          Missed = sum(file$coverage == 0),
          `Hits / Line` = sprintf("%.0f", sum(as.numeric(file$coverage), na.rm = TRUE) / sum(file$coverage != "")),
          stringsAsFactors = FALSE,
          check.names = FALSE)
      }
    )
  )
}

sort_file_stats <- function(stats) {
  stats[order(as.numeric(stats$Coverage), -stats$Relevant),
        c("Coverage", "File", "Lines", "Relevant", "Covered", "Missed", "Hits / Line")]
}

add_link <- function(files) {
  vcapply(files, function(file) { as.character(shiny::a(href = "#", file)) })
}

add_color_box <- function(nums) {

  vcapply(nums, function(num) {
    nnum <- as.numeric(num)
    if (nnum > 90) {
      as.character(shiny::div(class = "coverage-box coverage-high", num))
    } else if (nnum > 75) {
      as.character(shiny::div(class = "coverage-box coverage-medium", num))
    } else {
      as.character(shiny::div(class = "coverage-box coverage-low", num))
    }
  })
}

renderSourceTable <- function(data) {

  shiny::tags$div(id = "files",
    Map(function(lines, file) {
      shiny::tags$div(id = file, class="hidden",
        shiny::tags$table(class = "table-condensed",
          shiny::tags$tbody(
            lapply(seq_len(NROW(lines)),
              function(row_num) {
                coverage <- lines[row_num, "coverage"]

                cov_type <- NULL
                if (coverage == 0) {
                  cov_value <- "!"
                  cov_type <- "missed"
                } else if (coverage > 0) {
                  cov_value <- shiny::HTML(paste0(lines[row_num, "coverage"], "<em>x</em>", collapse = ""))
                  cov_type <- "covered"
                } else {
                  cov_type <- "never"
                  cov_value <- ""
                }
                shiny::tags$tr(class = cov_type,
                  shiny::tags$td(class = "num", lines[row_num, "line"]),
                  shiny::tags$td(class = "col-sm-12", shiny::pre(class = "language-r", lines[row_num, "source"])),
                  shiny::tags$td(class = "coverage", cov_value)
                  )
              })
            )
          ))
    }, lines = data, file = names(data)),
  shiny::tags$script(
    "$('div#files pre').each(function(i, block) {
    hljs.highlightBlock(block);
});"))
}

addHighlight <- function(x = list()) {
  highlight <- htmltools::htmlDependency("highlight.js", "6.2",
                                         system.file(package = "shiny",
                                                     "www/shared/highlight"),
                                         script = "highlight.pack.js",
                                         stylesheet = "rstudio.css")

  htmltools::attachDependencies(x, c(htmltools::htmlDependencies(x), list(highlight)))
}

#' Deprecated Functions

#' These functions are Deprecated in this release of covr, they will be
#' marked as Defunct and removed in a future version.
#'
#' @export
#' @keywords internal
#' @rdname covr-deprecated
shine <- function(...) {
  .Deprecated("report()", package = "covr")
  report(...)
}
addin_report <- function() {
  loadNamespace("rstudioapi")

  project <- rstudioapi::getActiveProject()

  covr::report(covr::package_coverage(project %||% getwd()))
}
