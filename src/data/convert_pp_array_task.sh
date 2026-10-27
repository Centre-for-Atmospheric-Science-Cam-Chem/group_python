#!/bin/bash

# Slurm array task wrapper: convert the pp file on line SLURM_ARRAY_TASK_ID
# (0-based) of the manifest. Each manifest line is "<pp_file_full>\t<converted_file_full>".

manifest=$1

if [[ -z "${SLURM_ARRAY_TASK_ID:-}" ]]; then
    echo "SLURM_ARRAY_TASK_ID is not set; run this as a Slurm array job." >&2
    exit 1
fi

IFS=$'\t' read -r pp_file_full converted_file_full < <(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" "$manifest")

if [[ -z "$pp_file_full" || -z "$converted_file_full" ]]; then
    echo "ERROR: No manifest entry for task $SLURM_ARRAY_TASK_ID in $manifest" >&2
    exit 1
fi

echo "Task $SLURM_ARRAY_TASK_ID: $pp_file_full -> $converted_file_full"
exec bash "$SRC_DATA_DIR/convert_single_pp.sh" "$pp_file_full" "$converted_file_full"
