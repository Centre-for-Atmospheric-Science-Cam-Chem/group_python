# Download pp file from MASS and convert to NetCDF files

This folder contains scripts for streamlining data retrieval from MASS and converting pp files to NetCDF files.

This works on JASMIN [sci servers](https://help.jasmin.ac.uk/docs/interactive-computing/sci-servers/) (and any other servers with access to mass-cli).

This code is hands-off and works in parallel to retrieve pp and convert to NetCDF files by using scheduling software, `slurm`. Everything runs in parallel on LOTUS compute nodes to speed up conversion.

## Usage

Main script, `driver_download_pp_convert.sh` should be run locally on the sci machine of Jasmin.

Before executing `driver_download_pp_convert.sh`, the user should edit `config.yaml` to set the job details.

This script will submit other scripts to Slurm's `sbatch` for each stash in a user-defined list, generally called `processing_queue.csv`. Each Slurm array job for each stash is executed in parallel.


### Steps for using the script

1. Check prerequisites and job details

   - Check that a conda environment has `iris` and `yaml` packages. Module `jaspy` should have this by default.
   - Check for batch job compute allocation. See if the user has an account with QOS short at least. [See manual](https://help.jasmin.ac.uk/docs/batch-computing/how-to-submit-a-job/).

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

   - This is for sbatch to parallelise the download for each stash. The file should contain four columns: `task_id`, `job_id`, `stream`, and `stash`. See `processing_queues/processing_queue.csv` for an example. I find it helpful to create the CSV in external point-and-click software like Excel or Google Sheets and export it as a CSV file.
   - Check the available stashes in a suite (See [useful code snippets](#useful-code-snippets))

3. Edit `config.yaml`. This file sets how to run the script for each column of `processing_queue.csv`.

   - `job`:
     - `name`: job name for Slurm
     - `l_batch`: True/False. Must be True for now, as the code only accepts sbatch execution
     - `l_download`: True/False. Set to True if downloading the -stash items
     - `l_copy_downloaded`: True/False. Set it to True to copy each stash item's pp files from tmp to another directory.
     - `l_convert`: True/False. Set it to True to convert pp to nc or zarr. See the convert section below.
     - `l_copy_converted`: True/False. Set to True if copying the converted stash items from tmp to another directory.
   - `slurm`:
     - `account`: "account". See prerequisite
     - `partition`: "standard". See prerequisite.
     - `qos`: "short". See prerequisite.
     - `time`: "4:00:00." See prerequisite. The upper limit for short Qos is 4 hours by default.
     - `memory`: "200000". See prerequisite.
     - `array_range`: "1-6". Set the array range in `processing_queue.csv` to execute the code. This does not have to be the whole range of CSV and does not have to be continuous. e.g. '1,4,10-13' is acceptable
   - `path`:
     - `tmp_dir`: "/work/scratch-pw2/\<USERNAME>" the usual scrath location for a user. Use a disk with parallel write access for speed.
     - `downloaded_save_dir`: "/gws/nopw/j04/acsis/vs480/model_output". Optional, for storing pp files long-term
     - `converted_save_dir`: "/gws/nopw/j04/acsis/vs480/model_output". Optional, for storing converted files long-term
     - `processing_queue`: "./processing_queues/processing_queue.csv" . Relative or absolute path to the `processing_queue.csv`. The name can be changed to submit to different queues. Do not forget to set `array_range` to customise the array job.
   - `download`:
     - `l_extra_query`: True/False. Set to True if needed extra query options. Then specify the query option file below.
     - `max_retries`: 3. Optional. Just in case, need more than 3 retries for downloading data from MASS
     - `query_options`: "./query_options.txt" optional, for setting extra query options, primarily time domain to download, only use if `l_extra_query` is True
   - `convert`:
     - `l_use_downloaded_save_dir`: True/False. Optional. For converting from pp files in `downloaded_save_dir` instead of from `tmp_dir`
     - `format`: "nc"/"zarr" case sensitive (untested). Only nc is working now.

4. Submit the code from the code directory

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
   
   To monitor Slurm jobs, [see here](https://help.jasmin.ac.uk/docs/batch-computing/how-to-monitor-slurm-jobs/).
   
   Auto update
   
   ```bash
   [vs480@sci-ph-01 download_pp_convert]$ watch squeue --me
   ```
   
   Print out to the terminal once
   
   ```bash
   [vs480@sci-ph-01 download_pp_convert]$ squeue --me
   ```

### Why is my job stuck in the pending (PD) state?

Note for NODELIST(REASON)

- **Priority**
  Explanation: This job has a lower priority than other jobs in the queue, so it will not start now.
  - Solution: Nothing. LOTUS/MASS is busy, just wait for your turn.
  - If you really need to jump the queue
    1. Switch to a QoS with a higher priority (`short` has the highest priority on LOTUS; `mass` is the only QoS for mass partition).
    2. Otherwise, lower job walltime to `time`: 1:00:00
- **Dependency**
  - Explanation: A job depends on finishing another job first.
  - Solution: Nothing. Just wait for that preceding job to finish. This applies to copying and converting
- **Resources**
  - Explanation: not enough resources
  - Solution: Nothing. Just wait for those earlier jobs to finish for your turn. If you really need to jump the queue, see jumping the queue in Priority above
- Others: [See full list of reasons here](https://slurm.schedmd.com/squeue.html#lbAF)
---

## Useful code snippets

### List all stash id available in a set (a rose suite)

```bash
jobid="u-dm931" ## EDIT
for f in $(moo ls moose:crum/$jobid/*pp); do stream=$(echo $f| cut -d/ -f4 | cut -d. -f1) ; moo mdls --attribute=stash $f>> $jobid_$stream ; done
```

This lists all stash items in each stream in separate text files.

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

- This code will always try to check for download pp `max_retries` times. To be a good MASS citizen, it's probably better not to try if the download is not corrupted.
- The working directory in `driver_download_pp_convert.sh` is hardcoded relative to the current directory. We probably need a better way of doing this.
