#!/usr/bin/env bash

set -euo pipefail

# This script reads in configuration from yaml file and sends information to 
# batch download pp and conversion.
# This script depends on other sources in this repository

# Paths are based on this script, not on the caller's current directory.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/../../.." && pwd -P)"
WORKFLOW_DIR="$SCRIPT_DIR"
LOG_DIR="$WORKFLOW_DIR/log"
CONFIG_FILE="${1:-$WORKFLOW_DIR/config.yaml}"

export SRC_DATA_DIR="$REPO_DIR/src/data"
export UTIL_DIR="$REPO_DIR/src/util"
export WORKFLOW_DIR
export LOG_DIR
# export PATH="$UTIL_DIR:$SRC_DATA_DIR:$PATH"

mkdir -p "$LOG_DIR"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE" >&2
    exit 1
fi

# Create tmp environment and delete upon script exiting 
# whether it succeeds, fails, or exits early. 
tmp_env=$(mktemp "$LOG_DIR/env_XXXXXX.sh")
cleanup() {
    rm -f -- "$tmp_env"
}
trap cleanup EXIT

# Load variables from yaml file
python3 "$UTIL_DIR/yaml_to_shell.py" "$CONFIG_FILE" > "$tmp_env"

# shellcheck disable=SC1090
source "$tmp_env"

resolve_workflow_path() {
    local configured_path="$1"

    if [[ "$configured_path" = /* ]]; then
        printf '%s\n' "$configured_path"
    else
        printf '%s/%s\n' "$WORKFLOW_DIR" "$configured_path"
    fi
}

# Check for processing queue
PATH_PROCESSING_QUEUE="$(resolve_workflow_path "$PATH_PROCESSING_QUEUE")"
export PATH_PROCESSING_QUEUE

if [[ ! -f "$PATH_PROCESSING_QUEUE" ]]; then
    echo "ERROR: Processing queue file not found: $PATH_PROCESSING_QUEUE" >&2
    exit 1
fi

# Optional query options file; unset or "" means no extra query
EXTRACT_QUERY_OPTIONS="${EXTRACT_QUERY_OPTIONS:-}"

if [[ -n "$EXTRACT_QUERY_OPTIONS" ]]; then
    EXTRACT_QUERY_OPTIONS="$(resolve_workflow_path "$EXTRACT_QUERY_OPTIONS")"

    if [[ ! -f "$EXTRACT_QUERY_OPTIONS" ]]; then
        echo "ERROR: Query options file not found: $EXTRACT_QUERY_OPTIONS" >&2
        exit 1
    fi
fi
export EXTRACT_QUERY_OPTIONS

# Check for sbatch
if ! command -v sbatch >/dev/null 2>&1 && [[ "${JOB_L_BATCH:-False}" = "True" ]]; then
    echo "ERROR: sbatch is required when job.l_batch is True" >&2
    exit 1
fi

# Validate the queue structure and every requested array task.
if [[ ! -s "$PATH_PROCESSING_QUEUE" ]]; then
    echo "ERROR: Processing queue is empty: $PATH_PROCESSING_QUEUE" >&2
    exit 1
fi

IFS=, read -r header_task header_job header_stream header_stash _header_label < "$PATH_PROCESSING_QUEUE"
header_stash="${header_stash%$'\r'}"
if [[ "$header_task" != "task_id" || "$header_job" != "job_id" || \
      "$header_stream" != "stream" || "$header_stash" != "stashID" ]]; then
    echo "ERROR: Invalid processing queue header in $PATH_PROCESSING_QUEUE" >&2
    echo "       Expected: task_id,job_id,stream,stashID[,label]" >&2
    exit 1
fi

declare -A queue_task_ids=()
queue_data_lines=0
queue_line_number=1
while IFS=, read -r queue_task queue_job queue_stream queue_stash _queue_label; do
    queue_line_number=$((queue_line_number + 1))
    queue_task="${queue_task%$'\r'}"
    queue_job="${queue_job%$'\r'}"
    queue_stream="${queue_stream%$'\r'}"
    queue_stash="${queue_stash%$'\r'}"

    if [[ -z "$queue_task$queue_job$queue_stream$queue_stash" ]]; then
        echo "ERROR: Blank processing queue row at line $queue_line_number" >&2
        exit 1
    fi
    if ! [[ "$queue_task" =~ ^[1-9][0-9]*$ ]]; then
        echo "ERROR: Invalid task ID '$queue_task' at queue line $queue_line_number" >&2
        exit 1
    fi
    if [[ -z "$queue_job" || -z "$queue_stream" || -z "$queue_stash" ]]; then
        echo "ERROR: Missing required queue field at line $queue_line_number" >&2
        exit 1
    fi
    if ! [[ "$queue_stash" =~ ^[0-9]+$ ]]; then
        echo "ERROR: Invalid stash '$queue_stash' at queue line $queue_line_number" >&2
        exit 1
    fi
    if [[ -v "queue_task_ids[$queue_task]" ]]; then
        echo "ERROR: Duplicate task ID '$queue_task' in processing queue" >&2
        exit 1
    fi

    queue_task_ids["$queue_task"]=1
    queue_data_lines=$((queue_data_lines + 1))
done < <(tail -n +2 "$PATH_PROCESSING_QUEUE")

declare -A requested_task_ids=()
IFS=, read -r -a array_entries <<< "$JOBS_ARRAY_RANGE"
if [[ "${#array_entries[@]}" -eq 0 ]]; then
    echo "ERROR: Invalid jobs.array_range: $JOBS_ARRAY_RANGE" >&2
    exit 1
fi

for array_entry in "${array_entries[@]}"; do
    if [[ "$array_entry" =~ ^([1-9][0-9]*)-([1-9][0-9]*)$ ]]; then
        range_start=${BASH_REMATCH[1]}
        range_end=${BASH_REMATCH[2]}
        if (( range_start > range_end )); then
            echo "ERROR: Invalid jobs.array_range: $JOBS_ARRAY_RANGE" >&2
            exit 1
        fi
        for ((task_id = range_start; task_id <= range_end; task_id++)); do
            requested_task_ids["$task_id"]=1
        done
    elif [[ "$array_entry" =~ ^[1-9][0-9]*$ ]]; then
        requested_task_ids["$array_entry"]=1
    else
        echo "ERROR: Invalid jobs.array_range: $JOBS_ARRAY_RANGE" >&2
        exit 1
    fi
done

for task_id in "${!requested_task_ids[@]}"; do
    if [[ ! -v "queue_task_ids[$task_id]" ]]; then
        echo "ERROR: No processing queue row for array task $task_id" >&2
        exit 1
    fi
done

requested_task_count=${#requested_task_ids[@]}

echo "Processing queue validation: PASSED"
echo "  Workflow: $WORKFLOW_DIR"
echo "  Config: $CONFIG_FILE"
echo "  Data scripts: $SRC_DATA_DIR"
echo "  Queue file: $PATH_PROCESSING_QUEUE"
echo "  Total rows in queue: $queue_data_lines"
echo "  Requested rows: $JOBS_ARRAY_RANGE"
echo "  Total requested tasks: $requested_task_count"
echo ""

# check if EXTRACT_DRY_RUN is set. If set, just exit as not actually running anything. 
if [[ "${EXTRACT_DRY_RUN:-False}" = "True" ]]; then
    echo "Dry run requested; no jobs submitted."
    exit 0
fi

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
        --chdir="$WORKFLOW_DIR" \
        --output="$LOG_DIR/driver_%j.out" \
        --error="$LOG_DIR/driver_%j.err" \
        "$SRC_DATA_DIR/batch_process.sh"

	echo ""
	echo "Execute command 'squeue --me' to monitor all the submitted job."
	echo ""
	
else
	echo "interactive shell session for extraction from MASS only"
	max_jobs=6
	
    bash "$WORKFLOW_DIR/submit_to_mass-cli.sh" "$max_jobs" "$JOBS_ARRAY_RANGE"
fi
