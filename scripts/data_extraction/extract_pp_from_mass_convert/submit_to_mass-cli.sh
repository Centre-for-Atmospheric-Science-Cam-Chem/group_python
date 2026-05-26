#!/bin/bash

# submit_to_mass-cli.sh - Manages job submission with concurrency control
# Usage: submit_to_mass-cli.sh <max_jobs> <jobs_array_range>
# Example: submit_to_mass-cli.sh 6 "1-5,7"

MAX_JOBS=$1
JOBS_ARRAY_RANGE=$2

# Expand SLURM array range (e.g., "1-5,7" -> 1 2 3 4 5 7)
expand_array_range() {
    local range_str="$1"
    local result=()
    
    IFS=',' read -ra ranges <<< "$range_str"
    
    for range in "${ranges[@]}"; do
        if [[ "$range" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            local start="${BASH_REMATCH[1]}"
            local end="${BASH_REMATCH[2]}"
            for ((i=start; i<=end; i++)); do
                result+=("$i")
            done
        else
            result+=("$range")
        fi
    done
    
    echo "${result[@]}"
}

# Expand job IDs and submit with concurrency control
job_ids=$(expand_array_range "$JOBS_ARRAY_RANGE")
echo "$JOBS_ARRAY_RANGE"
echo $job_ids
for job_id in $job_ids; do
	echo $job_id
    # Wait if we've reached the job limit
    while [ "$(jobs -r | wc -l)" -ge "$MAX_JOBS" ]; do
        sleep 1
    done
    
    # Submit the job in background
    export JOBS_ARRAY_TASK_ID="$job_id"
    sh interactive_extract_process.sh > log/extract_log_"$job_id" &
done

# Wait for all jobs to complete
wait
echo "All jobs completed"
