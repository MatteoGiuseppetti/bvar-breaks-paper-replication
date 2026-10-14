# Input snapshot sanity checks; no BVAR model is estimated here.
# Run from the repository root: Rscript scripts/check_inputs.R
options(stringsAsFactors = FALSE)
expected_rows <- c(PCECTPI = 318L, UNRATE = 943L, FEDFUNDS = 865L)
for (series in names(expected_rows)) {
  path <- file.path("data", "raw", paste0(series, ".csv"))
  if (!file.exists(path)) stop("Missing input file: ", path)
  dat <- read.csv(path, na.strings = c("", ".", "NA"))
  if (!identical(names(dat), c("observation_date", series))) {
    stop("Unexpected column names in: ", path)
  }
  if (nrow(dat) != expected_rows[[series]]) {
    stop("Unexpected number of archived rows in: ", path,
         " (", nrow(dat), "; expected ", expected_rows[[series]], ")")
  }
  dates <- as.Date(dat$observation_date)
  if (anyNA(dates) || is.unsorted(dates, strictly = TRUE)) {
    stop("Invalid or unsorted dates in: ", path)
  }
  cat(sprintf("PASS %-8s %4d rows, %s to %s\n",
              series, nrow(dat), min(dates), max(dates)))
}
unrate <- read.csv(file.path("data", "raw", "UNRATE.csv"),
                   na.strings = c("", ".", "NA"))
get_unrate <- function(d) {
  z <- unrate$UNRATE[unrate$observation_date == d]
  if (length(z) != 1L) stop("Missing or duplicated date: ", d)
  z
}
if (!is.na(get_unrate("2025-10-01")) ||
    is.na(get_unrate("2025-11-01")) ||
    is.na(get_unrate("2025-12-01"))) {
  stop("Archived UNRATE 2025Q4 completeness pattern differs from thesis.")
}
cat("PASS UNRATE October 2025 missing; November/December available.\n")
cat("Input checks passed. This is NOT a numerical reproduction of the paper.\n")
