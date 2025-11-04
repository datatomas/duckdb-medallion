#!/usr/bin/env python3
# duckdb_clone_timestamped.py
# pip install duckdb
import os
import sys
import pathlib
import tempfile
import shutil
import argparse
from datetime import datetime
import duckdb

DEFAULT_TMP = os.getenv("DUCK_TMP", "/tmp")

def now_stamp():
    # Local time, down to second, safe for filenames
    return datetime.now().strftime("%Y-%m-%d_%H-%M-%S")

def resolve_destination_path(dst_arg: str, src_path: pathlib.Path, stamp: str) -> pathlib.Path:
    """
    If dst_arg is a directory (or ends without .duckdb), create:
      <dst_arg>/<src_stem>_<stamp>.duckdb
    If dst_arg looks like a file path ending with .duckdb, use its parent and name.
    """
    dst = pathlib.Path(dst_arg)
    if dst.suffix.lower() != ".duckdb":
        # Treat as directory; auto-name the file
        dst_dir = dst
        dst_dir.mkdir(parents=True, exist_ok=True)
        name = f"{src_path.stem}_{stamp}.duckdb"
        return dst_dir / name
    else:
        dst.parent.mkdir(parents=True, exist_ok=True)
        return dst

def make_sibling_dirs(dst_path: pathlib.Path):
    """Create ad/ and r/ alongside the destination DB file."""
    # Disabled - uncomment if needed
    # root = dst_path.parent
    # (root / "ad").mkdir(parents=True, exist_ok=True)
    # (root / "r").mkdir(parents=True, exist_ok=True)
    pass

def export_import_clone(src_wh: str, dst_db: pathlib.Path, tmp_root: str, force: bool):
    src = pathlib.Path(src_wh)
    if not src.is_file():
        raise FileNotFoundError(f"Source database not found: {src}")

    # Export to a clean temp dir
    with tempfile.TemporaryDirectory(prefix="duckdb_export_", dir=tmp_root) as tdir:
        with duckdb.connect(str(src), read_only=True) as con_src:
            con_src.execute(f"EXPORT DATABASE '{tdir}' (FORMAT PARQUET)")

        # Create temp file path but DON'T create the file yet
        temp_dst_path = dst_db.parent / f"duckdb_clone_{os.getpid()}_{now_stamp()}.duckdb"
        
        try:
            # Let DuckDB create the file properly
            with duckdb.connect(str(temp_dst_path)) as con_dst:
                con_dst.execute(f"IMPORT DATABASE '{tdir}'")
                con_dst.execute("ANALYZE")
                con_dst.execute("CHECKPOINT")

            if dst_db.exists():
                if not force:
                    raise FileExistsError(
                        f"Destination exists: {dst_db}. Use --force to overwrite."
                    )
                os.replace(str(temp_dst_path), str(dst_db))  # atomic on POSIX
            else:
                shutil.move(str(temp_dst_path), str(dst_db))
        except Exception as e:
            # Cleanup if something went wrong
            if temp_dst_path.exists():
                try:
                    temp_dst_path.unlink()
                except Exception:
                    pass
            raise e

def main():
    ap = argparse.ArgumentParser(
        description="Clone a DuckDB database into a timestamped file and create ad/ and r/ folders."
    )
    ap.add_argument("src", nargs="?", help="Source DuckDB file (e.g., /mnt/data/db/duck/warehouse/prod.duckdb)")
    ap.add_argument("dst", nargs="?", help="Destination directory OR .duckdb file path. "
                                           "If a directory, a timestamped filename will be created inside.")
    ap.add_argument("--tmp-root", default=DEFAULT_TMP, help="Temp dir root for EXPORT/IMPORT (default: DUCK_TMP or /tmp).")
    ap.add_argument("--force", action="store_true", help="Overwrite destination DB if it already exists (atomic replace).")
    args = ap.parse_args()

    src = args.src or os.getenv("SRC_WH")
    dst = args.dst or os.getenv("DUCK_DEV_DB")

    if not src or not dst:
        print(
            "Usage:\n"
            "  python duckdb_clone_timestamped.py /path/to/src.duckdb /path/to/dst_dir_or_file\n"
            "Examples:\n"
            "  python duckdb_clone_timestamped.py /mnt/data/db/duck/warehouse/prod.duckdb /mnt/data/db/duck/dev\n"
            "  python duckdb_clone_timestamped.py /mnt/data/db/duck/warehouse/prod.duckdb /mnt/data/db/duck/dev/dev_wh.duckdb --force\n"
            "Or with env vars:\n"
            "  SRC_WH=/path/to/src.duckdb DUCK_DEV_DB=/path/to/dst_dir_or_file python duckdb_clone_timestamped.py\n",
            file=sys.stderr,
        )
        sys.exit(2)

    stamp = now_stamp()
    src_path = pathlib.Path(src)
    dst_path = resolve_destination_path(dst, src_path, stamp)

    # Ensure ad/ and r/ exist next to the destination DB
    make_sibling_dirs(dst_path)

    # If dst_path is a zero-byte placeholder, remove to avoid DuckDB header errors
    if dst_path.exists() and dst_path.stat().st_size == 0:
        dst_path.unlink()

    export_import_clone(str(src_path), dst_path, args.tmp_root, force=args.force)

    print("✅ Clone complete")
    print(f"   created_at : {stamp}")
    print(f"   source     : {src_path}")
    print(f"   dest_db    : {dst_path}")
    print(f"   sibling dirs: {dst_path.parent / 'ad'}, {dst_path.parent / 'r'}")

if __name__ == "__main__":
    main()
