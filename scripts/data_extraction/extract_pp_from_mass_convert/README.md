# Download pp file from MASS and convert to NetCDF files

This folder contains scripts for streamlining data retrieval from MASS and converting pp files to NetCDF files. The script depends on other codes in `src/data` and `src/util`.

This works on JASMIN [sci servers](https://help.jasmin.ac.uk/docs/interactive-computing/sci-servers/) (and any other servers with access to mass-cli).

This code is hands-off and works in parallel to retrieve pp and convert to NetCDF files by using scheduling software, `slurm`. Everything runs in parallel on LOTUS compute nodes to speed up conversion.

## Usage

Main script, `driver_download_pp_convert.sh` should be run locally on a sci machine of Jasmin.

This script will submit other scripts to slurm queuing system using `sbatch` for each stash in a user-defined list, genrally called `processing_queue.csv`. Each slurm array job for each stash is executed in parallel.

Before executing `driver_download_pp_convert.sh`, user should edit `config.yaml` to set the job details and monitor job status.

### Steps for using the script

1. Check prerequisites and job details
   - Check that there is a conda environment that has `iris` and `yaml` package. Module jaspy should have this by default.
   - Check for batch job compute allocation. See if user has account with QOS short at least. [See JASMIN documentation](https://help.jasmin.ac.uk/docs/batch-computing/how-to-submit-a-job/).
   - Note the details of Account and QOS which will be needed to set `config.yaml`
   - Example commands and output

   ```bash
   $ useraccounts
   # sacctmgr show user vs480 withassoc format=user%-15,account%-20,qos%-50
   User            Account              QOS
   --------------- -------------------- --------------------------------------------------
   vs480           acsis                dask,debug,high,long,short,standard
   vs480           mass                 mass
   vs480           shobu
   ```

   - Note the details of Account and QOS which will be needed to set `config.yaml`

2. Edit or create `processing_queue.csv` file
   - This is for sbatch to parallelize the download for each stash. The file should contain 4 columns: `task_id`, `job_id`, `stream`, and `stash`. See `processing_queues/processing_queue.csv` for an example.
   - I find it helpful to create the csv in external point-and-click software like Excel/Google Sheets and export as csv files.
   - See [useful code snippets](#useful-code-snippets) for how to check the available stashes in a suite

3. Edit `config.yaml`. This file sets how to run the script for each column of `processing_queue.csv`.
   - `job`:
     - `name`: "AAAAA" Job name for slurm. (Any string is fine; this is for user comment.)
     - `l_batch`: True/False. Must be True for now as the code only accept sbatch execution.
     - `l_download`: True/False. Set to True if downloading stash items.
     - `l_copy_downloaded`: True/False. Set to True if copying the pp files for each stash items from tmp to other directory.
     - `l_convert`: True/False. Set to True of converting pp to nc or zarr. See convert section below.
     - `l_copy_converted`: True/False. Set to True if copying the converted stash items from tmp to other directory.
   - `slurm`:
     - `account`: "account". See step 1.
     - `partition`: "standard". See step 1.
     - `qos`: "short". See step 1 and [JASMIN documentation](https://help.jasmin.ac.uk/docs/batch-computing/how-to-submit-a-job/).
     - `time`: "4:00:00". [See JASMIN documentation](https://help.jasmin.ac.uk/docs/batch-computing/how-to-submit-a-job/). Default 4 hours is the upper limit for short qos.
     - `memory`: "200000". [See JASMIN documentation](https://help.jasmin.ac.uk/docs/batch-computing/how-to-submit-a-job/).
     - `array_range`: "1-6". Set array range in `processing_queue.csv` to execute the code. This does not have to be the whole range of csv and does not have to be continuous. e.g. '1,4,10-13' is acceptable.
   - `path`:
     - `tmp_dir`: "/work/scratch-pw2/\<USERNAME>" the usual scrath location for a user. Use a disk with parallel write access for speed.
     - `downloaded_save_dir`: "/gws/nopw/j04/acsis/vs480/model_output". Optional, for storing pp files long-term
     - `converted_save_dir`: "/gws/nopw/j04/acsis/vs480/model_output". Optional, for storing converted files long-term
     - `processing_queue`: "./processing_queues/processing_queue.csv" . Relative or absolute path to the `processing_queue.csv`. The name can be changed to submit to different queues. Do not forget to set `array_range` to customise the array job.
   - `download`:
     - `l_extra_query`: True/False. Set to True if need extra query options. Then specify the query option file below.
     - `max_retries`: 3. Optional. Just in case need more than 3 retries for downloading data from MASS
     - `walltime`: "24:00:00" Set maximum job download time. Shorter time means the queue gets higher priority
     - `query_options`: "./query_options.txt" optional, for setting extra query options, especially time domain to download, only use if `l_extra_query` is True
   - `convert`:
     - `l_use_downloaded_save_dir`: True/False. Optional. For converting from pp files in `downloaded_save_dir` instead of from `tmp_dir`
     - `format`: "nc"/"zarr" case sensitive (untested). Only nc is working now.

4. Execute the code from the code directory

   On Jasmin, go to this script folder and execute the driver script.

   ```bash
   [vs480@sci-ph-01 download_pp_convert]$ sh driver_download_pp_convert.sh
   ```

   This should spawn a master job, then the master job should spawn.
   - downloading: one array job for each row in the processing queue CSV file, as directed by array_range.
   - copying downloaded pp: one array job that depends on the completion of the downloading job
   - converting: one array job for stash. This then spawns one job for each pp file. There will be a lot of jobs.
   - copying converted file: one array job for each stash. This will wait for the conversion to be done.

5. Monitor the job

   Each job has its own log in `log/...`

   To monitor slurm jobs, [see JASMIN documentation](https://help.jasmin.ac.uk/docs/batch-computing/how-to-monitor-slurm-jobs/).

   Example command and output

   ```bash
    $ squeue --me
    JOBID PARTIT       QOS                 NAME       USER NODE  CPUS ST         TIME    TIME_LEFT PRIORITY NODELIST(REASON)
    49450720   mass      mass     u-bv828 50291 pp      vs480    1     1  R        12:35     23:47:25   590140 moose2
    49450721   mass      mass     u-bv828 50873 pp      vs480    1     1  R        12:35     23:47:25   590140 moose2
    49450722   mass      mass     u-bv828 50914 pp      vs480    1     1  R        12:35     23:47:25   590140 moose2
    49450726   mass      mass     u-bv828 50290 pp      vs480    1     1  R        12:35     23:47:25   590140 moose2
    49450728   mass      mass     u-bv828 50654 pp      vs480    1     1  R        12:35     23:47:25   590140 moose2
    49450729 standa     short   pp2nc dep:49450728      vs480    1     1 PD         0:00      2:00:00   292039 (Dependency)
    49450727 standa     short   pp2nc dep:49450726      vs480    1     1 PD         0:00      2:00:00   292039 (Dependency)
    49450725 standa     short   pp2nc dep:49450722      vs480    1     1 PD         0:00      2:00:00   292039 (Dependency)
    49450724 standa     short   pp2nc dep:49450721      vs480    1     1 PD         0:00      2:00:00   292039 (Dependency)
    49450723 standa     short   pp2nc dep:49450720      vs480    1     1 PD         0:00      2:00:00   292039 (Dependency)
   ```

   Auto update

   ```bash
   [vs480@sci-ph-01 download_pp_convert]$ watch squeue --me
   ```

### Understanding the queue: why is my job stuck in pending (PD) state?

Note for NODELIST(REASON)

- **Priority**
  Explanation: This job has a lower priority than other jobs in the queue, so it will not start now.
  - Solution: Nothing. LOTUS/MASS is busy, just wait for your turn.
  - If really need to jump the queue
    1. Switch to qos that has higher priority (`short` has the highest priority on LOTUS. `mass` is the only qos for mass partition).
    2. Otherwise, lower job walltime using `config.yaml` `time` and `walltime`. 1:00:00 means 1 hour
- **Dependency**
  - Explanation: A job depends on finishing another job first.
  - Solution: Nothing. Just wait for that preceding job to finish. This applies to copying and converting
- **Resources**
  - Explanation: not enough resources
  - Solution: Nothing. Just wait for those earlier jobs to finish for your turn. If really need to jump the queue, see jumping queue in Priority above

### Other useful `squeue` commands

- kill the jobs: `scancel`
- kill all my jobs: `scancel --me`
- kill a specific jobid: `scancel <ID>`

---

## Useful code snippets

### List all stash id available in a set (a rose suite)

Execute on `mass-cli`

```bash
jobid="u-dm931" ## EDIT
for f in $(moo ls moose:crum/$jobid/*pp); do stream=$(echo $f| cut -d/ -f4 | cut -d. -f1) ; moo mdls --attribute=stash $f>> $jobid_$stream ; done
```

This lists all stash items in each stream in separate text files.

### Check available nodes in LOTUS

```bash
  sinfo
```

### Check the limit of each QOS

```bash
   $ sacctmgr show qos format=name,priority,maxtrespj%20,maxtrespu%20,maxwall
      Name   Priority              MaxTRES            MaxTRESPU     MaxWall
---------- ---------- -------------------- -------------------- -----------
  standard        500      cpu=16,mem=128G             cpu=4000  1-00:00:00
      long        350      cpu=16,mem=128G             cpu=1350  5-00:00:00
     short        550       cpu=8,mem=200G             cpu=2000    04:00:00
     debug        500                                    cpu=50    01:00:00
      dask        500                                    cpu=16
      mass        500
      high        450     cpu=96,mem=1000G    cpu=576,mem=4500G  2-00:00:00
```

---

## Known problem

- This code will always try to check for download pp `max_retries` times. It's probably better to don't try if the download is not corrupted to be a good MASS citizen...
- working directory in `driver_download_pp_convert.sh` is relative to current directory and is hardcoded. Probably need a better way of doing this.
- Copying converted nc file does not depend on each nc convert job. That means `l_copy_converted` needs to be False when `l_convert` is True for now.
- This code may be too parallel when converting each pp file. It produces too many log files. It may be useful to group together conversion log files.
