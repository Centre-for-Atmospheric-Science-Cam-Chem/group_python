#!/bin/bash

################################################################################
# Batch STASH extraction from PP files using SLURM array jobs
################################################################################
#
# This script extracts STASH codes from PP files specified in processing_queue.csv
# It is designed to be submitted as a SLURM array job by driver_extract_nc_from_large_pp.sh
#
# Each array task processes one line from the processing_queue.csv file
#

#SBATCH --job-name=extract_stash
#SBATCH --account=acsis
#SBATCH --partition=standard
#SBATCH --qos=short
#SBATCH -o %j.out
#SBATCH -e %j.err
#SBATCH --time=2:00:00
#SBATCH --mem=32000

# Load configuration (yaml_file and proj_dir are exported from driver script)
# yaml_file='./config.yaml'  # Set by driver_extract_nc_from_large_pp.sh
# proj_dir='../../git/group_python/'  # Set by driver_extract_nc_from_large_pp.sh

# set project paths
export SRC_DATA_DIR="${proj_dir}/src/data"
export UTIL_DIR="${proj_dir}/src/util"
export PATH="$UTIL_DIR:$SRC_DATA_DIR:$PATH"

# Set tmpdir if not set
if [[ -z $TMPDIR ]]; then
    TMPDIR='./log/'
fi

# Load environment variables from yaml file
tmp_env=$(mktemp -p "$TMPDIR" env_XXXXXX.sh)
python3 "$PATHS_YAML_TO_SHELL" $yaml_file > "$tmp_env"
source "$tmp_env"

# Load python environment
eval "$PYTHON_MODULE_LOAD"

### MAIN EXECUTION ##################################################################

# Get the PP file path from processing_queue.csv using SLURM_ARRAY_TASK_ID
processing_queue="$PATHS_PROCESSING_QUEUE"

# Extract the PP file path for the current $SLURM_ARRAY_TASK_ID
pp_file=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$processing_queue" | cut -d',' -f2 | tr -d '\r')

# Verify we got a valid PP file path
if [[ -z "$pp_file" ]]; then
    echo "ERROR: Could not extract PP file path from line $SLURM_ARRAY_TASK_ID in $processing_queue"
    exit 1
fi

if [[ ! -f "$pp_file" ]]; then
    echo "ERROR: PP file not found: $pp_file"
    exit 1
fi

# Get the basename of the PP file for output naming
pp_basename=$(basename "$pp_file" .pp)

echo "=========================================="
echo "STASH Extraction Task: $SLURM_ARRAY_TASK_ID"
echo "=========================================="
echo "PP file: $pp_file"
echo "Basename: $pp_basename"
echo ""

# Define output file for STASH check results
output_check_file="${pp_basename}_stash_check.txt"

echo "Output file: $output_check_file"
echo ""

# Execute the STASH extraction script
python3 "$PATHS_PYTHON_SCRIPT" \
    "$pp_file" \
    "$output_check_file" \
    --subset-stash "$PATHS_STASH_LIST" \
    --extract-stash \
    --nc-dir "$PATHS_OUTPUT_NC"

# Capture exit code
exit_code=$?

if [[ $exit_code -eq 0 ]]; then
    echo ""
    echo "=========================================="
    echo "Extraction completed successfully"
    echo "=========================================="
else
    echo ""
    echo "=========================================="
    echo "ERROR: Extraction failed with exit code $exit_code"
    echo "=========================================="
fi

# Clean up temporary environment file
rm -f "$tmp_env"

exit $exit_code
