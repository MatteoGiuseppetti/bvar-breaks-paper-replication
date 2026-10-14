# Three-break collapsed-MCMC functions: extracts from thesis script (line endings normalized).
# No two-break/one-break analysis is run by this file.

# Original BVAR_thesis_full_code.R lines 676-686 (verbatim)
flip_gamma_label <- function(gamma_label_current, pmax) {
  g <- label_to_gamma(gamma_label_current)
  ell <- sample(seq_len(pmax), size = 1)
  g[ell] <- 1L - g[ell]
  
  list(
    gamma_label = gamma_label(g),
    flipped_lag = ell
  )
}



# Original BVAR_thesis_full_code.R lines 708-767 (verbatim)
compute_convergence_diagnostics_general <- function(chains, m) {
  n_draws_min <- min(sapply(chains, function(z) nrow(z$breaks_draws)))
  
  rhat_per_break <- numeric(m)
  ess_bulk_per_break <- numeric(m)
  ess_tail_per_break <- numeric(m)
  
  for (k in seq_len(m)) {
    mat_k <- sapply(chains, function(z) z$breaks_draws[seq_len(n_draws_min), k])
    rhat_per_break[k] <- posterior::rhat(mat_k)
    ess_bulk_per_break[k] <- posterior::ess_bulk(mat_k)
    ess_tail_per_break[k] <- posterior::ess_tail(mat_k)
  }
  
  names(rhat_per_break) <- paste0("tau", seq_len(m))
  names(ess_bulk_per_break) <- paste0("tau", seq_len(m))
  names(ess_tail_per_break) <- paste0("tau", seq_len(m))
  
  list(
    Rhat = rhat_per_break,
    ESS_bulk = ess_bulk_per_break,
    ESS_tail = ess_tail_per_break
  )
}

compute_gamma_diagnostics_general <- function(chains, n_regimes, pmax) {
  n_draws_min <- min(sapply(chains, function(z) nrow(z$gammas_draws)))
  
  pip <- matrix(NA_real_, nrow = n_regimes, ncol = pmax)
  rhat <- matrix(NA_real_, nrow = n_regimes, ncol = pmax)
  ess_bulk <- matrix(NA_real_, nrow = n_regimes, ncol = pmax)
  ess_tail <- matrix(NA_real_, nrow = n_regimes, ncol = pmax)
  min_transitions <- matrix(NA_integer_, nrow = n_regimes, ncol = pmax)
  
  for (s in seq_len(n_regimes)) {
    for (ell in seq_len(pmax)) {
      
      ind_mat <- sapply(chains, function(z) {
        labs <- z$gammas_draws[seq_len(n_draws_min), s]
        as.integer(substr(labs, ell, ell))
      })
      
      pip[s, ell] <- mean(ind_mat)
      rhat[s, ell] <- posterior::rhat(ind_mat)
      ess_bulk[s, ell] <- posterior::ess_bulk(ind_mat)
      ess_tail[s, ell] <- posterior::ess_tail(ind_mat)
      
      transitions_per_chain <- apply(ind_mat, 2, function(col) sum(diff(col) != 0L))
      min_transitions[s, ell] <- min(transitions_per_chain)
    }
  }
  
  reg_names <- paste0("regime", seq_len(n_regimes))
  lag_names <- paste0("lag", seq_len(pmax))
  dimnames(pip) <- dimnames(rhat) <- dimnames(ess_bulk) <- dimnames(ess_tail) <-
    dimnames(min_transitions) <- list(reg_names, lag_names)
  
  list(PIP = pip, Rhat = rhat, ESS_bulk = ess_bulk, ESS_tail = ess_tail,
       MinTransitions = min_transitions)
}


# Original BVAR_thesis_full_code.R lines 771-813 (verbatim)
simulate_bvar_breaks <- function(T,
                                 breaks,
                                 pmax,
                                 c_list,
                                 A_list,
                                 Sigma_list,
                                 burnin = 200) {
  n <- length(c_list[[1]])
  m <- length(breaks)
  n_regimes <- m + 1L
  
  if (length(c_list) != n_regimes) {
    stop("c_list must have length m + 1.")
  }
  if (length(A_list) != n_regimes) {
    stop("A_list must have length m + 1.")
  }
  if (length(Sigma_list) != n_regimes) {
    stop("Sigma_list must have length m + 1.")
  }
  
  TT <- T + burnin
  y_all <- matrix(0, nrow = TT + pmax, ncol = n)
  
  for (tt in (pmax + 1):(TT + pmax)) {
    obs <- tt - pmax - burnin
    
    s <- sum(obs > breaks) + 1L
    s <- max(1L, min(s, n_regimes))
    
    mu <- c_list[[s]]
    
    for (ell in seq_len(pmax)) {
      mu <- mu + as.numeric(A_list[[s]][[ell]] %*% y_all[tt - ell, ])
    }
    
    y_all[tt, ] <- rmvnorm_one(mu, Sigma_list[[s]])
  }
  
  y <- y_all[(burnin + pmax + 1):(burnin + pmax + T), , drop = FALSE]
  colnames(y) <- paste0("y", seq_len(n))
  y
}


# Original BVAR_thesis_full_code.R lines 816-834 (verbatim)
make_segment_masks_from_breaks <- function(t_index, breaks) {
  breaks <- sort(as.integer(breaks))
  n_seg <- length(breaks) + 1L
  
  masks <- vector("list", n_seg)
  
  for (s in seq_len(n_seg)) {
    if (s == 1L) {
      masks[[s]] <- t_index <= breaks[1]
    } else if (s == n_seg) {
      masks[[s]] <- t_index > breaks[length(breaks)]
    } else {
      masks[[s]] <- t_index > breaks[s - 1L] & t_index <= breaks[s]
    }
  }
  
  names(masks) <- paste0("regime", seq_len(n_seg))
  masks
}


# Original BVAR_thesis_full_code.R lines 1461-1484 (verbatim)
regime_logmarg_live <- function(full_design, mask, gamma_label_regime,
                                prior_info) {
  
  gamma_vec <- label_to_gamma(gamma_label_regime)
  
  Y_seg <- full_design$Y[mask, , drop = FALSE]
  X_seg <- select_X_from_gamma(
    Xfull = full_design$Xfull[mask, , drop = FALSE],
    gamma = gamma_vec,
    n = prior_info$n,
    pmax = prior_info$pmax
  )
  
  pr <- prior_mniw_for_gamma(gamma_vec, prior_info)
  
  log_marginal_mniw(
    Y = Y_seg,
    X = X_seg,
    B0 = pr$B0,
    V0 = pr$V0,
    S0 = pr$S0,
    nu0 = pr$nu0
  )
}


# Original BVAR_thesis_full_code.R lines 1487-1509 (verbatim)
breaks_are_valid_general <- function(breaks, T0, T_end, min_segment_length,
                                     break_windows = NULL) {
  
  if (is.unsorted(breaks, strictly = TRUE)) return(FALSE)
  if (breaks[1] <= T0) return(FALSE)
  if (breaks[length(breaks)] >= T_end) return(FALSE)
  
  edges <- c(T0, breaks, T_end)
  seg_len <- diff(edges)
  
  if (!all(seg_len >= min_segment_length)) return(FALSE)
  
  if (!is.null(break_windows)) {
    for (k in seq_along(breaks)) {
      w <- break_windows[[k]]
      if (!is.null(w)) {
        if (breaks[k] < w[1] || breaks[k] > w[2]) return(FALSE)
      }
    }
  }
  
  TRUE
}


# Original BVAR_thesis_full_code.R lines 1512-1537 (verbatim)
propose_break_local_general <- function(breaks_current, T0, T_end,
                                        min_segment_length,
                                        steps = c(-10, -5, -2, -1, 1, 2, 5, 10),
                                        break_windows = NULL) {
  
  m <- length(breaks_current)
  k <- sample.int(m, size = 1)
  step <- sample(steps, size = 1)
  
  breaks_new <- breaks_current
  breaks_new[k] <- breaks_current[k] + step
  
  valid <- breaks_are_valid_general(
    breaks = breaks_new,
    T0 = T0,
    T_end = T_end,
    min_segment_length = min_segment_length,
    break_windows = break_windows
  )
  
  if (!valid) {
    return(list(breaks_new = breaks_current, k = k, valid = FALSE))
  }
  
  list(breaks_new = breaks_new, k = k, valid = TRUE)
}


# Original BVAR_thesis_full_code.R lines 1539-1550 (verbatim)
propose_gamma_flip_general <- function(gammas_current, pmax) {
  
  n_regimes <- length(gammas_current)
  s <- sample.int(n_regimes, size = 1)
  
  prop <- flip_gamma_label(gammas_current[s], pmax)
  
  gammas_new <- gammas_current
  gammas_new[s] <- prop$gamma_label
  
  list(gammas_new = gammas_new, regime = s, flipped_lag = prop$flipped_lag)
}


# Original BVAR_thesis_full_code.R lines 1553-1713 (verbatim)
run_mcmc_general_live <- function(full_design,
                                  prior_info,
                                  breaks_init,
                                  gammas_init,
                                  T0,
                                  T_end,
                                  min_segment_length,
                                  n_iter = 20000,
                                  seed = NULL,
                                  verbose = FALSE,
                                  break_windows = NULL) {
  
  if (!is.null(seed)) set.seed(seed)
  
  m <- length(breaks_init)
  n_regimes <- m + 1L
  
  if (length(gammas_init) != n_regimes) {
    stop("gammas_init must have length m + 1.")
  }
  if (!breaks_are_valid_general(breaks_init, T0, T_end, min_segment_length,
                                break_windows = break_windows)) {
    stop("breaks_init is not a valid break configuration (check break_windows if supplied).")
  }
  
  breaks_current <- as.integer(breaks_init)
  gammas_current <- as.character(gammas_init)
  
  masks_current <- make_segment_masks_from_breaks(
    t_index = full_design$t_index,
    breaks = breaks_current
  )
  
  regime_ll <- numeric(n_regimes)
  for (s in seq_len(n_regimes)) {
    regime_ll[s] <- regime_logmarg_live(
      full_design = full_design,
      mask = masks_current[[s]],
      gamma_label_regime = gammas_current[s],
      prior_info = prior_info
    )
  }
  total_ll <- sum(regime_ll)
  
  breaks_mat <- matrix(NA_integer_, nrow = n_iter, ncol = m)
  colnames(breaks_mat) <- paste0("tau", seq_len(m))
  
  gammas_mat <- matrix(NA_character_, nrow = n_iter, ncol = n_regimes)
  colnames(gammas_mat) <- paste0("gamma", seq_len(n_regimes))
  
  move_vec <- character(n_iter)
  logpost_vec <- numeric(n_iter)
  accepted_vec <- logical(n_iter)
  
  for (iter in seq_len(n_iter)) {
    
    accepted <- FALSE
    
    if (iter %% 2 == 1) {
      
      move <- "break"
      
      prop <- propose_break_local_general(
        breaks_current = breaks_current,
        T0 = T0,
        T_end = T_end,
        min_segment_length = min_segment_length,
        break_windows = break_windows
      )
      
      if (prop$valid) {
        
        masks_prop <- make_segment_masks_from_breaks(
          t_index = full_design$t_index,
          breaks = prop$breaks_new
        )
        
        touched <- unique(c(prop$k, prop$k + 1L))
        
        regime_ll_prop <- regime_ll
        for (s in touched) {
          regime_ll_prop[s] <- regime_logmarg_live(
            full_design = full_design,
            mask = masks_prop[[s]],
            gamma_label_regime = gammas_current[s],
            prior_info = prior_info
          )
        }
        
        total_prop <- total_ll - sum(regime_ll[touched]) + sum(regime_ll_prop[touched])
        
        log_alpha <- total_prop - total_ll
        
        if (log(runif(1)) < log_alpha) {
          breaks_current <- prop$breaks_new
          masks_current <- masks_prop
          regime_ll <- regime_ll_prop
          total_ll <- total_prop
          accepted <- TRUE
        }
      }
      
    } else {
      
      move <- "gamma"
      
      prop <- propose_gamma_flip_general(
        gammas_current = gammas_current,
        pmax = prior_info$pmax
      )
      
      s <- prop$regime
      
      new_ll_s <- regime_logmarg_live(
        full_design = full_design,
        mask = masks_current[[s]],
        gamma_label_regime = prop$gammas_new[s],
        prior_info = prior_info
      )
      
      total_prop <- total_ll - regime_ll[s] + new_ll_s
      
      log_alpha <- total_prop - total_ll
      
      if (log(runif(1)) < log_alpha) {
        gammas_current <- prop$gammas_new
        regime_ll[s] <- new_ll_s
        total_ll <- total_prop
        accepted <- TRUE
      }
    }
    
    breaks_mat[iter, ] <- breaks_current
    gammas_mat[iter, ] <- gammas_current
    move_vec[iter] <- move
    logpost_vec[iter] <- total_ll
    accepted_vec[iter] <- accepted
    
    if (verbose && iter %% 2000 == 0) {
      cat("Iteration", iter,
          "| breaks =", paste(breaks_current, collapse = ","),
          "| gammas =", paste(gammas_current, collapse = ","),
          "| logpost =", round(total_ll, 2), "\n")
    }
  }
  
  list(
    breaks_draws = breaks_mat,
    gammas_draws = gammas_mat,
    move = move_vec,
    logpost = logpost_vec,
    accepted = accepted_vec,
    acceptance = c(
      total = mean(accepted_vec),
      break_move = mean(accepted_vec[move_vec == "break"]),
      gamma_move = mean(accepted_vec[move_vec == "gamma"])
    ),
    init = list(breaks = breaks_init, gammas = gammas_init),
    m = m
  )
}


# Original BVAR_thesis_full_code.R lines 1862-1889 (verbatim)
plot_general_mcmc_posteriors <- function(break_summary_tab, T0,
                                         true_breaks_est = NULL) {
  
  m <- length(break_summary_tab)
  op <- par(no.readonly = TRUE)
  par(mfrow = c(m, 1), mar = c(4, 5, 2, 2))
  
  for (k in seq_len(m)) {
    tab <- break_summary_tab[[k]]
    plot(
      tab$tau - T0,
      tab$postprob,
      type = "h",
      lwd = 2,
      xlab = bquote(tau[.(k)]),
      ylab = "Posterior probability",
      main = paste0("MCMC posterior of break ", k)
    )
    if (!is.null(true_breaks_est)) {
      abline(v = true_breaks_est[k], lty = 2, lwd = 2, col = "red")
    }
    if (k == 1) {
      legend("topleft", legend = "true break", lty = 2, lwd = 2, col = "red", bty = "n", cex = 0.85)
    }
  }
  
  par(op)
}


# Original BVAR_thesis_full_code.R lines 1892-2059 (verbatim)
run_multiple_chains_general_live_dispersed <- function(seeds,
                                                       breaks_init_list,
                                                       gammas_init_list,
                                                       full_design,
                                                       prior_info,
                                                       T0,
                                                       T_end,
                                                       min_segment_length,
                                                       burnin,
                                                       thin,
                                                       n_iter,
                                                       true_breaks_est = NULL,
                                                       true_gamma_labels = NULL,
                                                       break_windows = NULL) {
  
  if (length(seeds) != length(breaks_init_list)) {
    stop("seeds and breaks_init_list must have the same length.")
  }
  if (length(seeds) != length(gammas_init_list)) {
    stop("seeds and gammas_init_list must have the same length.")
  }
  
  m <- length(breaks_init_list[[1]])
  n_regimes <- m + 1L
  
  chains <- vector("list", length(seeds))
  rows <- vector("list", length(seeds))
  
  for (i in seq_along(seeds)) {
    cat("Running dispersed live-MCMC chain", i,
        "| seed =", seeds[i],
        "| init breaks =", paste(breaks_init_list[[i]], collapse = ","), "\n")
    
    mcmc_i <- run_mcmc_general_live(
      full_design = full_design,
      prior_info = prior_info,
      breaks_init = breaks_init_list[[i]],
      gammas_init = gammas_init_list[[i]],
      T0 = T0,
      T_end = T_end,
      min_segment_length = min_segment_length,
      n_iter = n_iter,
      seed = seeds[i],
      verbose = FALSE,
      break_windows = break_windows
    )

    keep <- seq_len(n_iter) > burnin
    
    keep_thin <- keep
    if (!is.null(thin) && thin > 1) {
      keep_thin <- keep_thin & ((seq_len(n_iter) - burnin) %% thin == 0)
    }
    
    chains[[i]] <- list(
      mcmc_out = mcmc_i,
      breaks_draws = mcmc_i$breaks_draws[keep, , drop = FALSE],
      gammas_draws = mcmc_i$gammas_draws[keep, , drop = FALSE],
      breaks_draws_thin = mcmc_i$breaks_draws[keep_thin, , drop = FALSE],
      gammas_draws_thin = mcmc_i$gammas_draws[keep_thin, , drop = FALSE],
      init_breaks = breaks_init_list[[i]],
      init_gammas = gammas_init_list[[i]]
    )
    
    row_i <- data.frame(
      chain = i,
      seed = seeds[i],
      init_breaks = paste(breaks_init_list[[i]], collapse = ","),
      acceptance_total = mcmc_i$acceptance["total"],
      acceptance_break = mcmc_i$acceptance["break_move"],
      acceptance_gamma = mcmc_i$acceptance["gamma_move"],
      stringsAsFactors = FALSE
    )
    for (k in seq_len(m)) {
      row_i[[paste0("mean_tau", k)]] <- mean(chains[[i]]$breaks_draws[, k])
    }
    rows[[i]] <- row_i
  }
  
  chain_summary <- do.call(rbind, rows)
  rownames(chain_summary) <- NULL
  
  all_breaks <- do.call(rbind, lapply(chains, function(z) z$breaks_draws))
  all_gammas <- do.call(rbind, lapply(chains, function(z) z$gammas_draws))
  
  conv_diag <- compute_convergence_diagnostics_general(chains, m)
  rhat_per_break <- conv_diag$Rhat
  ess_bulk_per_break <- conv_diag$ESS_bulk
  ess_tail_per_break <- conv_diag$ESS_tail
  
  gamma_diag <- compute_gamma_diagnostics_general(chains, n_regimes, prior_info$pmax)
  
  break_summary_tab <- lapply(seq_len(m), function(k) {
    tab <- as.data.frame(table(all_breaks[, k]), stringsAsFactors = FALSE)
    names(tab) <- c("tau", "freq")
    tab$tau <- as.integer(tab$tau)
    tab$postprob <- tab$freq / sum(tab$freq)
    tab <- tab[order(tab$postprob, decreasing = TRUE), ]
    rownames(tab) <- NULL
    tab
  })
  names(break_summary_tab) <- paste0("tau", seq_len(m))
  
  gamma_summary_tab <- lapply(seq_len(n_regimes), function(s) {
    tab <- as.data.frame(table(all_gammas[, s]), stringsAsFactors = FALSE)
    names(tab) <- c("gamma", "freq")
    tab$postprob <- tab$freq / sum(tab$freq)
    tab <- tab[order(tab$postprob, decreasing = TRUE), ]
    rownames(tab) <- NULL
    tab
  })
  names(gamma_summary_tab) <- paste0("regime", seq_len(n_regimes))

  per_chain_break_means <- do.call(rbind, lapply(seq_along(chains), function(i) {
    data.frame(
      chain = i,
      break_index = seq_len(m),
      init_value = breaks_init_list[[i]],
      posterior_mean = as.numeric(colMeans(chains[[i]]$breaks_draws))
    )
  }))
  rownames(per_chain_break_means) <- NULL
  
  validation <- NULL
  if (!is.null(true_breaks_est) && !is.null(true_gamma_labels)) {
    rows_val <- lapply(seq_len(m), function(k) {
      data.frame(
        break_index = k,
        true_tau_est = true_breaks_est[k],
        posterior_mean_tau_est = mean(all_breaks[, k]) - T0,
        posterior_mode_tau_est = break_summary_tab[[k]]$tau[1] - T0,
        mass_within_pm5 = mean(abs(all_breaks[, k] - true_breaks_est[k] - T0) <= 5)
      )
    })
    tau_validation <- do.call(rbind, rows_val)
    
    gamma_validation <- data.frame(
      regime = seq_len(n_regimes),
      true_gamma = true_gamma_labels,
      posterior_mode_gamma = sapply(gamma_summary_tab, function(z) z$gamma[1]),
      mass_true_gamma = sapply(seq_len(n_regimes), function(s) {
        mean(all_gammas[, s] == true_gamma_labels[s])
      })
    )
    
    validation <- list(tau_validation = tau_validation,
                       gamma_validation = gamma_validation)
  }
  
  list(
    chains = chains,
    chain_summary = chain_summary,
    per_chain_break_means = per_chain_break_means,
    all_breaks = all_breaks,
    all_gammas = all_gammas,
    Rhat_breaks = rhat_per_break,
    ESS_bulk_breaks = ess_bulk_per_break,
    ESS_tail_breaks = ess_tail_per_break,
    gamma_PIP = gamma_diag$PIP,
    gamma_Rhat = gamma_diag$Rhat,
    gamma_ESS_bulk = gamma_diag$ESS_bulk,
    gamma_ESS_tail = gamma_diag$ESS_tail,
    gamma_min_transitions = gamma_diag$MinTransitions,
    break_summary_tab = break_summary_tab,
    gamma_summary_tab = gamma_summary_tab,
    validation = validation
  )
}


# Original BVAR_thesis_full_code.R lines 3274-3281 (verbatim)
add_break_ci95 <- function(tau_validation, all_breaks, T0, prob = c(0.025, 0.975)) {
  m <- nrow(tau_validation)
  ci <- t(sapply(seq_len(m), function(k) quantile(all_breaks[, k] - T0, probs = prob, names = FALSE)))
  tau_validation$ci95_lower_est <- ci[, 1]
  tau_validation$ci95_upper_est <- ci[, 2]
  tau_validation[, c("break_index", "true_tau_est", "posterior_mean_tau_est",
                     "posterior_mode_tau_est", "ci95_lower_est", "ci95_upper_est", "mass_within_pm5")]
}


# Original BVAR_thesis_full_code.R lines 3298-3336 (verbatim)
plot_multichain_trace_breaks <- function(chains, m, T0, true_breaks_est = NULL, use_thinned = TRUE,
                                         max_points = 3000) {
  op <- par(no.readonly = TRUE)
  n_chains <- length(chains)
  chain_palette <- c("black", "#D55E00", "#0072B2", "#009E73", "#CC79A7", "#E69F00")
  chain_cols <- rep_len(chain_palette, n_chains)
  chain_cols_alpha <- vapply(chain_cols, adjustcolor, character(1), alpha.f = 0.55)
  chain_ltys <- rep_len(1:6, n_chains)
  
  par(mfrow = c(m, 1), mar = c(4, 5, 2, 2), oma = c(0, 0, 1.5, 0))
  
  for (k in seq_len(m)) {
    draws_list <- lapply(chains, function(z) (if (use_thinned) z$breaks_draws_thin else z$breaks_draws)[, k] - T0)
    n_draws <- length(draws_list[[1]])
    stride <- max(1, ceiling(n_draws / max_points))
    idx <- seq(1, n_draws, by = stride)
    
    y_range <- range(unlist(draws_list))
    y_top <- y_range[2] + diff(y_range) * 0.22
    plot(idx, draws_list[[1]][idx], type = "l", col = chain_cols_alpha[1], lty = chain_ltys[1],
         ylim = c(y_range[1], y_top), xlim = c(1, n_draws),
         xlab = "Iteration (post-burnin, thinned)", ylab = bquote(tau[.(k)]),
         main = paste0("Multi-chain traceplot (dispersed-start, m=3): break ", k))
    for (i in seq_along(draws_list)[-1]) {
      lines(idx, draws_list[[i]][idx], col = chain_cols_alpha[i], lty = chain_ltys[i])
    }
    if (!is.null(true_breaks_est)) abline(h = true_breaks_est[k], lty = 2, lwd = 2, col = "gray40")
    if (k == 1) {
      legend("topright", legend = paste0("chain ", seq_len(n_chains)),
             col = chain_cols, lty = chain_ltys, lwd = 2, bty = "n", cex = 0.85,
             horiz = TRUE, seg.len = 1.5)
    }
  }
  
  mtext("Gray dashed line: true break value used in the simulation",
        side = 3, outer = TRUE, line = 0.2, font = 3, cex = 0.8)
  
  par(op)
}
