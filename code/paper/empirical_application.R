# PAPER ONLY — empirical U.S. macro application: baseline K=4 and robustness K=8.
# Entire empirical application copied from the thesis R file (line endings normalized).

# Original BVAR_thesis_full_code.R lines 3352-4222 (verbatim)
# Chapter 6: Empirical application
figure_dir <- "figures_chapter6"
if (!dir.exists(figure_dir)) dir.create(figure_dir, recursive = TRUE)
# 6.1 Settings and data construction
file_pce_real <- "PCECTPI.csv"
file_unrate_real <- "UNRATE.csv"
file_fedfunds_real <- "FEDFUNDS.csv"

sample_end_real <- "2026Q2"
T0_len_real <- 40L
pmax_main_real <- 4L
pmax_robust_real <- 8L
min_segment_length_real <- 28L
max_breaks_real <- 4L
excluded_quarter_real <- "2020Q2"
quarter_label_real <- function(date) {
  date <- as.Date(date)
  year <- as.integer(format(date, "%Y"))
  month <- as.integer(format(date, "%m"))
  quarter <- ((month - 1L) %/% 3L) + 1L
  paste0(year, "Q", quarter)
}

quarter_index_real <- function(q) {
  year <- as.integer(substr(q, 1L, 4L))
  quarter <- as.integer(sub(".*Q", "", q))
  4L * year + quarter
}

read_fred_csv_real <- function(path, value_name) {
  x <- read.csv(path, stringsAsFactors = FALSE, na.strings = c("", ".", "NA"))
  x$observation_date <- as.Date(x$observation_date)
  x[[value_name]] <- as.numeric(x[[value_name]])
  x <- x[order(x$observation_date), c("observation_date", value_name), drop = FALSE]
  if (anyDuplicated(x$observation_date)) stop(sprintf("Duplicated dates found in %s.", path))
  x
}

quarterly_mean_real <- function(x, value_name, min_valid = 2L) {
  x$quarter <- quarter_label_real(x$observation_date)
  out <- aggregate(
    x[[value_name]], by = list(quarter = x$quarter),
    FUN = function(z) if (sum(!is.na(z)) < min_valid) NA_real_ else mean(z, na.rm = TRUE)
  )
  names(out)[2] <- value_name
  out <- out[order(quarter_index_real(out$quarter)), , drop = FALSE]
  rownames(out) <- NULL
  out
}
pce_real <- read_fred_csv_real(file_pce_real, "PCECTPI")
unrate_real <- read_fred_csv_real(file_unrate_real, "UNRATE")
fedfunds_real <- read_fred_csv_real(file_fedfunds_real, "FEDFUNDS")
pce_real$quarter <- quarter_label_real(pce_real$observation_date)
pce_real$G_growth <- pce_real$PCECTPI / c(NA_real_, head(pce_real$PCECTPI, -1))
pce_real$PCE_INFL <- 400 * (pce_real$G_growth - 1)
pce_q_real <- pce_real[, c("quarter", "PCE_INFL"), drop = FALSE]
pce_q_real <- pce_q_real[order(quarter_index_real(pce_q_real$quarter)), , drop = FALSE]
rownames(pce_q_real) <- NULL

unrate_q_real <- quarterly_mean_real(x = unrate_real, value_name = "UNRATE")
fedfunds_q_real <- quarterly_mean_real(x = fedfunds_real, value_name = "FEDFUNDS")

macro_bvar_real <- merge(pce_q_real, unrate_q_real, by = "quarter", all = FALSE)
macro_bvar_real <- merge(macro_bvar_real, fedfunds_q_real, by = "quarter", all = FALSE)
macro_bvar_real <- macro_bvar_real[order(quarter_index_real(macro_bvar_real$quarter)), , drop = FALSE]
macro_bvar_real <- macro_bvar_real[
  quarter_index_real(macro_bvar_real$quarter) <= quarter_index_real(sample_end_real), , drop = FALSE
]
macro_bvar_real <- macro_bvar_real[complete.cases(macro_bvar_real), , drop = FALSE]
rownames(macro_bvar_real) <- NULL

if (nrow(macro_bvar_real) == 0L) stop("The merged real-data dataset is empty.")
q_index_real <- quarter_index_real(macro_bvar_real$quarter)
if (any(diff(q_index_real) != 1L)) stop("The real-data dataset contains missing quarters.")
if (macro_bvar_real$quarter[1] != "1954Q3") stop("Unexpected starting quarter.")
if (tail(macro_bvar_real$quarter, 1L) != "2026Q2") stop("Unexpected ending quarter.")
if (anyNA(macro_bvar_real)) stop("Missing values remain in the final dataset.")
if (nrow(macro_bvar_real) != 288L) stop("Unexpected number of observations.")

training_data_real <- macro_bvar_real[1:T0_len_real, , drop = FALSE]
estimation_data_real <- macro_bvar_real[(T0_len_real + 1L):nrow(macro_bvar_real), , drop = FALSE]

y_full_real <- as.matrix(macro_bvar_real[, c("PCE_INFL", "UNRATE", "FEDFUNDS")])
storage.mode(y_full_real) <- "double"
y_est_real <- y_full_real[(T0_len_real + 1L):nrow(y_full_real), , drop = FALSE]
quarter_full_real <- macro_bvar_real$quarter
quarter_est_real <- estimation_data_real$quarter
var_names_real <- colnames(y_full_real)
axis_at_real <- seq(1, length(quarter_est_real), by = 20)

y_full_model_real <- y_full_real
y_full_model_real[quarter_full_real == excluded_quarter_real, ] <- NA_real_
# 6.2 Model functions (factorized evaluation, break search, DP, stability)
prepare_model_space_empirical <- function(gamma_grid, prior_info) {
  J <- nrow(gamma_grid)
  n <- prior_info$n
  pmax <- prior_info$pmax
  models <- vector("list", J)
  for (j in seq_len(J)) {
    gamma <- gamma_grid[j, ]
    cols <- 1L
    for (ell in seq_len(pmax)) {
      if (gamma[ell] == 1L) cols <- c(cols, 1L + seq.int((ell - 1L) * n + 1L, ell * n))
    }
    models[[j]] <- list(
      label = rownames(gamma_grid)[j], cols = cols,
      prior = prior_mniw_for_gamma(gamma = gamma, prior_info = prior_info)
    )
  }
  list(models = models, J = J)
}

evaluate_segment_models_empirical <- function(Y_segment, Xfull_segment, model_space, keep_scan = FALSE) {
  J <- model_space$J
  logv <- numeric(J)
  for (j in seq_len(J)) {
    model_j <- model_space$models[[j]]
    prior_j <- model_j$prior
    Xj <- Xfull_segment[, model_j$cols, drop = FALSE]
    logv[j] <- log_marginal_mniw(Y = Y_segment, X = Xj, B0 = prior_j$B0, V0 = prior_j$V0, S0 = prior_j$S0, nu0 = prior_j$nu0)
  }
  names(logv) <- vapply(model_space$models, function(z) z$label, character(1))
  if (!any(is.finite(logv))) stop("No finite marginal likelihood found in this segment.")
  denom <- log_sum_exp(logv)
  best_index <- which.max(logv)
  out <- list(
    integrated_logmarg = log_mean_exp(logv), best_gamma = names(logv)[best_index],
    best_gamma_postprob = exp(logv[best_index] - denom)
  )
  if (keep_scan) {
    scan <- data.frame(gamma = names(logv), logmarg = as.numeric(logv),
                        postprob_segment = exp(logv - denom), stringsAsFactors = FALSE)
    scan <- scan[order(scan$logmarg, decreasing = TRUE), , drop = FALSE]
    rownames(scan) <- NULL
    out$scan <- scan
  }
  out
}

make_segment_evaluator_empirical <- function(full_design, model_space, valid_rows = NULL) {
  first_t <- min(full_design$t_index)
  last_t <- max(full_design$t_index)
  cache_logmarg <- matrix(NA_real_, nrow = last_t, ncol = last_t)
  cache_gamma <- matrix(NA_character_, nrow = last_t, ncol = last_t)
  cache_postprob <- matrix(NA_real_, nrow = last_t, ncol = last_t)
  cache_n_likelihood <- matrix(NA_integer_, nrow = last_t, ncol = last_t)

  function(start_abs, end_abs, keep_scan = FALSE) {
    start_abs <- as.integer(start_abs); end_abs <- as.integer(end_abs)
    if (start_abs < first_t || end_abs > last_t || start_abs > end_abs) stop("Invalid empirical segment.")

    if (!keep_scan && is.finite(cache_logmarg[start_abs, end_abs])) {
      return(list(
        integrated_logmarg = cache_logmarg[start_abs, end_abs], best_gamma = cache_gamma[start_abs, end_abs],
        best_gamma_postprob = cache_postprob[start_abs, end_abs], nobs = end_abs - start_abs + 1L,
        n_likelihood = cache_n_likelihood[start_abs, end_abs]
      ))
    }

    rows <- (start_abs - first_t + 1L):(end_abs - first_t + 1L)
    if (!is.null(valid_rows)) rows <- rows[valid_rows[rows]]

    fit <- evaluate_segment_models_empirical(
      Y_segment = full_design$Y[rows, , drop = FALSE], Xfull_segment = full_design$Xfull[rows, , drop = FALSE],
      model_space = model_space, keep_scan = keep_scan
    )
    fit$nobs <- end_abs - start_abs + 1L    # n_calendar
    fit$n_likelihood <- length(rows)

    if (!keep_scan) {
      cache_logmarg[start_abs, end_abs] <<- fit$integrated_logmarg
      cache_gamma[start_abs, end_abs] <<- fit$best_gamma
      cache_postprob[start_abs, end_abs] <<- fit$best_gamma_postprob
      cache_n_likelihood[start_abs, end_abs] <<- fit$n_likelihood
    }
    fit
  }
}

make_break_configurations_empirical <- function(m, T0, T_end, min_segment_length) {
  m <- as.integer(m)
  if (m == 0L) return(matrix(integer(0), nrow = 1L, ncol = 0L))
  T_est <- T_end - T0
  if (T_est < (m + 1L) * min_segment_length) stop("The sample is too short for this m and n_min.")
  upper_adjusted <- T_est - min_segment_length - (m - 1L) * (min_segment_length - 1L)
  adjusted_support <- seq.int(from = min_segment_length, to = upper_adjusted)
  z <- combn(adjusted_support, m)
  offsets <- (seq_len(m) - 1L) * (min_segment_length - 1L)
  breaks_est <- sweep(z, MARGIN = 1L, STATS = offsets, FUN = "+")
  breaks_abs <- breaks_est + T0
  out <- t(breaks_abs)
  colnames(out) <- paste0("tau", seq_len(m))
  storage.mode(out) <- "integer"
  out
}

scan_break_number_empirical <- function(m, break_configurations, evaluate_segment, T0, T_end, verbose = FALSE) {
  m <- as.integer(m)
  configurations <- break_configurations[[m + 1L]]
  n_configurations <- nrow(configurations)
  logmarg <- numeric(n_configurations)

  for (i in seq_len(n_configurations)) {
    breaks_i <- if (m == 0L) integer(0) else as.integer(configurations[i, ])
    edges <- c(T0, breaks_i, T_end)
    total_logmarg <- 0
    for (s in seq_len(m + 1L)) {
      fit_s <- evaluate_segment(start_abs = edges[s] + 1L, end_abs = edges[s + 1L])
      total_logmarg <- total_logmarg + fit_s$integrated_logmarg
    }
    logmarg[i] <- total_logmarg
  }

  scan <- if (m == 0L) data.frame(logmarg = logmarg) else as.data.frame(configurations)
  if (m != 0L) scan$logmarg <- logmarg
  scan$delta_vs_best <- scan$logmarg - max(scan$logmarg)

  best_index <- which.max(scan$logmarg)
  best_breaks <- if (m == 0L) integer(0) else as.integer(configurations[best_index, , drop = TRUE])
  best_edges <- c(T0, best_breaks, T_end)

  best_gammas <- character(m + 1L)
  best_gamma_postprob <- numeric(m + 1L)
  for (s in seq_len(m + 1L)) {
    fit_s <- evaluate_segment(start_abs = best_edges[s] + 1L, end_abs = best_edges[s + 1L])
    best_gammas[s] <- fit_s$best_gamma
    best_gamma_postprob[s] <- fit_s$best_gamma_postprob
  }

  list(m = m, scan = scan, best_logmarg = scan$logmarg[best_index], best_breaks = best_breaks,
       best_gammas = best_gammas, best_gamma_postprob = best_gamma_postprob)
}

scan_break_number_dp_empirical <- function(m, evaluate_segment, T0, T_end, min_segment_length) {
  m <- as.integer(m)
  if (m == 0L) {
    fit0 <- evaluate_segment(start_abs = T0 + 1L, end_abs = T_end)
    return(list(m = 0L, best_logmarg = fit0$integrated_logmarg, best_breaks = integer(0),
                best_gammas = fit0$best_gamma, best_gamma_postprob = fit0$best_gamma_postprob))
  }

  t_grid <- T0:T_end
  n_t <- length(t_grid)
  idx_of <- function(t) t - T0 + 1L
  NEG_INF <- -Inf

  DP <- vector("list", m + 1L)
  back <- vector("list", m + 1L)
  for (k in seq_len(m + 1L)) { DP[[k]] <- rep(NEG_INF, n_t); back[[k]] <- rep(NA_integer_, n_t) }

  for (t in t_grid) {
    if (t - T0 >= min_segment_length) DP[[1L]][idx_of(t)] <- evaluate_segment(T0 + 1L, t)$integrated_logmarg
  }

  for (k in 2:(m + 1L)) {
    for (t in t_grid) {
      if (T_end - t < (m + 1L - k) * min_segment_length) next
      best_val <- NEG_INF; best_tprev <- NA_integer_
      for (t_prev in t_grid) {
        if (t_prev >= t) break
        if (t - t_prev < min_segment_length) next
        prev_val <- DP[[k - 1L]][idx_of(t_prev)]
        if (!is.finite(prev_val)) next
        cand <- prev_val + evaluate_segment(t_prev + 1L, t)$integrated_logmarg
        if (cand > best_val) { best_val <- cand; best_tprev <- t_prev }
      }
      DP[[k]][idx_of(t)] <- best_val
      back[[k]][idx_of(t)] <- best_tprev
    }
  }

  best_logmarg <- DP[[m + 1L]][idx_of(T_end)]
  if (!is.finite(best_logmarg)) stop("DP found no feasible partition for m = ", m, ".")

  breaks_rev <- integer(0); t_cur <- T_end
  for (k in (m + 1L):2L) { t_prev <- back[[k]][idx_of(t_cur)]; breaks_rev <- c(t_prev, breaks_rev); t_cur <- t_prev }
  best_breaks <- breaks_rev

  edges <- c(T0, best_breaks, T_end)
  best_gammas <- character(m + 1L); best_gamma_postprob <- numeric(m + 1L)
  for (s in seq_len(m + 1L)) {
    fit_s <- evaluate_segment(edges[s] + 1L, edges[s + 1L])
    best_gammas[s] <- fit_s$best_gamma; best_gamma_postprob[s] <- fit_s$best_gamma_postprob
  }

  list(m = m, best_logmarg = best_logmarg, best_breaks = best_breaks,
       best_gammas = best_gammas, best_gamma_postprob = best_gamma_postprob)
}

posterior_mean_stability_empirical <- function(full_design, start_abs, end_abs, gamma_string, prior_info, valid_rows = NULL) {
  gamma_vec <- label_to_gamma(gamma_string)
  mask <- full_design$t_index >= start_abs & full_design$t_index <= end_abs
  if (!is.null(valid_rows)) mask <- mask & valid_rows
  Y_seg <- full_design$Y[mask, , drop = FALSE]
  Xfull_seg <- full_design$Xfull[mask, , drop = FALSE]
  Xj <- select_X_from_gamma(Xfull = Xfull_seg, gamma = gamma_vec, n = prior_info$n, pmax = prior_info$pmax)
  pr <- prior_mniw_for_gamma(gamma = gamma_vec, prior_info = prior_info)

  V0_inv <- solve(pr$V0)
  Vn_inv <- V0_inv + crossprod(Xj)
  Vn <- solve(Vn_inv)
  Bn <- Vn %*% (V0_inv %*% pr$B0 + crossprod(Xj, Y_seg))

  n <- prior_info$n; pmax <- prior_info$pmax
  A_list <- replicate(pmax, matrix(0, n, n), simplify = FALSE)
  for (ell in seq_len(pmax)) {
    rows <- which(pr$reg_info$type == "lag" & pr$reg_info$lag == ell)
    if (length(rows) > 0L) A_list[[ell]] <- t(Bn[rows, , drop = FALSE])
  }
  rho <- companion_radius(A_list_regime = A_list, n = n)
  list(radius = rho, stable = is.finite(rho) && rho < 1, Bn = Bn, A_list = A_list)
}

compute_pip_empirical <- function(scan_df, pmax) {
  pip <- numeric(pmax)
  for (ell in seq_len(pmax)) {
    included <- vapply(scan_df$gamma, function(g) as.integer(substr(g, ell, ell)) == 1L, logical(1))
    pip[ell] <- sum(scan_df$postprob_segment[included])
  }
  names(pip) <- paste0("lag", seq_len(pmax))
  pip
}
# 6.3 Estimation engine: context builder and per-run estimator
build_empirical_context_v2 <- function(y_full_model, quarter_full, T0, pmax) {
  T_end <- nrow(y_full_model)
  train_y <- y_full_model[1:T0, , drop = FALSE]
  gamma_grid <- make_gamma_grid(pmax)
  prior_info <- make_prior_info(train_y = train_y, pmax = pmax, lambda_const = 10, lambda_lag = 0.40,
                                 lambda_decay = 1, own_lag_mean = 0, nu0_extra = 2)
  full_design <- build_full_design(y_full = y_full_model, pmax = pmax, T0 = T0)

  valid_rows <- !apply(is.na(full_design$Y), 1, any) & !apply(is.na(full_design$Xfull[, -1, drop = FALSE]), 1, any)

  model_space <- prepare_model_space_empirical(gamma_grid = gamma_grid, prior_info = prior_info)
  evaluate_segment <- make_segment_evaluator_empirical(full_design = full_design, model_space = model_space, valid_rows = valid_rows)

  list(T0 = T0, T_end = T_end, pmax = pmax, gamma_grid = gamma_grid, prior_info = prior_info,
       full_design = full_design, model_space = model_space, evaluate_segment = evaluate_segment,
       quarter_full = quarter_full, valid_rows = valid_rows)
}

run_empirical_bvar_from_context <- function(context, min_segment_length, max_breaks, dp_for_m = integer(0),
                                             validate_dp = TRUE, verbose = FALSE) {
  T0 <- context$T0; T_end <- context$T_end; pmax <- context$pmax
  quarter_full <- context$quarter_full
  evaluate_segment <- context$evaluate_segment

  if (T_end - T0 < (max_breaks + 1L) * min_segment_length) stop("Estimation sample too short for max_breaks.")

  exhaustive_m <- setdiff(0:max_breaks, dp_for_m)
  break_configurations <- lapply(exhaustive_m, function(m) {
    make_break_configurations_empirical(m = m, T0 = T0, T_end = T_end, min_segment_length = min_segment_length)
  })
  names(break_configurations) <- paste0("m", exhaustive_m)

  exhaustive_m3_precomputed <- NULL
  if (length(dp_for_m) > 0L && validate_dp) {
    if (is.null(break_configurations[["m3"]])) stop("DP validation requires exhaustive m = 3.")
    exhaustive_m3_precomputed <- scan_break_number_empirical(3L, break_configurations, evaluate_segment, T0, T_end, verbose)
    dp_m3 <- scan_break_number_dp_empirical(3L, evaluate_segment, T0, T_end, min_segment_length)
    if (abs(exhaustive_m3_precomputed$best_logmarg - dp_m3$best_logmarg) > 1e-6 ||
        !identical(as.integer(exhaustive_m3_precomputed$best_breaks), as.integer(dp_m3$best_breaks))) {
      stop("DP validation FAILED at m = 3.")
    }
    if (verbose) cat("DP validation OK at m = 3.\n")
  }

  results_by_m <- vector("list", max_breaks + 1L)
  names(results_by_m) <- paste0("m", 0:max_breaks)
  for (m in 0:max_breaks) {
    if (m %in% dp_for_m) {
      results_by_m[[m + 1L]] <- scan_break_number_dp_empirical(m, evaluate_segment, T0, T_end, min_segment_length)
    } else if (m == 3L && !is.null(exhaustive_m3_precomputed)) {
      results_by_m[[m + 1L]] <- exhaustive_m3_precomputed
    } else {
      results_by_m[[m + 1L]] <- scan_break_number_empirical(m, break_configurations, evaluate_segment, T0, T_end, verbose)
    }
  }

  profile_logmarg <- vapply(results_by_m, function(z) z$best_logmarg, numeric(1))
  selection_table <- data.frame(
    m = 0:max_breaks, profile_logmarg = profile_logmarg, delta_vs_best = profile_logmarg - max(profile_logmarg),
    break_quarters = character(max_breaks + 1L), best_gammas = character(max_breaks + 1L), stringsAsFactors = FALSE
  )
  for (m in 0:max_breaks) {
    fit_m <- results_by_m[[m + 1L]]
    selection_table$break_quarters[m + 1L] <- if (m == 0L) "-" else paste(quarter_full[fit_m$best_breaks], collapse = ", ")
    selection_table$best_gammas[m + 1L] <- paste(fit_m$best_gammas, collapse = ", ")
  }

  selected_m <- selection_table$m[which.max(selection_table$profile_logmarg)]
  selected_breaks <- results_by_m[[selected_m + 1L]]$best_breaks

  if (selected_m == 0L) {
    break_table <- data.frame(break_id = integer(0), tau_abs = integer(0), tau_est = integer(0),
                               last_quarter_previous_regime = character(0), first_quarter_next_regime = character(0),
                               stringsAsFactors = FALSE)
  } else {
    break_table <- data.frame(
      break_id = seq_len(selected_m), tau_abs = selected_breaks, tau_est = selected_breaks - T0,
      last_quarter_previous_regime = quarter_full[selected_breaks],
      first_quarter_next_regime = quarter_full[selected_breaks + 1L], stringsAsFactors = FALSE
    )
  }

  edges <- c(T0, selected_breaks, T_end)
  n_regimes <- selected_m + 1L
  regime_table <- data.frame(
    regime = seq_len(n_regimes), start_quarter = NA_character_, end_quarter = NA_character_,
    nobs = NA_integer_, n_likelihood = NA_integer_, best_gamma = NA_character_, best_gamma_postprob = NA_real_,
    companion_radius = NA_real_, stable = NA, stringsAsFactors = FALSE
  )
  selected_regime_fits <- vector("list", n_regimes)
  for (s in seq_len(n_regimes)) {
    start_abs <- edges[s] + 1L; end_abs <- edges[s + 1L]
    fit_s <- evaluate_segment(start_abs = start_abs, end_abs = end_abs, keep_scan = TRUE)
    stability_s <- posterior_mean_stability_empirical(
      full_design = context$full_design, start_abs = start_abs, end_abs = end_abs,
      gamma_string = fit_s$best_gamma, prior_info = context$prior_info, valid_rows = context$valid_rows
    )
    regime_table$start_quarter[s] <- quarter_full[start_abs]
    regime_table$end_quarter[s] <- quarter_full[end_abs]
    regime_table$nobs[s] <- fit_s$nobs
    regime_table$n_likelihood[s] <- fit_s$n_likelihood
    regime_table$best_gamma[s] <- fit_s$best_gamma
    regime_table$best_gamma_postprob[s] <- fit_s$best_gamma_postprob
    regime_table$companion_radius[s] <- stability_s$radius
    regime_table$stable[s] <- stability_s$stable
    selected_regime_fits[[s]] <- list(scan = fit_s$scan, posterior_mean_B = stability_s$Bn, A_list = stability_s$A_list)
  }
  names(selected_regime_fits) <- paste0("regime", seq_len(n_regimes))

  list(
    settings = list(T0 = T0, T_end = T_end, pmax = pmax, J = nrow(context$gamma_grid),
                     max_breaks = max_breaks, min_segment_length = min_segment_length),
    selection_table = selection_table, selected_m = selected_m, selected_breaks = selected_breaks,
    break_table = break_table, regime_table = regime_table, selected_regime_fits = selected_regime_fits
  )
}
# 6.4 Diagnostic functions (gap-aware Ljung-Box/ARCH/ACF, restricted-OLS multivariate LM)
acf_gap_empirical <- function(resid_vec, t_index, max_lag = 12) {
  N <- length(resid_vec)
  e <- resid_vec - mean(resid_vec)
  gamma0 <- sum(e^2)
  pos_of <- setNames(seq_len(N), as.character(t_index))
  rho <- rep(NA_real_, max_lag); valid_pairs <- integer(max_lag)
  for (h in seq_len(max_lag)) {
    match_pos <- pos_of[as.character(t_index - h)]
    valid <- !is.na(match_pos)
    valid_pairs[h] <- sum(valid)
    if (valid_pairs[h] > 0 && gamma0 > 0) rho[h] <- sum(e[valid] * e[match_pos[valid]]) / gamma0
  }
  data.frame(lag = seq_len(max_lag), autocorrelation = rho, valid_pairs = valid_pairs)
}

ljung_box_gap_test <- function(resid_vec, t_index, max_lag = 4) {
  N <- length(resid_vec)
  acf_tab <- acf_gap_empirical(resid_vec, t_index, max_lag = max_lag)
  stat_terms <- ifelse(acf_tab$valid_pairs > 0 & !is.na(acf_tab$autocorrelation),
                        acf_tab$autocorrelation^2 / acf_tab$valid_pairs, 0)
  Q <- N * (N + 2) * sum(stat_terms)
  list(statistic = Q, p_value = 1 - pchisq(Q, df = max_lag), lag = max_lag, valid_pairs = acf_tab$valid_pairs)
}

arch_lm_test <- function(resid_vec, t_index, lags = 4) {
  N <- length(resid_vec)
  e2 <- resid_vec^2
  pos_of <- setNames(seq_len(N), as.character(t_index))
  X <- matrix(NA_real_, nrow = N, ncol = lags); rows_ok <- logical(N)
  for (i in seq_len(N)) {
    lag_pos <- pos_of[as.character(t_index[i] - seq_len(lags))]
    if (!anyNA(lag_pos)) { rows_ok[i] <- TRUE; X[i, ] <- e2[lag_pos] }
  }
  y <- e2[rows_ok]; N_eff <- length(y)
  if (N_eff <= lags + 2) return(list(statistic = NA_real_, p_value = NA_real_, lags = lags, N_eff = N_eff))
  fit <- lm.fit(x = cbind(1, X[rows_ok, , drop = FALSE]), y = y)
  r2 <- { ss_tot <- sum((y - mean(y))^2); if (ss_tot > 0) 1 - sum(fit$residuals^2) / ss_tot else 0 }
  stat <- N_eff * r2
  list(statistic = stat, p_value = 1 - pchisq(stat, df = lags), lags = lags, N_eff = N_eff)
}

get_regime_residuals_empirical <- function(full_design, edges, s, gamma_string, Bn, n, pmax, valid_rows = NULL) {
  start_abs <- edges[s] + 1L; end_abs <- edges[s + 1L]
  mask <- full_design$t_index >= start_abs & full_design$t_index <= end_abs
  if (!is.null(valid_rows)) mask <- mask & valid_rows
  Y_seg <- full_design$Y[mask, , drop = FALSE]
  Xfull_seg <- full_design$Xfull[mask, , drop = FALSE]
  gamma_vec <- label_to_gamma(gamma_string)
  Xj <- select_X_from_gamma(Xfull = Xfull_seg, gamma = gamma_vec, n = n, pmax = pmax)
  fitted_seg <- Xj %*% Bn
  list(Y = Y_seg, fitted = fitted_seg, resid = Y_seg - fitted_seg, X_selected = Xj,
       t_index_kept = full_design$t_index[mask])
}

compute_regime_residual_tests <- function(resid_seg, t_index_kept, var_names, regime_id, lb_lag = 4, arch_lag = 4, alpha = 0.05) {
  no_gap <- length(t_index_kept) >= 2L && all(diff(t_index_kept) == 1L)
  rows <- vector("list", length(var_names))
  for (j in seq_along(var_names)) {
    r <- resid_seg[, j]
    sw <- tryCatch(shapiro.test(r), error = function(e) NULL)
    lb <- tryCatch(ljung_box_gap_test(r, t_index_kept, max_lag = lb_lag), error = function(e) NULL)
    arch <- arch_lm_test(r, t_index_kept, lags = arch_lag)

    if (no_gap && !is.null(lb)) {
      lb_ref <- Box.test(r, lag = lb_lag, type = "Ljung-Box")
      if (abs(unname(lb_ref$statistic) - lb$statistic) > 1e-6) stop("Gap-aware Ljung-Box mismatch vs Box.test().")
    }

    sw_p <- if (!is.null(sw)) sw$p.value else NA_real_
    lb_p <- if (!is.null(lb)) lb$p_value else NA_real_
    rows[[j]] <- data.frame(
      regime = regime_id, variable = var_names[j], Shapiro_p = sw_p, LjungBox_p = lb_p, ARCH_p = arch$p_value,
      Shapiro_reject = !is.na(sw_p) & sw_p < alpha, LjungBox_reject = !is.na(lb_p) & lb_p < alpha,
      ARCH_reject = !is.na(arch$p_value) & arch$p_value < alpha, stringsAsFactors = FALSE
    )
  }
  do.call(rbind, rows)
}

restricted_ols_residuals <- function(full_design, edges, s, gamma_string, n, pmax, valid_rows = NULL) {
  start_abs <- edges[s] + 1L; end_abs <- edges[s + 1L]
  mask <- full_design$t_index >= start_abs & full_design$t_index <= end_abs
  if (!is.null(valid_rows)) mask <- mask & valid_rows
  Y_seg <- full_design$Y[mask, , drop = FALSE]
  Xfull_seg <- full_design$Xfull[mask, , drop = FALSE]
  gamma_vec <- label_to_gamma(gamma_string)
  Xj <- select_X_from_gamma(Xfull = Xfull_seg, gamma = gamma_vec, n = n, pmax = pmax)
  N <- nrow(Xj); q <- ncol(Xj)
  available <- (qr(Xj)$rank == q) && (N - q) >= 1L
  if (!available) return(list(available = FALSE, resid = NULL, X_selected = Xj, t_index_kept = full_design$t_index[mask]))
  fit <- lm.fit(x = Xj, y = Y_seg)
  list(available = TRUE, resid = fit$residuals, X_selected = Xj, t_index_kept = full_design$t_index[mask])
}

multivariate_lm_serial_test_ols <- function(U0_all, X_selected_all, t_index_kept, h) {
  N <- nrow(U0_all); K <- ncol(U0_all)
  pos_of <- setNames(seq_len(N), as.character(t_index_kept))
  rows_ok <- logical(N); lag_mat <- matrix(NA_real_, nrow = N, ncol = K * h)
  for (i in seq_len(N)) {
    lag_pos <- pos_of[as.character(t_index_kept[i] - seq_len(h))]
    if (!anyNA(lag_pos)) { rows_ok[i] <- TRUE; lag_mat[i, ] <- as.vector(t(U0_all[lag_pos, , drop = FALSE])) }
  }
  N_eff <- sum(rows_ok); df <- h * K^2
  n_orig <- ncol(X_selected_all); n_aux <- n_orig + K * h
  na_res <- list(statistic = NA_real_, p_value = NA_real_, df = df, N_eff = N_eff,
                 n_original_regressors = n_orig, n_auxiliary_regressors = n_aux, available = FALSE)
  if (N_eff <= n_aux + K) return(na_res)

  U0 <- U0_all[rows_ok, , drop = FALSE]
  X0 <- X_selected_all[rows_ok, , drop = FALSE]
  Xaux <- cbind(X0, lag_mat[rows_ok, , drop = FALSE])
  if (qr(X0)$rank < ncol(X0) || qr(Xaux)$rank < ncol(Xaux)) return(na_res)

  fit0 <- lm.fit(x = X0, y = U0)
  Sigma_0 <- crossprod(fit0$residuals) / N_eff
  fit_aux <- lm.fit(x = Xaux, y = U0)
  Sigma_R <- crossprod(fit_aux$residuals) / N_eff
  Sigma_0_inv <- tryCatch(solve(Sigma_0), error = function(e) NULL)
  if (is.null(Sigma_0_inv)) return(na_res)
  stat <- N_eff * (K - sum(diag(Sigma_R %*% Sigma_0_inv)))
  if (!is.finite(stat) || stat < 0) return(na_res)
  list(statistic = stat, p_value = 1 - pchisq(stat, df = df), df = df, N_eff = N_eff,
       n_original_regressors = n_orig, n_auxiliary_regressors = n_aux, available = TRUE)
}

run_full_diagnostics_for_model <- function(fit, full_design, pmax, valid_rows, var_names) {
  edges <- c(fit$settings$T0, fit$selected_breaks, fit$settings$T_end)
  n_regimes <- nrow(fit$regime_table)
  main_rows <- vector("list", n_regimes); acf_rows <- list(); resid_list <- vector("list", n_regimes)
  for (s in seq_len(n_regimes)) {
    reg_row <- fit$regime_table[s, ]
    diag_s <- get_regime_residuals_empirical(
      full_design, edges, s, reg_row$best_gamma, fit$selected_regime_fits[[s]]$posterior_mean_B,
      length(var_names), pmax, valid_rows
    )
    resid_list[[s]] <- diag_s
    res_s <- compute_regime_residual_tests(diag_s$resid, diag_s$t_index_kept, var_names, regime_id = s)
    main_rows[[s]] <- res_s

    no_gap_s <- length(diag_s$t_index_kept) >= 2L && all(diff(diag_s$t_index_kept) == 1L)
    for (vname in var_names[res_s$LjungBox_reject]) {
      j <- match(vname, var_names)
      acf_tab <- acf_gap_empirical(diag_s$resid[, j], diag_s$t_index_kept, max_lag = 12L)
      acf_rows[[length(acf_rows) + 1L]] <- data.frame(
        regime = s, variable = vname, lag = acf_tab$lag,
        autocorrelation = acf_tab$autocorrelation, valid_pairs = acf_tab$valid_pairs, stringsAsFactors = FALSE
      )
      if (no_gap_s) {
        ref_acf <- as.numeric(stats::acf(diag_s$resid[, j], lag.max = 12L, plot = FALSE)$acf)[-1]
        if (any(abs(ref_acf - acf_tab$autocorrelation) > 1e-6)) stop("Gap-aware ACF mismatch vs stats::acf().")
      }
    }
  }
  list(residual_main = do.call(rbind, main_rows),
       acf_table = if (length(acf_rows) > 0L) do.call(rbind, acf_rows) else NULL,
       resid_list = resid_list)
}

compute_ols_lm_for_model <- function(fit, full_design, pmax, valid_rows, n_vars, lm_orders = 1:4) {
  edges <- c(fit$settings$T0, fit$selected_breaks, fit$settings$T_end)
  n_regimes <- nrow(fit$regime_table)
  rows <- vector("list", n_regimes)
  for (s in seq_len(n_regimes)) {
    reg_row <- fit$regime_table[s, ]
    ols_s <- restricted_ols_residuals(full_design, edges, s, reg_row$best_gamma, n_vars, pmax, valid_rows)
    if (!ols_s$available) {
      rows[[s]] <- data.frame(regime = s, h = lm_orders, p_value = NA_real_, reject_5pct = NA,
                               LM_available = FALSE, OLS_LM_available = FALSE, stringsAsFactors = FALSE)
      next
    }
    rows[[s]] <- do.call(rbind, lapply(lm_orders, function(h) {
      res <- multivariate_lm_serial_test_ols(ols_s$resid, ols_s$X_selected, ols_s$t_index_kept, h)
      data.frame(regime = s, h = h, p_value = res$p_value, reject_5pct = if (res$available) res$p_value < 0.05 else NA,
                 LM_available = res$available, OLS_LM_available = TRUE, stringsAsFactors = FALSE)
    }))
  }
  do.call(rbind, rows)
}
# 6.5 Plot functions
plot_series_with_breaks <- function(y_est, quarters, axis_at, breaks_tau_est, var_names, show_breaks = TRUE) {
  op <- par(no.readonly = TRUE)
  par(mfrow = c(3, 1), mar = c(7, 5, 3, 2))
  labs <- c("PCE inflation (% ann.)", "UNRATE (%)", "FEDFUNDS (%)")
  titles <- c("PCE inflation", "Unemployment rate", "Federal funds rate")
  for (j in seq_along(var_names)) {
    plot(seq_along(quarters), y_est[, j], type = "l", lwd = 2, xaxt = "n",
         xlab = "", ylab = labs[j], main = titles[j])
    axis(1, at = axis_at, labels = quarters[axis_at], las = 2)
    mtext("Quarter", side = 1, line = 5)
    if (show_breaks && length(breaks_tau_est) > 0) abline(v = breaks_tau_est, lty = 2, lwd = 2)
  }
  par(op)
}

plot_profile_logml <- function(selection_table) {
  par(mar = c(5, 5, 3, 2))
  plot(selection_table$m, selection_table$profile_logmarg, type = "b", pch = 19, lwd = 2,
       xlab = "Number of breaks m", ylab = "Profile log marginal likelihood",
       main = "Baseline: profile log ML by m")
}

plot_posterior_model_probs <- function(fit) {
  n_regimes <- nrow(fit$regime_table)
  op <- par(no.readonly = TRUE)
  par(mfrow = c(ceiling(n_regimes / 2), 2), mar = c(6, 5, 3, 2))
  for (s in seq_len(n_regimes)) {
    scan_s <- fit$selected_regime_fits[[s]]$scan
    scan_s <- scan_s[order(scan_s$gamma), , drop = FALSE]
    barplot(scan_s$postprob_segment, names.arg = scan_s$gamma, las = 2, cex.names = 0.7,
            ylab = "Posterior model probability", main = paste0("Regime ", s))
  }
  par(op)
}

plot_pip_by_regime <- function(fit, pmax) {
  n_regimes <- nrow(fit$regime_table)
  op <- par(no.readonly = TRUE)
  par(mfrow = c(ceiling(n_regimes / 2), 2), mar = c(5, 5, 3, 2))
  for (s in seq_len(n_regimes)) {
    pip_s <- compute_pip_empirical(fit$selected_regime_fits[[s]]$scan, pmax)
    barplot(pip_s, ylim = c(0, 1), names.arg = paste0("lag", seq_len(pmax)),
            ylab = "PIP", main = paste0("Regime ", s), col = "grey70", border = NA)
  }
  par(op)
}

plot_qq_grid <- function(resid_list, var_names) {
  n_regimes <- length(resid_list)
  op <- par(no.readonly = TRUE)
  par(mfrow = c(n_regimes, length(var_names)), mar = c(4, 4, 3, 1))
  for (s in seq_len(n_regimes)) {
    for (j in seq_along(var_names)) {
      qqnorm(resid_list[[s]]$resid[, j], main = paste0("Regime ", s, " - ", var_names[j]), pch = 20)
      qqline(resid_list[[s]]$resid[, j], lwd = 2)
    }
  }
  par(op)
}

plot_acf_rejections <- function(acf_table, n_likelihood_by_regime) {
  if (is.null(acf_table) || nrow(acf_table) == 0L) return(invisible(NULL))
  combos <- unique(acf_table[, c("regime", "variable")])
  n_panels <- nrow(combos)
  ncol_p <- min(3, n_panels)
  op <- par(no.readonly = TRUE)
  par(mfrow = c(ceiling(n_panels / ncol_p), ncol_p), mar = c(5, 5, 3, 2))
  for (i in seq_len(n_panels)) {
    s <- combos$regime[i]; v <- combos$variable[i]
    sub <- acf_table[acf_table$regime == s & acf_table$variable == v, ]
    sub <- sub[order(sub$lag), ]
    ci <- 1.96 / sqrt(n_likelihood_by_regime[s])
    plot(sub$lag, sub$autocorrelation, type = "h", lwd = 2,
         ylim = range(c(sub$autocorrelation, ci, -ci), na.rm = TRUE),
         xlab = "Lag", ylab = "Autocorrelation", main = paste0("Regime ", s, " - ", v))
    abline(h = 0)
    abline(h = c(-ci, ci), lty = 2, lwd = 2, col = "blue")
  }
  par(op)
}
# 6.6 Baseline: pmax = 4, n_min = 28
context_pmax4_real <- build_empirical_context_v2(
  y_full_model = y_full_model_real, quarter_full = quarter_full_real, T0 = T0_len_real, pmax = pmax_main_real
)
context_pmax8_real <- build_empirical_context_v2(
  y_full_model = y_full_model_real, quarter_full = quarter_full_real, T0 = T0_len_real, pmax = pmax_robust_real
)

results_real_main <- run_empirical_bvar_from_context(
  context = context_pmax4_real, min_segment_length = min_segment_length_real,
  max_breaks = max_breaks_real, dp_for_m = 4L, validate_dp = TRUE, verbose = FALSE
)
# Technical checks
full_design_main <- context_pmax4_real$full_design
valid_rows_main <- context_pmax4_real$valid_rows
full_design_robust <- context_pmax8_real$full_design
valid_rows_robust <- context_pmax8_real$valid_rows

idx_2020q2_abs <- which(quarter_full_real == excluded_quarter_real)
idx_2020q3_abs <- which(quarter_full_real == "2020Q3")
row_2020q2_main <- which(full_design_main$t_index == idx_2020q2_abs)
row_2020q3_main <- which(full_design_main$t_index == idx_2020q3_abs)
lag1_cols <- paste0(colnames(y_full_real), "_L1")

check_calendar_present <- (excluded_quarter_real %in% quarter_full_real) &&
  all(diff(quarter_index_real(quarter_full_real)) == 1L)
check_excluded_as_response <- !valid_rows_main[row_2020q2_main]
check_never_lag_regressor <- all(is.na(full_design_main$Xfull[row_2020q3_main, lag1_cols])) && !valid_rows_main[row_2020q3_main]
check_calendar_not_compressed <- all(diff(full_design_main$t_index) == 1L)
check_not_2020q1_as_lag1 <- is.na(full_design_main$Xfull[row_2020q3_main, lag1_cols[1]])

mask_common <- full_design_main$t_index >= (T0_len_real + 1L) & full_design_main$t_index <= nrow(y_full_real) & valid_rows_main
Xfull_common <- full_design_main$Xfull[mask_common, , drop = FALSE]
n_rows_g1 <- nrow(select_X_from_gamma(Xfull_common, label_to_gamma(paste(rep("1", pmax_main_real), collapse = "")), length(var_names_real), pmax_main_real))
n_rows_g0 <- nrow(select_X_from_gamma(Xfull_common, label_to_gamma(paste(c("1", rep("0", pmax_main_real - 1)), collapse = "")), length(var_names_real), pmax_main_real))
check_common_sample <- n_rows_g1 == n_rows_g0

first_valid_after_gap <- function(full_design, valid_rows, quarter_full, gap_abs) {
  cand <- full_design$t_index[valid_rows & full_design$t_index > gap_abs]
  quarter_full[min(cand)]
}
check_pmax4_first_valid <- identical(first_valid_after_gap(full_design_main, valid_rows_main, quarter_full_real, idx_2020q2_abs), "2021Q3")
check_pmax8_first_valid <- identical(first_valid_after_gap(full_design_robust, valid_rows_robust, quarter_full_real, idx_2020q2_abs), "2022Q3")

all_checks <- c(
  calendar_present = check_calendar_present, excluded_as_response = check_excluded_as_response,
  never_lag_regressor = check_never_lag_regressor, calendar_not_compressed = check_calendar_not_compressed,
  not_2020q1_as_lag1 = check_not_2020q1_as_lag1, common_sample = check_common_sample,
  pmax4_first_valid = check_pmax4_first_valid, pmax8_first_valid = check_pmax8_first_valid
)
if (!all(all_checks)) stop("Technical checks FAILED: ", paste(names(all_checks)[!all_checks], collapse = ", "))
cat("Technical checks: ALL PASSED\n")
edges_main <- c(T0_len_real, results_real_main$selected_breaks, nrow(y_full_real))
breaks_tau_est_main <- results_real_main$break_table$tau_est

pdf(file.path(figure_dir, "00_series_raw.pdf"), width = 8, height = 9)
plot_series_with_breaks(y_est_real, quarter_est_real, axis_at_real, breaks_tau_est_main, var_names_real, show_breaks = FALSE)
dev.off()
plot_series_with_breaks(y_est_real, quarter_est_real, axis_at_real, breaks_tau_est_main, var_names_real, show_breaks = FALSE)

pdf(file.path(figure_dir, "01_series_with_breaks_baseline.pdf"), width = 8, height = 9)
plot_series_with_breaks(y_est_real, quarter_est_real, axis_at_real, breaks_tau_est_main, var_names_real)
dev.off()
plot_series_with_breaks(y_est_real, quarter_est_real, axis_at_real, breaks_tau_est_main, var_names_real)

pdf(file.path(figure_dir, "02_profile_logML_by_m_baseline.pdf"), width = 7, height = 5)
plot_profile_logml(results_real_main$selection_table)
dev.off()
plot_profile_logml(results_real_main$selection_table)

pdf(file.path(figure_dir, "03_posterior_model_probabilities_baseline.pdf"), width = 9, height = 8)
plot_posterior_model_probs(results_real_main)
dev.off()
plot_posterior_model_probs(results_real_main)

pdf(file.path(figure_dir, "04_PIP_by_regime_baseline.pdf"), width = 8, height = 7)
plot_pip_by_regime(results_real_main, pmax_main_real)
dev.off()
plot_pip_by_regime(results_real_main, pmax_main_real)
diag_main <- run_full_diagnostics_for_model(results_real_main, full_design_main, pmax_main_real, valid_rows_main, var_names_real)
ols_lm_main <- compute_ols_lm_for_model(results_real_main, full_design_main, pmax_main_real, valid_rows_main, length(var_names_real))

pdf(file.path(figure_dir, "05_QQ_plots_baseline.pdf"), width = 9, height = 11)
plot_qq_grid(diag_main$resid_list, var_names_real)
dev.off()
plot_qq_grid(diag_main$resid_list, var_names_real)

pdf(file.path(figure_dir, "06_residual_ACF_rejections_baseline.pdf"), width = 9, height = 7)
plot_acf_rejections(diag_main$acf_table, results_real_main$regime_table$n_likelihood)
dev.off()
plot_acf_rejections(diag_main$acf_table, results_real_main$regime_table$n_likelihood)
# 6.7 Robustness: pmax = 8, n_min = 28
results_real_robust <- run_empirical_bvar_from_context(
  context = context_pmax8_real, min_segment_length = min_segment_length_real,
  max_breaks = max_breaks_real, dp_for_m = 4L, validate_dp = TRUE, verbose = FALSE
)
pdf(file.path(figure_dir, "07_PIP_by_regime_pmax8.pdf"), width = 8, height = 7)
plot_pip_by_regime(results_real_robust, pmax_robust_real)
dev.off()
plot_pip_by_regime(results_real_robust, pmax_robust_real)

diag_robust <- run_full_diagnostics_for_model(results_real_robust, full_design_robust, pmax_robust_real, valid_rows_robust, var_names_real)

pdf(file.path(figure_dir, "08_residual_ACF_rejections_pmax8.pdf"), width = 9, height = 7)
plot_acf_rejections(diag_robust$acf_table, results_real_robust$regime_table$n_likelihood)
dev.off()
plot_acf_rejections(diag_robust$acf_table, results_real_robust$regime_table$n_likelihood)
expected_figures <- c(
  file.path(figure_dir, "00_series_raw.pdf"),
  file.path(figure_dir, sprintf("%02d_%s.pdf", 1:8, c(
    "series_with_breaks_baseline", "profile_logML_by_m_baseline", "posterior_model_probabilities_baseline",
    "PIP_by_regime_baseline", "QQ_plots_baseline", "residual_ACF_rejections_baseline",
    "PIP_by_regime_pmax8", "residual_ACF_rejections_pmax8"
  )))
)
stopifnot(all(file.exists(expected_figures)))
cat("Chapter 6 figures saved in:", figure_dir, "/\n", sep = "")
# 6.8 Final tables
cat("\n--- Baseline selection ---\n")
print(results_real_main$selection_table[, c("m", "break_quarters", "profile_logmarg", "delta_vs_best")])

cat("\n--- Baseline regimes ---\n")
baseline_regimes_table <- data.frame(
  regime = results_real_main$regime_table$regime,
  period = paste(results_real_main$regime_table$start_quarter, results_real_main$regime_table$end_quarter, sep = "-"),
  n_calendar = results_real_main$regime_table$nobs, n_likelihood = results_real_main$regime_table$n_likelihood,
  best_gamma = results_real_main$regime_table$best_gamma, best_gamma_postprob = round(results_real_main$regime_table$best_gamma_postprob, 4),
  spectral_radius = round(results_real_main$regime_table$companion_radius, 4), stable = results_real_main$regime_table$stable
)
print(baseline_regimes_table)

cat("\n--- Baseline PIP ---\n")
baseline_pip_table <- do.call(rbind, lapply(seq_len(nrow(results_real_main$regime_table)), function(s) {
  pip_s <- compute_pip_empirical(results_real_main$selected_regime_fits[[s]]$scan, pmax_main_real)
  data.frame(regime = s, lag1 = pip_s[1], lag2 = pip_s[2], lag3 = pip_s[3], lag4 = pip_s[4])
}))
print(round(baseline_pip_table, 4))

cat("\n--- Baseline residual diagnostics ---\n")
print(diag_main$residual_main[, c("regime", "variable", "Shapiro_p", "LjungBox_p", "ARCH_p")])

cat("\n--- Baseline multivariate LM (restricted-OLS, diagnostic-only) ---\n")
baseline_lm_table <- do.call(rbind, lapply(seq_len(nrow(results_real_main$regime_table)), function(s) {
  sub <- ols_lm_main[ols_lm_main$regime == s, ]
  p_by_h <- vapply(1:4, function(h) { row <- sub[sub$h == h, ]; if (nrow(row) == 1L) row$p_value else NA_real_ }, numeric(1))
  data.frame(regime = s, LM_p_h1 = p_by_h[1], LM_p_h2 = p_by_h[2], LM_p_h3 = p_by_h[3], LM_p_h4 = p_by_h[4])
}))
print(baseline_lm_table)

cat("\n--- pmax = 8 robustness ---\n")
breaks_robust_str <- paste(results_real_robust$break_table$last_quarter_previous_regime, collapse = ", ")
robustness_summary_table <- data.frame(
  selected_m = results_real_robust$selected_m, break_dates = breaks_robust_str,
  best_gammas = paste(results_real_robust$regime_table$best_gamma, collapse = ", "),
  spectral_radii = paste(round(results_real_robust$regime_table$companion_radius, 3), collapse = ", "),
  Shapiro_rejections = sum(diag_robust$residual_main$Shapiro_reject, na.rm = TRUE),
  LjungBox_rejections = sum(diag_robust$residual_main$LjungBox_reject, na.rm = TRUE),
  ARCH_rejections = sum(diag_robust$residual_main$ARCH_reject, na.rm = TRUE),
  stringsAsFactors = FALSE
)
print(robustness_summary_table)
# 6.9 Save final results
saveRDS(
  list(
    baseline = results_real_main,
    baseline_diagnostics = diag_main$residual_main,
    baseline_multivariate_LM = baseline_lm_table,
    robustness_pmax8 = results_real_robust,
    robustness_pmax8_diagnostics = diag_robust$residual_main
  ),
  "BVAR_real_data_final_results.rds"
)
