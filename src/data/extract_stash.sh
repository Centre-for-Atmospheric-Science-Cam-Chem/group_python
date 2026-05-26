#!/bin/bash

# This a script to extract pp files from the MASS archive that match a given stash number 
# and save to a specified directory. It is designed to be run on mass-cli or from account=mass
# when submitted from slurm
# It uses the moo select to filter out relevant stash. 
# As default, it will try 3 times before exiting.

# This script could be run directly from the command line, or
# as a batch extract job from batch_retrieve_pp.sh, or
# as part of a larger workflow from batch_retrieve_and_convert_to_nc.sh

# Edit query_options.txt as appropriate for the data file being extracted e.g. include year range
# See https://gws-access.jasmin.ac.uk/public/mohc_shared/moose-user-doc/external_user_guide.html#record-level-retrieval-query-syntax
# Example queries
#   T1=20180101
#   T2=20181231
# Do not set if extracting full time range

# Edit the try loop (imax) to change the number of attempts if needed.

# Usage: [on mass-cli] sh retrieve_pp.sh $jobID $stream $stash $extract_dir (optional) $imax $queries

jobID=$1 # e.g. u-cu594
stream=$2 # e.g. ap4.pp
stash=$3 # e.g. 38285
extract_dir=$4 # e.g. /work/scratch-pw5/vs480/pp_files/$jobID/${jobID}_${stream}_${stash}
imax=${5:-"3"} # default = 3
queries=${6:-""} # default is empty

# Get absolute path of queries if defined
if [[ -n "$queries" ]]; then
    queries=$(realpath "$queries")
fi

# go to the directory where the data will be extracted
cd "$extract_dir"  || { echo "ERROR: $extract_dir not exist"; exit 1; }

# Log variable information
echo "Current directory = $(pwd)"
echo "Extract directory = $extract_dir"
echo "Job ID = $jobID"
echo "stream = $stream"
echo "stash = $stash"
echo ""

# create query file 
# See Moose documentation for details on the query file format
# https://gws-access.jasmin.ac.uk/public/mohc_shared/moose-user-doc/external_user_guide.html
# Users are asked not to submit more than 50 moo select commands in parallel. 

query_file="query_file.txt"
{
  echo "begin"
  echo "  stash=$stash"
  [[ -n "$queries" ]] && cat "$queries"
  echo "end"
} > "$query_file"
echo "Query file created: $query_file"
cat $query_file
echo ""

# load ppfile from moose and save to tmp directory. 
i=1
until [ $i -gt "$imax" ]; do
  echo "Attemp $i/$imax;"
  echo "  moo select --fill-gaps-and-overwrite-smaller-files $query_file moose:crum/$jobID/$stream ./"
  moo select --fill-gaps-and-overwrite-smaller-files $query_file moose:crum/"$jobID"/"$stream" ./ 
  ((i++))
done

echo ""
echo "------------------------------------------------"
