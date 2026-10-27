# Extract pp file from MASS and convert to NetCDF files

**Please check out the whole git directory (group_python) for this script to work**

This folder contains scripts for streamlining data retrieval from MASS and converting pp files to NetCDF files. The script depends on other codes in `src/data` and `src/util`.

This works on JASMIN [sci servers](https://help.jasmin.ac.uk/docs/interactive-computing/sci-servers/) (and any other servers with access to mass-cli).

This code is hands-off and works in parallel to retrieve pp and convert to NetCDF files by using scheduling software, `slurm`. Everything runs in parallel on LOTUS compute nodes to speed up conversion.

## Usage

Main script, `driver_extract_pp_convert.sh` should be run locally on a sci or a vm machine of Jasmin.

This script will submit other scripts to slurm queuing system using `sbatch` for each stash in a user-defined list, genrally called `processing_queue.csv`. Each slurm array job for each stash is executed in parallel.

Before executing `driver_extract_pp_convert.sh`, user should edit `config.yaml` to set the job details and monitor job status.

### Steps for using the script

1. **Check prerequisites and job details**

- Check that the runtime provides Iris and PyYAML. The `jaspy` module should provide both packages on JASMIN.
- Check for batch job compute allocation. See if user has account with QOS short at least. [See JASMIN documentation](https://help.jasmin.ac.uk/docs/batch-computing/how-to-submit-a-job/).
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

1. **Edit or create `processing_queue.csv` file**

- This is for parallelize each stash. The file must contain the columns `task_id`, `job_id`, `stream`, and `stashID`. An optional fifth `label` column may be included for your own reference; it is ignored by the workflow. See `processing_queues/processing_queue.csv` for an example.
  - `task_id` values must be positive integers and unique.
  - `stashID` must be numeric.
- I find it helpful to create the csv in external point-and-click software like Excel/Google Sheets and export as csv files.
- See [useful code snippets](#useful-code-snippets) for how to check the available stashes in a suite

1. **Edit `config.yaml`.** This file sets how to run the script for each column of `processing_queue.csv`.
   - `job`:
     - `name`: "AAAAA" Job name for slurm. (Any string is fine; this is for user comment.)
     - `l_batch`: True/False. Must be True for now as the code only accept sbatch execution.
     - `l_extract`: True/False. Set to True if extracting stash items.
     - `l_copy_extracted`: True/False. Set to True if copying the pp files for each stash items from tmp to other directory.
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
     - `extracted_save_dir`: "/gws/nopw/j04/acsis/vs480/model_output". Optional, for storing pp files long-term
     - `converted_save_dir`: "/gws/nopw/j04/acsis/vs480/model_output". Optional, for storing converted files long-term
     - `processing_queue`: "./processing_queues/processing_queue.csv" . Relative paths are resolved relative to this workflow directory; absolute paths are also accepted. The name can be changed to submit to different queues. Do not forget to set `array_range` to customise the array job.
   - `extract`:
     - `query_options`: "./query_options.txt" optional, for setting extra query options, especially time domain to extract. Leave empty ("") or omit to not use extra query options
     - `max_retries`: 3. Optional. Just in case need more than 3 retries for extracting data from MASS
     - `walltime`: "24:00:00" Set maximum job extract time. Shorter time means the queue gets higher priority.

   - `convert`:
     - `l_use_extracted_save_dir`: True/False. Optional. For converting from pp files in `extracted_save_dir` instead of from `tmp_dir`
     - `format`: "nc"/"zarr" case sensitive. Only nc is working now.
     - `max_parallel`: 10 Set maximum conversion tasks running at once per stash (default 10)

2. **Execute the code**

  Execute the driver with Bash. It can be called from any directory; paths to the repository scripts and workflow logs are resolved from the driver location.

   ```bash
  bash driver_extract_pp_convert.sh
   ```

  An alternative configuration file can be supplied as the first argument:

  ```bash
  bash driver_extract_pp_convert.sh /path/to/config.yaml
  ```

  The driver performs preflight checks before submitting jobs. Logs are written to the workflow's `log/` directory.

  This should spawn an array of workflow jobs. Each array task maps to one validated row in the processing queue.

1. **Monitor the job**

  Each job has its own log in `log/...`. Per-file conversion jobs use separate output and error logs named with their SLURM job IDs.

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
   [vs480@sci-ph-01 extract_pp_convert]$ watch squeue --me
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

## More details

- extracting: one MASS extraction job for each requested array task.
- copying extracted pp: an optional `rsync` job that waits for extraction to complete successfully.
- converting: one conversion coordinator for each requested array task. It submits one conversion job per pp file and waits for all of them to finish.
- copying converted files: an optional `rsync` job that waits for the conversion coordinator and therefore all per-file conversion jobs to complete successfully.

Jobs use SLURM `afterok` dependencies. If extraction or conversion fails, dependent conversion or copy jobs do not start. Jobs with dependencies also use `--kill-on-invalid-dep=yes`.

Each generated NetCDF file is reopened with Iris after conversion. A conversion job fails if the output cannot be read or contains no readable cubes. Failed conversion reports include the input pp filename.

Copies use `rsync --archive --partial`, which preserves metadata, includes hidden files, and allows interrupted transfers to resume. Existing files in the destination are not deleted.

---

## Known problem

- The driver requires Bash, Python 3 with PyYAML, and (for batch mode) Slurm's `sbatch` command. It resolves repository scripts and workflow logs from its own location, while data directories remain configured in `config.yaml`.
- Conversion is intentionally fanned out to one SLURM job per pp file, which allows independent resources and failure reporting but can produce many jobs and log files. If this becomes a scheduling or bookkeeping problem, conversion could be grouped into fewer jobs.
