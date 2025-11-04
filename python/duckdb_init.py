#!/usr/bin/env python3
import os, pathlib, duckdb

# Environment variables
DB = os.environ["DUCK_WH_DB"]
TMP = os.environ.get("DUCK_TMP", "/media/ares/data/db/duck/tmp")

# ✅ Ensure the directories exist
pathlib.Path(DB).parent.mkdir(parents=True, exist_ok=True)
pathlib.Path(TMP).mkdir(parents=True, exist_ok=True)

# Config
cfg = {"memory_limit": "24GB", "temp_directory": TMP}

# Initialize DuckDB warehouse (duckdb.connect creates the DB if it doesn't exist)
with duckdb.connect(DB, config=cfg) as con:
    con.execute("CREATE SCHEMA IF NOT EXISTS bronze;")
    con.execute("CREATE SCHEMA IF NOT EXISTS silver;")
    con.execute("CREATE SCHEMA IF NOT EXISTS gold;")
    con.execute("CREATE SCHEMA IF NOT EXISTS meta;")
    con.execute("CHECKPOINT;")

# Confirm settings
with duckdb.connect(DB, read_only=True) as con:
    settings = con.execute("""
        SELECT current_setting('memory_limit') AS memory_limit,
               current_setting('threads') AS threads,
               current_setting('temp_directory') AS temp_directory
    """).fetchall()[0]
    
print("✅ DuckDB initialized at:", DB)
print("   PRAGMAs:", settings)
