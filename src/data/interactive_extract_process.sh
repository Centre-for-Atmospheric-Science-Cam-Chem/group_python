#!/bin/bash

# driver script to batch extract pp files using retrieve_stash.sh and
# for converting pp files. This should be executed from driver script 
# which sets the global variables

# Usage: sh interactive_extract_convert_process.sh

### DEFINE FUNCTIONS ##################################################################

extract_pp () {

	# Create tmp_pp_dir and parent directories if they don't exist
	mkdir -p "$tmp_pp_dir"

	# Verify directory was created successfully
	if [[ ! -d "$tmp_pp_dir" ]]; then
		echo "Error: Failed to create directory $tmp_pp_dir" >&2
		exit 1
	fi

	echo "Created/verified directory: $tmp_pp_dir"

	# Convert relative SRC_DATA_DIR to absolute path
	src_data_abs="$(cd "$SRC_DATA_DIR" 2>/dev/null && pwd)" || { echo "Error: Cannot resolve $SRC_DATA_DIR" >&2; exit 1; }
	
	## For executing from jasmin-sci machines
	ssh mass-cli "sh \"$src_data_abs/extract_stash.sh\" \"$jobID\" \"$stream\" \"$stash\" \"$tmp_pp_dir\" \"$EXTRACT_MAX_RETRIES\" \"$EXTRACT_QUERY_OPTIONS\"" > "log/extract_atomic_log_${jobID}_${stream}_${stash}" 2>&1
	
	## for using on mass-cli machine interactively
	# sh "$src_data_abs/extract_stash.sh" "$jobID" "$stream" "$stash" "$tmp_pp_dir" \
	# "$EXTRACT_MAX_RETRIES" "$EXTRACT_QUERY_OPTIONS" > "log/extract_atomic_log_${jobID}_${stream}_${stash}" 2>&1

}

convert_pp () {
    echo "Parallel convert files"
	sh convert_one_stash_pp.sh "$jobID" "$stream" "$stash" "$tmp_pp_dir" "$convert_dir"

return 0
}

copy () {
	# copy all files in $src directory to $dest directory
    src=$1
    dest=$2

    echo "Copy files from $src to $dest"
    sh copy_files.sh "$src" "$dest"

    echo ""
    return 0
}


### SET VARIABLES #################################################################

processing_queue="$PATH_PROCESSING_QUEUE"

# Extract the stream and stash for the current $JOBS_ARRAY_TASK_ID
jobID=$(grep "^$JOBS_ARRAY_TASK_ID," "$processing_queue" | head -n1 | cut -d',' -f2 | tr -d '\r')
stream=$(grep "^$JOBS_ARRAY_TASK_ID," "$processing_queue" | head -n1 | cut -d',' -f3 | tr -d '\r')
stash=$(grep "^$JOBS_ARRAY_TASK_ID," "$processing_queue" | head -n1 | cut -d',' -f4 | tr -d '\r')


# Internal variables
# set extract dir to tmp dir if extracting data or if copying data
if [[ "$JOB_L_EXTRACT" = "True" || "$JOB_L_COPY_EXTRACTED" = "True" ]]; then
    tmp_pp_dir="$PATH_TMP_DIR/pp_files/${jobID}/${stream}_${stash}"
    mkdir -p "$tmp_pp_dir"
fi

# set tmp_pp_dir and convert_dir if converting from pp
if [[ "$JOB_L_CONVERT" = "True"  || "$JOB_L_COPY_CONVERTED" = "True"  ]]; then
    convert_dir="$PATH_TMP_DIR/${CONVERT_FORMAT}_files/${jobID}/${stream}_${stash}"
    mkdir -p "$convert_dir"

    # pp data has been extracted and is in tmp
    if [[ "$JOB_L_EXTRACT" = "False" && "$CONVERT_L_USE_EXTRACTED_SAVE_DIR" = "False" ]]; then
       tmp_pp_dir="$PATH_TMP_DIR/pp_files/${jobID}/${stream}_${stash}"
    
    # pp data has been extracted and saved to EXTRACTED_DATA_DIR
    elif [[ "$JOB_L_EXTRACT" = "False" && "$CONVERT_L_USE_EXTRACTED_SAVE_DIR" = "True" ]]; then
        tmp_pp_dir="$PATH_EXTRACTED_SAVE_DIR/pp_files/${jobID}/${stream}_${stash}"
    fi
fi

# Set extract save dir
if [[ "$JOB_L_COPY_EXTRACTED" = "True" && -n "$PATH_EXTRACTED_SAVE_DIR" ]]; then
    extracted_save_dir_full="$PATH_EXTRACTED_SAVE_DIR/pp_files/${jobID}/${stream}_${stash}"
    copy_extracted="True"

elif [[ "$JOB_L_COPY_EXTRACTED" = "True" && -z "$PATH_EXTRACTED_SAVE_DIR" ]]; then
    echo "Error. Set to copy extracted files but"
    echo "extracted_save_dir is not set in config.yaml. Will not copy pp files"
    copy_extracted="False"

else
    copy_extracted="False"
fi

# Set converted save dir
if [[ "$JOB_L_COPY_CONVERTED" = "True" && -n "$PATH_CONVERTED_SAVE_DIR" ]]; then
    converted_save_dir_full="$PATH_CONVERTED_SAVE_DIR/${CONVERT_FORMAT}_files/${jobID}/${stream}_${stash}"
    copy_converted="True"

elif [[ "$JOB_L_COPY_CONVERTED" = "True" && -z "$PATH_CONVERTED_SAVE_DIR" ]]; then
    echo "Error. Set to copy converted files but"
    echo "converted_save_dir is not set in config.yaml. Will not copy converted files"
    copy_converted="False"

else
    copy_converted="False"
fi


### EXECUTION ##################################################################

echo "Start submission: $jobID $stream $stash"
echo ""

# If extract only and not convert
if [[ "$JOB_L_EXTRACT" = "True" ]]; then
	extract_pp
fi

# Copy pp files after extract
if [[ "$JOB_L_EXTRACT" = "True" && "$copy_extracted" = "True" ]]; then
	copy "$tmp_pp_dir" "$extracted_save_dir_full"
fi

# If copying extracted files without actually extracting files
if [[ "$JOB_L_EXTRACT" = "False" && "$copy_extracted" = "True" ]]; then
    copy "$tmp_pp_dir" "$extracted_save_dir_full"
fi


# If extract then convert
if [[ "$JOB_L_EXTRACT" = "True" && "$JOB_L_CONVERT" = "True" ]]; then
    convert_pp
    echo ""
fi

# Just convert
if [[ "$JOB_L_EXTRACT" = "False" && "$JOB_L_CONVERT" = "True" ]]; then

    convert_pp

fi

# If copying converted files after conversion
if [[ "$JOB_L_CONVERT" = "True" && "$copy_converted" = "True" ]]; then
	copy "$convert_dir" "$converted_save_dir_full"
fi

# If copying converted files without actually extracting files
if [[ "$JOB_L_CONVERT" = "False" && "$copy_converted" = "True" ]]; then
    copy "$convert_dir" "$converted_save_dir_full"
fi

echo "Finished submission: $jobID $stream $stash"
echo ""
