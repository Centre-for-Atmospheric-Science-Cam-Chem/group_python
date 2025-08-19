#!/bin/bash
#SBATCH --job-name=dl_pp
#SBATCH --account=acsis
#SBATCH --partition=debug # standard or debug
#SBATCH --qos=debug
#SBATCH -o %j.out
#SBATCH -e %j.err
#SBATCH --time=1:00:00
#SBATCH --array=1-24 # edit to match the range in array_stream_stash.txt. This can select only the lines needed
#SBATCH --mem=200000

# driver script to batch download pp files using retrieve_stash.sh

# Usage: sh retrieve_pp_batch.sh

# Set config
# TODO: change to config.yaml
tmpdir="/work/scratch-pw2/vs480"
processing_queue='./processing_queue_extra-noy.csv'

# Get current task ID, either from slurm or from passing in the variable from interactive shell or from reading config file
TASK_ID=$SLURM_ARRAY_TASK_ID

# Extract the stream and stash for the current $SLURM_ARRAY_TASK_ID
jobID=$(grep "^$TASK_ID," "$processing_queue" | head -n1 | cut -d',' -f2 | tr -d '\r')
stream=$(grep "^$TASK_ID," "$processing_queue" | head -n1 | cut -d',' -f3 | tr -d '\r')
stash=$(grep "^$TASK_ID," "$processing_queue" | head -n1 | cut -d',' -f4 | tr -d '\r')

# Internal variables
download_dir="$tmpdir/pp_files/${jobID}_${stream}_${stash}"

# Create download_dir and parent directories if they don't exist
mkdir -p "$download_dir"

# Verify directory was created successfully
if [[ ! -d "$download_dir" ]]; then
    echo "Error: Failed to create directory $download_dir" >&2
    exit 1
fi

echo "Created/verified directory: $download_dir"

# submit to mass queue
# SLURM job submission using config
SLURM_RETRIEVE_ID=$(sbatch --parsable \
       --job-name="$jobID $stash pp" \
       --partition="mass" \
       --account="mass" \
       --qos="mass" \
       retrieve_stash.sh "$jobID" "$stream" "$stash" "$download_dir")

echo "Submitted MASS retrieval job for $TASK_ID with job ID: $SLURM_RETRIEVE_ID"
echo "jobID=$jobID; stream=$stream; stash=$stash"