#!/usr/bin/env python3
import os, pathlib, duckdb

DB  = os.environ["DUCKDB_PATH"]                         # /media/ares/data/db/duck/warehouse/warehouse.duckdb
TMP = os.environ.get("DUCK_TMP", "/media/ares/data/db/duck/tmp")

# ensure dirs exist
pathlib.Path(DB).parent.mkdir(parents=True, exist_ok=True)
pathlib.Path(TMP).mkdir(parents=True, exist_ok=True)

# choose ONE of these:
# 1) Let DuckDB decide (recommended)
cfg = {"memory_limit": "24GB", "temp_directory": TMP}

# 2) Or set threads explicitly (uncomment if you want control)
# threads = max(1, (os.cpu_count() or 1) - 1)  # leave 1 core free
# cfg = {"memory_limit": "24GB", "temp_directory": TMP, "threads": str(threads)}

with duckdb.connect(DB, config=cfg) as con:
    con.execute("CREATE SCHEMA IF NOT EXISTS bronze;")
    con.execute("CREATE SCHEMA IF NOT EXISTS silver;")
    con.execute("CREATE SCHEMA IF NOT EXISTS gold;")
    con.execute("CREATE SCHEMA IF NOT EXISTS meta;")
    con.execute("CHECKPOINT;")

with duckdb.connect(DB, read_only=True) as con:
    settings = con.execute("""
      SELECT
        current_setting('memory_limit')  AS memory_limit,
        current_setting('threads')       AS threads,
        current_setting('temp_directory') AS temp_directory
    """).fetchall()[0]

print("✅ DuckDB initialized at:", DB)
print("   PRAGMAs:", settings)
