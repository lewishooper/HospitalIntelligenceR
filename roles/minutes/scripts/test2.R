#run1 <- read.csv("roles/minutes/outputs/llm_run1_validation_results.csv")

# Run the classification loop again and save as run2
# (re-source Section 4 with RESULTS_FILE temporarily renamed)

run2 <- read.csv("roles/minutes/outputs/llm_run1_validation_results.csv")

# Compare classifications
comparison <- data.frame(
  seq_num  = run1$seq_num,
  fac      = run1$fac,
  run1_got = run1$got,
  run2_got = run2$got,
  match    = run1$got == run2$got
)

cat(sprintf("Identical classifications: %d / %d\n",
            sum(comparison$match), nrow(comparison)))
print(comparison |> filter(!match))

write.csv(results, 
          "roles/minutes/outputs/llm_run1_validation_results_rev1.csv", 
          row.names = FALSE)
