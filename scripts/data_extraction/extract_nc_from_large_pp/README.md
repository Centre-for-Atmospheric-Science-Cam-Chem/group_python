# Extract STASH codes from PP files and save as NetCDF

This folder contains scripts for streamlining STASH code extraction from UM PP files and saving selected STASH codes as NetCDF files. The script depends on other codes in `src/data` and `src/util`.

This is especially useful for extracting multiple stashes from multiple large pp files generated from ARCHER2 simulations.

This works on JASMIN [sci servers](https://help.jasmin.ac.uk/docs/interactive-computing/sci-servers/) (and any other servers with access to PP files).

This code is hands-off and extracts STASH codes from PP files in parallel using `slurm`. Everything runs on LOTUS compute nodes to speed up extraction and NetCDF file creation.

## Usage

Main script, `driver_extract_nc_from_large_pp.sh` should be run locally on a sci machine of JASMIN.

This script will submit other scripts to slurm queuing system using `sbatch` for each PP file in the processing queue, as specified in `processing_queue.csv`. Each slurm array job for each PP file is executed in parallel. All uncommented stashes in `stash_list.txt` will be attemted in extraction and saved separately.

Before executing `driver_extract_nc_from_large_pp.sh`, user should edit `config.yaml` to set the job details and monitoring options.

### Steps for using the script

1. Check prerequisites and job details
   - Check that there is a conda environment that has `iris` package. Module jaspy should have this by default.
   - Check for batch job compute allocation. See if user has account with QOS short at least. [See JASMIN documentation](https://help.jasmin.ac.uk/docs/batch-computing/how-to-submit-a-job/).
   - Note the details of Account and QOS which will be needed to set `config.yaml`
   - Example commands and output

   ```bash
   $ useraccounts
   # sacctmgr show user vs480 withassoc format=user%-15,account%-20,qos%-50
   User            Account              QOS
   --------------- -------------------- --------------------------------------------------
   vs480           acsis                debug,high,long,short,standard
   vs480           mass                 mass
   vs480           shobu
   ```

   - Note the details of Account and QOS which will be needed to set `config.yaml`

2. Create or edit `processing_queue.csv` file
   - This file contains the list of PP files to extract STASH codes from. The file should contain 2 columns: `task_id` and `pp_file_path`.
   - Format: `1, /path/to/file.pp`
   - Each row is one PP file to process.
   - Example:

   ```
   1, /work/scratch-pw5/vs480/dest_output/u-du754/20140101T0000Z/du754a.p42014feb.pp
   2, /work/scratch-pw5/vs480/dest_output/u-du754/20140101T0000Z/du754a.p42014jan.pp
   3, /work/scratch-pw5/vs480/dest_output/u-du754/20140101T0000Z/du754a.p52014feb.pp
   ```

   - You can use `ls <directory> >> processing_queue.csv` to populate the paths, then run  `awk '{print NR", "$0}' processing_queue.csv` to prepend with row number.
   - Alternatively, you can create the CSV in external software like Excel/Google Sheets and export as csv files.
   - Use `wc -l processing_queue.csv` to count the total number of PP files to process.

3. Create the reference STASH list file to be extracted
   - This file contains the STASH codes you want to check for and extract.
   - Format: one STASH code per line, e.g., `m01s34i081`
   - Example file content:

   ```
   m01s34i081
   m01s34i001
   m01s34i071
   m01s50i228
   m01s50i063
   ...
   ```

   - Comments (lines starting with `#`) are ignored.

4. Edit `config.yaml`. This file sets how to run the script for each row of `processing_queue.csv`.
   - `job`:
     - `name`: "extract_stash_from_pp" - Job name for slurm (any string is fine; this is for user comment)
     - `l_batch`: True/False - Set to True to submit jobs via SLURM. Set to False to run locally (not yet implemented)
     - `l_extract`: True/False - Set to True to enable extraction. Set to False to skip processing
   - `slurm`:
     - `account`: "acsis" - Your compute allocation. See step 1.
     - `partition`: "standard" - Partition for LOTUS nodes. See step 1.
     - `qos`: "short" - Quality of service. See step 1 and [JASMIN documentation](https://help.jasmin.ac.uk/docs/batch-computing/how-to-submit-a-job/).
     - `time`: "02:00:00" - Wall time per job. [See JASMIN documentation](https://help.jasmin.ac.uk/docs/batch-computing/how-to-submit-a-job/). Default 2 hours.
     - `memory`: "32G" - Memory per job. Adjust based on PP file size and complexity.
     - `array_range`: "1-10" - Set array range to execute the code. This does not have to be the whole range of CSV and does not have to be continuous. e.g. '1,4,10-13' is acceptable. Update this to match your processing_queue.csv size.
   - `paths`:
     - `python_script`: "./read_extract_stash_in_pp_to_file.py" - Path to the extraction script
     - `processing_queue`: "./processing_queue.csv" - Relative or absolute path to the processing queue CSV
     - `stash_list`: "./stash_needed_for_investigation.txt" - Reference STASH list to check against
     - `output_nc`: "/work/scratch-pw5/vs480/nc_files/" - Output directory for extracted NetCDF files
     - `yaml_to_shell`: Path to yaml_to_shell.py utility script
   - `python`:
     - `module_load`: "module load jaspy" - Command to load Python environment with iris

5. Execute the code from the code directory

   On JASMIN, go to this script folder and execute the driver script.

   ```bash
   [vs480@sci-ph-01 extract_nc_from_large_pp]$ sh driver_extract_nc_from_large_pp.sh
   ```

   This should submit array jobs to SLURM, one for each PP file specified in `processing_queue.csv` and `array_range`.

6. Monitor the job

   Each job has its own log in `log/...`

   To monitor slurm jobs, [see JASMIN documentation](https://help.jasmin.ac.uk/docs/batch-computing/how-to-monitor-slurm-jobs/).

   Example command and output

   ```bash
    $ squeue --me
    JOBID PARTIT     QOS         NAME       USER CPUS   ST         TIME    TIME_LEFT PRIORITY NODELIST(REASON)
    49450720  standa    short extract_st...  vs480    1    R        2:35     1:57:25   590140 compute-a-1-23
    49450721  standa    short extract_st...  vs480    1    R        2:34     1:57:26   590140 compute-a-1-24
    49450722  standa    short extract_st...  vs480    1    R        2:33     1:57:27   590140 compute-a-1-25
   ```

   Auto update every 2 seconds:

   ```bash
   [vs480@sci-ph-01 extract_nc_from_large_pp]$ watch -n 2 squeue --me
   ```

### Understanding the queue: why is my job stuck in pending (PD) state?

Note for NODELIST(REASON)

- **Priority**
  Explanation: This job has a lower priority than other jobs in the queue, so it will not start now.
  - Solution: Nothing. LOTUS is busy, just wait for your turn.
  - If really need to jump the queue:
    1. Switch to qos that has higher priority (`short` has the highest priority on LOTUS).
    2. Otherwise, lower job walltime using `config.yaml` `time`. Shorter time means higher priority.

- **Resources**
  Explanation: Not enough resources (CPUs, memory) available.
  - Solution: Nothing. Just wait for earlier jobs to finish.
  - If job still fails, reduce `memory` in `config.yaml` or increase `time` to allow jobs to run longer.

- **QOSMaxJobsPerUserLimit**
  Explanation: You have too many jobs queued at once.
  - Solution: The job will get to run eventually. It is not an error or a problem

### Other useful `squeue` commands

- View all my jobs: `squeue --me`
- View a specific job: `squeue -j <JOBID>`
- Kill the jobs: `scancel`
- Kill all my jobs: `scancel --me`
- Kill a specific jobid: `scancel <JOBID>`
- Cancel a range of jobs: `scancel 49450720-49450722`

---

## Output Structure

After extraction, the output NetCDF files are organized as follows:

```
/work/scratch-pw5/vs480/nc_files/
├── u-du754/ap4.pp_34001/
│   ├── du754ap.4XXXX.nc
│   └── ...
└── u-du754/ap4.pp_34002/
    ├── du754ap.4XXXX.nc
    └── ...
```

Each directory is named `<suite_id>_<stream>/` and contains NetCDF files for each extracted STASH code.

---

## Useful code snippets

### Count total number of PP files to process

```bash
wc -l processing_queue.csv
# Output: 7715 processing_queue.csv
```

### Generate STASH list file from a table

If you have a list of STASH codes in a markdown table (as documented in your investigation), extract unique codes:

```bash
# Example: extract from notes/required_stash.txt
grep "^m01s" notes/required_stash.txt | sort -u > stash_needed_for_investigation.txt
```

### List all available STASH codes in a PP file

```bash
python3 read_extract_stash_in_pp_to_file.py /path/to/file.pp
# This will create file.pp_stash.txt with all available 
# STASH codes in the current working directory
```

### Check available nodes in LOTUS

```bash
sinfo
```

### Check the limits of each QOS

```bash
sacctmgr show qos format=name,priority,maxtrespj%20,maxtrespu%20,maxwall
```

---

## Known problems and future improvements

- Local execution mode (`l_batch=False`) is not yet implemented. Currently must use SLURM submission.
- Suite ID and stream are automatically extracted from PP filename format `[a-z][a-z][0-9][0-9][0-9]a.p[1-9my]*`. If your filename doesn't match this pattern, you need to provide `--suite-id` and `--stream` arguments to `extract_batch.sh`.
- This code produces many log files (one per array job). Consider purging `log/` directory after successful completion.
- Output check text files are written to the current directory. Consider moving them to a dedicated directory after completion.
