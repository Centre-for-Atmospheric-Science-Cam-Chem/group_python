# An alternative to the cylc suite clean command, which deletes all run data from each suite's cylc-run history except for the last 2 runs. Useful when doing lots of test runs. 
# You may need to change your cylc-run directory in the script.

#!/usr/bin/env bash
set -euo pipefail

# Loop over every subdirectory starting with 'u-'
for dir in /home/users/$USER/cylc-run/u-*/; do
    echo "$dir"
    cd "$dir" || continue

    # Find directories matching run[0-9]+ and sort them numerically by their suffix
    run_dirs=($(find . -maxdepth 1 -type d -regex './run[0-9]+' | sed 's|^\./||' | sort -t n -k1.4n))

    # Find if 'runN' exists
    has_runN=false
    if [ -d "runN" ]; then
        has_runN=true
    fi

    # Only proceed if there are at least 3 numbered runs
    num_runs=${#run_dirs[@]}
    if (( num_runs > 2 )); then
        # Determine which two to keep (largest numeric suffix)
        keep_runs=($(printf "%s\n" "${run_dirs[@]}" | sort -t n -k1.4n | tail -n 2))

        echo "Keeping: ${keep_runs[*]}"
        $has_runN && echo "Also keeping: runN"

        # Delete all others except the ones we're keeping and runN
        for run in "${run_dirs[@]}"; do
            if [[ ! " ${keep_runs[*]} " =~ " ${run} " ]]; then
                if [[ "$run" != "runN" ]]; then
                    echo "Deleting $run"
                    rm -rf "$run"
                fi
            fi
        done
    else
        echo "Less than 3 run directories ? nothing to delete."
    fi

    cd ..
done
