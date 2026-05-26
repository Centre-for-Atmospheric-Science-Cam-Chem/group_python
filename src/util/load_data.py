#!/usr/bin/env python

# Utilities for running notebooks

import os
import sys
import xarray as xr

proj_path = os.path.abspath(os.path.join(".."))
if proj_path not in sys.path:
    sys.path.append(proj_path)

from config.proj_defs import rename_vars, data_paths


def load_grids(
    geovols_path=data_paths["geovols"],
    filename_glob=["geovol_192x144x85.nc", "sfarea_192x144.nc"],
):
    """
    Load and return UKESM1 N95 grid data from data directory

    Parameters
    ----------
    geovols_path : str
        Path to the geovols data directory
    filename_glob : list
        List of filenames to load. Default is ['geovol_192x144x85.nc', 'sfarea_192x144.nc']

    Returns
    -------
    grids : xarray.Dataset
        Xarray dataset containing the grid data with renamed coordinates: lat, lon, and
        lev (model level, starting from 1)
    """

    # list files to load
    file_list = [xr.open_mfdataset(f"{geovols_path}/{f}") for f in filename_glob]

    # combine files into a single dataset
    # and rename the coordinates
    rename_dict_grids = {
        "latitude": "lat",
        "longitude": "lon",
        "hybrid_ht": "level_height",
    }
    grids = xr.combine_by_coords(
        file_list, join="outer", combine_attrs="drop_conflicts"
    ).rename(rename_dict_grids)

    # add a 'lev' coordinate that is model level index
    # Create a 1-based index for the 'lev' coordinate using the length of 'level_height'
    grids = grids.assign_coords(
        {"lev": ("level_height", range(1, len(grids.level_height.data) + 1))}
    )
    grids = grids.swap_dims({"level_height": "lev"})

    return grids


def load_um_data(data_path, stash_list, engine="zarr", rename=True):
    """
    Load stashes in stash_list data in data_path into xarray dataset.

    Parameters
    ----------
    data_path : str
        Path to the root of data directory
    stash_list : list
        List of stash to load. should be in numeric form of 12, 31015, 31016, etc.
    engine : str
        The engine to use for loading the data. Default is 'zarr'.
    rename : bool
        If True, rename the variables in the dataset using the rename_vars dictionary
        from proj_defs.py. Default is True.

    Returns
    -------
    dataset : xarray.Dataset
        Xarray dataset containing the data with renamed coordinates: lat, lon, and
        lev (model level, starting from 1)
    """
    # list files to load
    filename_glob = [f"{data_path}/*{f}/*" for f in stash_list]
    print(f"Loading files from {data_path} with stashes {stash_list}")
    file_list = [
        xr.open_mfdataset(
            f,
            engine=engine,
            concat_dim="time",
            combine="nested",
            parallel=True,
        )
        for f in filename_glob
    ]

    # combine files into a single dataset and sort by time
    dataset = xr.combine_by_coords(
        # compat="override",
        file_list,
        join="outer",
        combine_attrs="drop_conflicts",
    ).sortby("time")

    if rename:
        # rename the coordinates
        rename_dict_ukca = {
            "latitude": "lat",
            "longitude": "lon",
            "model_level_number": "lev",
        }
        dataset = dataset.rename(rename_dict_ukca)

        # filter only keys with variables to be renamed in dataset
        filtered_vars = {
            i: rename_vars[i] for i in list(dataset.keys()) if i in rename_vars.keys()
        }
        if (rename_vars != {}) & (rename_vars is not None):
            dataset = dataset.rename(filtered_vars)

        # add grid data (can only be done after renaming coordinates)
        # grids = load_grids()
        # dataset = dataset.merge(grids)

    return dataset


# load data from badc archive
def load_badc_data(data_path, badc_variables):
    """
    Load data from badc archive based on the badc variable list
    """
    file_list = [xr.open_mfdataset(f"{data_path}/{f}") for f in badc_variables]
    dataset = xr.combine_by_coords(
        file_list, join="outer", combine_attrs="drop_conflicts"
    )
    return dataset
