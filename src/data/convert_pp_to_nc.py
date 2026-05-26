"""
Convert pp file to netcdf file in a directory and its subdirectory one by one

Usage: convert_pp_to_nc.py pp_file_path nc_file_path
"""

import iris
from datetime import datetime
import STASH_fields_defs as def_STASH
import sys

# Future-proofing per warnings from iris 20260120
iris.FUTURE.save_split_attrs = True

pp_file_path = sys.argv[1]
nc_file_path = sys.argv[2]


def get_current_time():
    # Print current time
    now = datetime.now()
    current_time = now.strftime("%H:%M:%S")
    return current_time


"""
Convert a pp file in `pp_file_path` to an nc file and save to `nc_file_path`.
"""

# read in .pp file
print(f"  Loading file ... {get_current_time()}", end="")
cubes = iris.load(pp_file_path, callback=def_STASH.UKCA_callback)
print(f" - {get_current_time()}  DONE")

# write to .nc file
print(f"  Saving to .nc ... {get_current_time()}", end="")
# arr.to_netcdf(nc_dir)
iris.save(cubes, nc_file_path)
print(f" - {get_current_time()}  DONE")
