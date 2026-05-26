#!/usr/bin/env python3
"""
Extract and check STASH codes from a PP subset file.

This script extracts available STASH codes from a simulation PP file and:
1. Lists available STASH codes
2. Optionally checks against a reference STASH list (--subset-stash)
3. Optionally extracts matching STASH codes to NetCDF files (--extract-stash)

Requirements:
    module load jaspy

USAGE MODES:

  Mode 1: List all STASH codes (default output name)
    python read_stash_in_pp_to_file.py <input_pp>
    # Output: <input_pp>_stash.txt (in current directory)

  Mode 2: List all STASH codes (custom output)
    python read_stash_in_pp_to_file.py <input_pp> <output_text_file>

  Mode 3: Check which STASH codes from a list are available
    python read_stash_in_pp_to_file.py <input_pp> <output_text_file> --subset-stash <stash_list.txt>
    # output_text_file shows: stash_code available or not available

  Mode 4: Check AND extract available STASH codes to NetCDF
    python read_stash_in_pp_to_file.py <input_pp> <output_text_file> --subset-stash <stash_list.txt> --extract-stash \\
                                       --nc-dir <output_nc_dir> --suite-id suite_id --stream stream
    # Extracts all STASH codes from stash_list.txt that are available in input_pp. 
    # suite_id and stream are optional and if not given will be determined from input_pp name 
    # if input_pp is in the format <suite><stream>*.pp 

EXAMPLES:

  # List all STASH codes
  python read_stash_in_pp_to_file.py data.pp
  python read_stash_in_pp_to_file.py data.pp stash_codes.txt

  # Check which STASH from a list are available
  python read_stash_in_pp_to_file.py data.pp check_results.txt --subset-stash stash_list.txt

  # Check and extract available STASH codes
  python read_stash_in_pp_to_file.py data.pp check_results.txt \\
      --subset-stash stash_list.txt --extract-stash --nc-dir ./nc_output/ 

  # Check and extract available STASH codes with explicit suite-id and stream
  python read_stash_in_pp_to_file.py data.pp check_results.txt \\
      --subset-stash stash_list.txt --extract-stash --nc-dir ./nc_output/ \\
      --suite-id u-dk111 --stream apm.pp

  # Extracted .nc will be written to <nc_dir>/<suite_id>_<stream>/data.nc
"""

import iris
import sys
import argparse
from pathlib import Path

iris.FUTURE.save_split_attrs = True


def format_stash(stash_code):
    """
    Format STASH code by removing metadata prefixes and leading zeros.

    Applies transformations equivalent to:
        sed 's/m01s//g; s/^0//g; s/^0//g; s/i//g; s/^0//g; s/^0//g'

    Args:
        stash_code: STASH code string (e.g., "m01s34i081")

    Returns:
        Formatted STASH code (e.g., "34081")
    """
    formatted = stash_code
    formatted = formatted.replace("m01", "")
    # special case for s01 which should just be removed
    formatted = formatted.replace("s01", "")
    formatted = formatted.replace("s", "")
    formatted = formatted.lstrip("0") or "0"
    formatted = formatted.replace("i", "")
    formatted = formatted.lstrip("0") or "0"
    return formatted


def extract_suite_and_stream(pp_basename):
    """
    Extract suite_id and stream from PP file basename.

    Expected format: [a-z][a-z][0-9][0-9][0-9]a.p[1-9my]*
    Example: dk502a.p42015apr → suite_id=u-dk502, stream=ap4.pp

    Args:
        pp_basename: Basename of PP file without extension (e.g., "dk502a.p42015apr")

    Returns:
        Tuple of (suite_id, stream) or (None, None) if format doesn't match
    """
    import re

    # Pattern: [a-z][a-z][0-9][0-9][0-9]a.p[1-9my]
    pattern = r"^([a-z]{2})(\d{3})a\.p([1-9my])"
    match = re.match(pattern, pp_basename)

    if not match:
        return None, None

    suite_prefix = match.group(1)  # e.g., "dk"
    suite_number = match.group(2)  # e.g., "502"
    stream_char = match.group(3)  # e.g., "4"

    suite_id = f"u-{suite_prefix}{suite_number}"  # e.g., "u-dk502"
    stream = f"ap{stream_char}.pp"  # e.g., "ap4.pp"

    return suite_id, stream


def extract_and_save_stash(
    pp_file, stash_code, output_nc_dir, pp_basename, suite_id=None, stream=None
):
    """
    Extract a specific STASH code from PP file and save as NetCDF.

    Args:
        pp_file: Path to input PP file
        stash_code: STASH code to extract (string)
        output_nc_dir: Base output directory for NetCDF files
        pp_basename: Base filename of the PP file (for organizing output)
        suite_id: (optional) suite_id of the PP file (for organizing output)
        stream: (optional) stream of the PP file (for organizing output)

    Returns:
        Tuple of (True/False for success, output_file_path)
    """
    try:
        # Extract suite_id and stream from pp_basename if not provided
        if suite_id is None or stream is None:
            extracted_suite_id, extracted_stream = extract_suite_and_stream(pp_basename)

            if extracted_suite_id is None or extracted_stream is None:
                print(
                    f"ERROR: Could not extract suite_id and stream from {pp_basename}. "
                    f"Expected format: [a-z][a-z][0-9][0-9][0-9]a.p[1-9my]*. "
                    f"Please provide --suite-id and --stream arguments.",
                    file=sys.stderr,
                )
                return False, None

            # Use extracted values if not provided
            if suite_id is None:
                suite_id = extracted_suite_id
            if stream is None:
                stream = extracted_stream

        # Create output subdirectory: <suite_id>_<stream>/
        # Remove .pp extension from stream for directory name
        formatted_stash = format_stash(stash_code)

        subdir_name = f"{stream}_{formatted_stash}"
        output_subdir = Path(output_nc_dir) / suite_id / subdir_name
        output_subdir.mkdir(parents=True, exist_ok=True)

        # Output file: <nc_dir>/<suite_id>_<stream>/<pp_basename>.nc
        output_file = output_subdir / f"{pp_basename}.nc"

        # Use iris constraint to filter by STASH code
        constraint = iris.NameConstraint(STASH=stash_code)
        cubes = iris.load(str(pp_file), constraints=constraint)

        if not cubes:
            return False, None

        iris.save(cubes, str(output_file))
        return True, output_file

    except Exception as e:
        print(f"  WARNING: Failed to extract STASH {stash_code}: {e}", file=sys.stderr)
        return False, None


def get_available_stash(pp_file):
    """
    Read all available STASH codes from PP file.

    Returns:
        Set of STASH codes as strings
    """
    pp_path = Path(pp_file)

    if not pp_path.exists():
        print(f"ERROR: Input file not found: {pp_file}", file=sys.stderr)
        return None

    try:
        cubes = iris.load(str(pp_path))

        if not cubes:
            print(f"WARNING: No data found in {pp_file}", file=sys.stderr)
            return set()

        stash_codes = set()
        for cube in cubes:
            stash = cube.attributes.get("STASH")
            if stash is not None:
                stash_codes.add(str(stash))

        return stash_codes

    except Exception as e:
        print(f"ERROR: Failed to read {pp_file}: {e}", file=sys.stderr)
        import traceback

        traceback.print_exc()
        return None


def read_stash_list(stash_list_file):
    """
    Read STASH codes from a file (one per line).

    Returns:
        Set of STASH codes as strings
    """
    try:
        with open(stash_list_file, "r") as f:
            stash_codes = set(
                line.strip() for line in f if line.strip() and not line.startswith("#")
            )
        return stash_codes
    except Exception as e:
        print(
            f"ERROR: Failed to read STASH list from {stash_list_file}: {e}",
            file=sys.stderr,
        )
        return None


def main():
    """Main entry point with flexible argument parsing."""
    parser = argparse.ArgumentParser(
        description="Extract and check STASH codes from a PP file",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )

    # Positional arguments (only 2 allowed)
    parser.add_argument(
        "input_pp",
        help="Input PP file to extract STASH codes from",
    )
    parser.add_argument(
        "output_text_file",
        nargs="?",
        default=None,
        help="Output text file (optional, defaults to <input_pp>_stash.txt)",
    )

    # Optional arguments
    parser.add_argument(
        "--subset-stash",
        type=str,
        default=None,
        help="Reference STASH list file to check against",
    )
    parser.add_argument(
        "--extract-stash",
        action="store_true",
        help="Extract available STASH codes to NetCDF files (requires --nc-dir)",
    )
    parser.add_argument(
        "--nc-dir",
        type=str,
        help="Output directory for NetCDF files (required with --extract-stash)",
    )
    parser.add_argument(
        "--suite-id",
        type=str,
        help="(optional) suite ID, in the form of u-xxNNN, e.g. u-dv111",
    )
    parser.add_argument(
        "--stream",
        type=str,
        help="(optional) stream, in the form of apX.pp, e.g. ap4.pp",
    )

    args = parser.parse_args()

    # Validate --extract-stash usage
    if args.extract_stash:
        if not args.nc_dir:
            print("ERROR: --nc-dir is required when using --extract-stash")
            sys.exit(1)
        if not args.subset_stash:
            print("ERROR: --subset-stash is required when using --extract-stash")
            sys.exit(1)

    # Determine output file
    if args.output_text_file is None:
        pp_basename = Path(args.input_pp).stem
        output_text_file = f"{pp_basename}_stash.txt"
    else:
        output_text_file = args.output_text_file

    # Create output directory if needed
    output_path = Path(output_text_file)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    pp_basename = Path(args.input_pp).stem

    print(f"Reading PP file: {args.input_pp}")
    available_stash = get_available_stash(args.input_pp)

    if available_stash is None:
        sys.exit(1)

    if not available_stash:
        print(f"WARNING: No STASH codes found in {args.input_pp}")
        sys.exit(0)

    print(f"Found {len(available_stash)} unique STASH code(s)")

    # If subset stash list provided, check against it; otherwise use all available
    if args.subset_stash:
        print(f"Reading STASH list from: {args.subset_stash}")
        stash_to_check = read_stash_list(args.subset_stash)

        if stash_to_check is None:
            sys.exit(1)

        print(f"Checking {len(stash_to_check)} STASH code(s) from list")
    else:
        stash_to_check = available_stash

    # Check availability and write results
    print(f"Writing results to: {output_text_file}")

    available_count = 0
    not_available_count = 0

    with open(output_text_file, "w") as f:
        for stash in stash_to_check:
            if stash in available_stash:
                f.write(f"{stash} available\n")
                available_count += 1
            else:
                f.write(f"{stash} not available\n")
                not_available_count += 1

    # Extract to NetCDF if requested
    if args.extract_stash and available_stash:
        print(f"\nExtracting available STASH codes to NetCDF in {args.nc_dir}...")
        nc_extracted = 0

        for stash in sorted(available_stash):
            if stash in stash_to_check:
                success, output_nc_file = extract_and_save_stash(
                    args.input_pp,
                    stash,
                    args.nc_dir,
                    pp_basename,
                    suite_id=args.suite_id,
                    stream=args.stream,
                )
                if success:
                    nc_extracted += 1
                    print(f"  Saved: {output_nc_file}")

        print(f"Extracted {nc_extracted} STASH code(s)")

    # Print summary
    print(f"\nSummary:")
    print(f"  Total STASH codes checked: {available_count + not_available_count}")
    print(f"  Available: {available_count}")
    print(f"  Not available: {not_available_count}")

    sys.exit(0)


if __name__ == "__main__":
    main()
