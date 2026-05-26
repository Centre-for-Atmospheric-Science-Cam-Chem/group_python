#!/bin/bash

# This script reads in configuration from yaml file and sends information to 
# batch download pp and conversion.
# This script depends on other sources in this repository

# USER EDIT
yaml_file='./config.yaml'
proj_dir='../../../'

# set project paths. This script depends on other code in src/data and src/util in this repo
export SRC_DATA_DIR="${proj_dir}/src/data"
export UTIL_DIR="${proj_dir}/src/util"
export PATH="$UTIL_DIR:$SRC_DATA_DIR:$PATH"

# Set tmpdir to log, in case this is not set
if [[ -z $TMPDIR ]]; then
    TMPDIR='./log/'
fi

tmp_env=$(mktemp -p "$TMPDIR" env_XXXXXX.sh)

# Load variables from yaml file
python3 "${UTIL_DIR}/yaml_to_shell.py" $yaml_file > "$tmp_env"

# shellcheck disable=SC1090
source "$tmp_env"

# Validate processing_queue file
if [[ ! -f "$PATH_PROCESSING_QUEUE" ]]; then
    echo "ERROR: Processing queue file not found: $PATH_PROCESSING_QUEUE"
    exit 1
fi

# Check that processing_queue has valid format and entries
num_lines=$(wc -l < "$PATH_PROCESSING_QUEUE")
max_array=$(echo "$JOBS_ARRAY_RANGE" | awk -F'[-,]' '{print $NF}')

if [[ $num_lines -lt $max_array ]]; then
    echo "ERROR: Processing queue has $num_lines lines but array_range requests up to $max_array"
    echo "       Update JOBS_ARRAY_RANGE in config.yaml to match processing_queue.csv"
    exit 1
fi

echo "Processing queue validation: PASSED"
echo "  File: $PATH_PROCESSING_QUEUE"
echo "  Total lines: $num_lines"
echo "  Array range: $JOBS_ARRAY_RANGE"
echo ""

# This submit N jobs, where N=number of each array job set 
# by JOBS_ARRAY_RANGE in config.yaml

if [[ "$JOB_L_BATCH" = "True" ]]; then

    sbatch \
        --job-name="$JOB_NAME" \
        --partition="$SLURM_PARTITION" \
        --account="$SLURM_ACCOUNT" \
        --qos="$SLURM_QOS" \
        --time="$SLURM_TIME" \
        --mem="$SLURM_MEMORY" \
        --array="$JOBS_ARRAY_RANGE" \
		--output="log/driver_%j.out" \
		--error="log/driver_%j.err" \
        batch_process.sh

	echo "Execute command 'squeue --me' to monitor all the submitted job."
	
else
	echo "interactive shell session for extraction from MASS only"
	max_jobs=6
	
	sh submit_to_mass-cli.sh "$max_jobs" "$JOBS_ARRAY_RANGE"
fi
