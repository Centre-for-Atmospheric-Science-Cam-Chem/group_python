#!/bin/bash

jobID=$1
stream=$2
stash=$3
pp_dir=$4
converted_dir=$5
dependent_id=${6:-""}

# Maximum number of conversion tasks running at once (convert.max_parallel in config.yaml).
# Limits how many processes write into converted_dir simultaneously.
max_parallel=${CONVERT_MAX_PARALLEL:-10}

# Convert the pp files to netCDF format ---

echo "$jobID; $stream; $stash; conversion to NetCDF; started; $(date)"

# List pp files in the extract directory while preserving each filename.
mapfile -t pp_files < <(find "$pp_dir" -maxdepth 1 -type f ! -name "*.txt" ! -name "MetOffice*" -printf "%f\n")

# In batch mode, files are listed in a manifest and converted by one throttled job array.
manifest="log/convert_manifest_${jobID}_${stream}_${stash}.txt"
if [[ "$JOB_L_BATCH" = "True" ]]; then
	mkdir -p log
	: > "$manifest"
fi

# Loop through each pp file and convert it to new format.
# this is done in parallel
for pp_file in "${pp_files[@]}"; do

    # Get the base name of the pp file (without the path)
    base_name=$(basename "$pp_file")
    # Get the file name without the extension
    file="${base_name%.*}"
    # Create the output file name
    converted_file="${file}.$CONVERT_FORMAT"

    pp_file_full="$pp_dir/$pp_file"
    converted_file_full="$converted_dir/$converted_file"
    
	echo "Converting $pp_file in $pp_dir to $CONVERT_FORMAT file" 
	echo "and save to $converted_dir as $converted_file"

	# add to manifest for the slurm job array
	if [[ "$JOB_L_BATCH" = "True" ]]; then
		printf '%s\t%s\n' "$pp_file_full" "$converted_file_full" >> "$manifest"

	# Converting interactively in shell
	elif [[ "$JOB_L_BATCH" = "False" ]]; then
		nohup sh convert_single_pp.sh "$pp_file_full" "$converted_file_full" >> log/interactive_convert_"$jobID"_"$stream"_"$stash".log &
	fi
done

if [[ "$JOB_L_BATCH" = "True" && "${#pp_files[@]}" -gt 0 ]]; then
	n_files=${#pp_files[@]}

	# Prepare sbatch command as an argument array so eval is unnecessary.
	declare -a sbatch_cmd=(
		sbatch
		--parsable
		"--job-name=convert ${jobID}_${stream}_${stash}"
		"--partition=$SLURM_PARTITION"
		"--account=$SLURM_ACCOUNT"
		"--qos=$SLURM_QOS"
		"--time=$SLURM_TIME"
		"--mem=$SLURM_MEMORY"
		"--array=0-$((n_files - 1))%$max_parallel"
		--output=log/convert_%A_%a.out
		--error=log/convert_%A_%a.err
	)

	# Add dependency if provided
	if [[ -n "$dependent_id" ]]; then
		sbatch_cmd+=("--dependency=afterok:$dependent_id")
		sbatch_cmd+=(--kill-on-invalid-dep=yes)
	fi

	sbatch_cmd+=(
		"$SRC_DATA_DIR/convert_pp_array_task.sh"
		"$manifest"
	)

	# Submit the conversion job array and capture the job ID
	convert_id=$("${sbatch_cmd[@]}")
	echo "Converting ID:$convert_id == job array of $n_files file(s), at most $max_parallel at a time (manifest: $manifest)"

	echo "Waiting for $n_files conversion task(s) to finish."

	# Poll until no task of the array is still pending/running.
	while true; do
		mapfile -t task_rows < <(sacct -X -n -P -j "$convert_id" --format=JobID,State,ExitCode)
		if [[ "${#task_rows[@]}" -gt 0 ]] && \
			! printf '%s\n' "${task_rows[@]}" | cut -d'|' -f2 | \
				grep -qE '^(PENDING|RUNNING|REQUEUED|RESIZING|SUSPENDED|CONFIGURING|COMPLETING|SIGNALING|STAGE_OUT)'; then
			break
		fi
		sleep 10
	done

	failed_conversion_files=()
	for row in "${task_rows[@]}"; do
		IFS='|' read -r task_job_id task_state task_exit_code <<< "$row"
		[[ "$task_state|$task_exit_code" = "COMPLETED|0:0" ]] && continue

		task_index="${task_job_id##*_}"
		if [[ "$task_index" =~ ^[0-9]+$ ]]; then
			failed_file=$(sed -n "$((task_index + 1))p" "$manifest" | cut -f1)
		else
			# collapsed range of tasks that never ran, e.g. 123_[5-20]
			failed_file="tasks $task_index"
		fi
		failed_conversion_files+=("$failed_file")
		echo "ERROR: Conversion task $task_job_id failed for file $failed_file with status $task_state|$task_exit_code." >&2
	done

	if [[ "${#failed_conversion_files[@]}" -gt 0 ]]; then
		echo "ERROR: Conversion failures:" >&2
		for failed_file in "${failed_conversion_files[@]}"; do
			echo "  $failed_file" >&2
		done
		exit 1
	fi
fi
