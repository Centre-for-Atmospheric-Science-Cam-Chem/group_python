#!/bin/bash

# Deletes old run directories inside all suite directories except for the two most recent runs.
# An alternative to the cylc clean command for when doing lots of test runs. 
# You may need to change your cylc-run directory in the script.

# Directories to search.
cylc_dirs=(
  "/home/users/$USER/cylc-run"
  "/data/scratch/$USER/cylc-run"
  "/data/users/$USER/cylc-run"
)

for cylc_dir in "${cylc_dirs[@]}"; do

  # Loop through subdirectories starting with 'u-'.
  for suite_dir in "$cylc_dir"/u-*; do

    # Find directories named run[n].
    run_dirs=($(find "$suite_dir" -maxdepth 1 -type d -regex '.*/run[0-9]+' -printf '%f\n' | sort -V))

    # Skip if there are fewer than 3 numbered runs.
    if (( ${#run_dirs[@]} <= 2 )); then
      continue
    fi

    # Keep only the two largest numbers.
    keep=("${run_dirs[@]: -2}")

    # Loop through all runs and delete the unwanted ones.
    for run_dir in "${run_dirs[@]}"; do
      if [[ ! " ${keep[*]} " =~ " $run_dir " ]]; then
        if [[ -d "$suite_dir/$run_dir" ]]; then
          echo "  Deleting: $suite_dir/$run_dir"
          rm -rf "$suite_dir/$run_dir"
        fi
      fi
    done
    
  done
done
