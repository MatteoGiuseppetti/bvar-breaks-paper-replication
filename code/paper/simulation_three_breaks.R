# PAPER ONLY — three-break simulation, final dispersed-start run.
# No preliminary 15000-iteration run and no m=0/1/2 simulation.

# Original BVAR_thesis_full_code.R lines 2986-3077 (verbatim)
set.seed(2026)

n_3b <- 2
pmax_3b <- 3

zeroA_3b <- matrix(0, n_3b, n_3b)

A_lag1_3b <- matrix(c(0.45,  0.10,
                      -0.05,  0.35), nrow = n_3b, byrow = TRUE)
A_lag2_3b <- matrix(c(-0.35, 0.15,
                      0.10, 0.25), nrow = n_3b, byrow = TRUE)
A_lag3_3b <- matrix(c(0.18,  0.00,
                      0.08, -0.15), nrow = n_3b, byrow = TRUE)

c_list_3b <- list(
  c(0.00,  0.00),
  c(0.20, -0.10),
  c(-0.15, 0.15),
  c(0.10,  0.10)
)

A_list_3b <- list(
  list(A_lag1_3b, zeroA_3b, zeroA_3b),   # regime 1: gamma = 100
  list(zeroA_3b, A_lag2_3b, zeroA_3b),   # regime 2: gamma = 010
  list(zeroA_3b, zeroA_3b, A_lag3_3b),   # regime 3: gamma = 001
  list(A_lag1_3b, A_lag2_3b, zeroA_3b)   # regime 4: gamma = 110
)

Sigma_list_3b <- list(
  matrix(c(1.00,  0.30, 0.30,  1.00), nrow = n_3b, byrow = TRUE),
  matrix(c(0.70, -0.20, -0.20,  1.20), nrow = n_3b, byrow = TRUE),
  matrix(c(1.10,  0.15, 0.15,  0.80), nrow = n_3b, byrow = TRUE),
  matrix(c(0.90,  0.00, 0.00,  0.90), nrow = n_3b, byrow = TRUE)
)

true_gamma1_3b <- c(1L, 0L, 0L)
true_gamma2_3b <- c(0L, 1L, 0L)
true_gamma3_3b <- c(0L, 0L, 1L)
true_gamma4_3b <- c(1L, 1L, 0L)

true_gamma_labels_3b <- c(
  gamma_label(true_gamma1_3b),
  gamma_label(true_gamma2_3b),
  gamma_label(true_gamma3_3b),
  gamma_label(true_gamma4_3b)
)

rho_3b <- sapply(seq_along(A_list_3b), function(s) {
  companion_radius(A_list_3b[[s]], n_3b)
})
cat("Spectral radii of the four regimes:\n")
print(round(rho_3b, 4))
cat("All stable:", if (all(rho_3b < 1)) "YES" else "NO", "\n\n")

T0_len_3b <- 200
T_est_3b <- 3200
T_sim_3b <- T0_len_3b + T_est_3b

breaks_est_true_3b <- c(800, 1600, 2400)
breaks_abs_true_3b <- T0_len_3b + breaks_est_true_3b

y_3b <- simulate_bvar_breaks(
  T = T_sim_3b,
  breaks = breaks_abs_true_3b,
  pmax = pmax_3b,
  c_list = c_list_3b,
  A_list = A_list_3b,
  Sigma_list = Sigma_list_3b,
  burnin = 300
)

train_y_3b <- y_3b[1:T0_len_3b, , drop = FALSE]
y_full_3b <- y_3b

gamma_grid_3b <- make_gamma_grid(pmax_3b)

prior_info_3b <- make_prior_info(
  train_y = train_y_3b,
  pmax = pmax_3b,
  lambda_const = 10,
  lambda_lag = 0.40,
  lambda_decay = 1,
  own_lag_mean = 0,
  nu0_extra = 2
)

full_design_3b <- build_full_design(y_full_3b, pmax_3b, T0 = T0_len_3b)

cat("Data dimension:", dim(y_full_3b), "\n")
cat("True absolute breaks:", breaks_abs_true_3b, "\n")
cat("True breaks in the estimation sample:", breaks_est_true_3b, "\n")
cat("True gammas:", paste(true_gamma_labels_3b, collapse = ", "), "\n\n")


# Original BVAR_thesis_full_code.R lines 3081-3081 (verbatim)
min_segment_length_3b <- 200


# Original BVAR_thesis_full_code.R lines 3178-3245 (verbatim)
breaks_init_list_3b <- list(
  c(650, 1500, 2550),
  c(850, 1700, 2700),
  c(500, 1300, 2300),
  c(1000, 1900, 2900)
)

gammas_init_list_3b <- list(
  rep("111", 4),
  rep("000", 4),
  c("101", "010", "110", "001"),
  c("011", "101", "001", "111")
)

seeds_disp_3b <- c(1001, 1002, 1003, 1004)

n_iter_disp_3b <- 150000
burnin_disp_3b <- 25000
thin_disp_3b <- 5

multi_mcmc_3b_disp <- run_multiple_chains_general_live_dispersed(
  seeds = seeds_disp_3b,
  breaks_init_list = breaks_init_list_3b,
  gammas_init_list = gammas_init_list_3b,
  full_design = full_design_3b,
  prior_info = prior_info_3b,
  T0 = T0_len_3b,
  T_end = T_sim_3b,
  min_segment_length = min_segment_length_3b,
  burnin = burnin_disp_3b,
  thin = thin_disp_3b,
  n_iter = n_iter_disp_3b,
  true_breaks_est = breaks_est_true_3b,
  true_gamma_labels = true_gamma_labels_3b
)

cat("Per-chain summary:\n")
print(multi_mcmc_3b_disp$chain_summary)
cat("\n")

cat("Per-chain posterior mean by starting point:\n")
print(multi_mcmc_3b_disp$per_chain_break_means)
cat("\n")

cat("R-hat per break:\n")
print(multi_mcmc_3b_disp$Rhat_breaks)
cat("\n")

cat("Bulk-ESS per break:\n")
print(multi_mcmc_3b_disp$ESS_bulk_breaks)
cat("\nTail-ESS per break:\n")
print(multi_mcmc_3b_disp$ESS_tail_breaks)

cat("\nLag posterior inclusion probabilities (PIP), m = 3 dispersed-start:\n")
print(round(multi_mcmc_3b_disp$gamma_PIP, 3))
cat("\nR-hat per lag indicator, m = 3 dispersed-start:\n")
print(round(multi_mcmc_3b_disp$gamma_Rhat, 3))
cat("\nBulk-ESS per lag indicator, m = 3 dispersed-start:\n")
print(round(multi_mcmc_3b_disp$gamma_ESS_bulk, 1))
cat("\nTail-ESS per lag indicator, m = 3 dispersed-start\n")
print(round(multi_mcmc_3b_disp$gamma_ESS_tail, 1))
cat("\nMinimum transitions per lag indicator across chains, m = 3 dispersed-start\n")
print(multi_mcmc_3b_disp$gamma_min_transitions)
cat("Break recovery vs the true simulated DGP:\n")
print(multi_mcmc_3b_disp$validation$tau_validation)

cat("Lag-model (gamma) recovery vs the true simulated DGP:\n")
print(multi_mcmc_3b_disp$validation$gamma_validation)


# Original BVAR_thesis_full_code.R lines 3293-3295 (verbatim)
cat("m=3 final dispersed-start run (150000 iter): true value, posterior mean/mode, 95% CI:\n")
print(add_break_ci95(multi_mcmc_3b_disp$validation$tau_validation,
                     multi_mcmc_3b_disp$all_breaks, T0_len_3b))

# Output-only additions: archive posterior draws and plot the original figures into files.
saveRDS(list(
  truth = list(breaks_est = breaks_est_true_3b, gammas = true_gamma_labels_3b),
  seed_dgp = 2026L,
  seeds_chains = seeds_disp_3b,
  burnin = burnin_disp_3b,
  iterations = n_iter_disp_3b,
  thin_for_plots_only = thin_disp_3b,
  fit = multi_mcmc_3b_disp
), "simulation_three_breaks_final.rds")

pdf("simulation_three_breaks_trace.pdf", width = 10, height = 10)
plot_multichain_trace_breaks(multi_mcmc_3b_disp$chains, m = 3, T0 = T0_len_3b,
                             true_breaks_est = breaks_est_true_3b, use_thinned = TRUE)
dev.off()

pdf("simulation_three_breaks_break_posteriors.pdf", width = 9, height = 10)
plot_general_mcmc_posteriors(
  break_summary_tab = multi_mcmc_3b_disp$break_summary_tab,
  T0 = T0_len_3b,
  true_breaks_est = breaks_est_true_3b
)
dev.off()
