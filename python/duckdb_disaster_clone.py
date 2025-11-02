#!/usr/bin/env python3
# clone_warehouse.py
# pip install duckdb
import os, sys, pathlib, duckdb

TABLES = [
    "ufc_fighters",
    "ufc_fights"
]

SCHEMA = "bronze"

def clone_wh(src_wh: str, dst_db: str):
    # --- sanity + mkdirs ---
    src = pathlib.Path(src_wh)
    if not src.is_file():
        raise FileNotFoundError(f"Source warehouse not found: {src}")
    dst = pathlib.Path(dst_db)
    dst.parent.mkdir(parents=True, exist_ok=True)  # create folder if missing

    # --- connect (creates DB file if it doesn't exist) ---
    con = duckdb.connect(str(dst))
    con.execute("PRAGMA threads=8")
    con.execute(f"CREATE SCHEMA IF NOT EXISTS {SCHEMA}")

    # --- attach prod read-only ---
    src_escaped = str(src).replace("'", "''")
    con.execute(f"ATTACH '{src_escaped}' AS wh (READ_ONLY)")

    # --- materialize tables (overwrite if they exist) ---
    for t in TABLES:
        con.execute(f"DROP TABLE IF EXISTS {SCHEMA}.{t}")
        con.execute(f"CREATE TABLE {SCHEMA}.{t} AS SELECT * FROM wh.{SCHEMA}.{t}")

    # --- optional: stats + checkpoint ---
    con.execute("ANALYZE")
    con.execute("CHECKPOINT")

    # --- quick verification ---
    rows = con.execute(f"""
        SELECT table_schema, table_name, table_type
        FROM information_schema.tables
        WHERE table_schema = '{SCHEMA}'
        ORDER BY 1,2;
    """).fetchall()
    for r in rows:
        print(r)

def main():
    # Accept either CLI args or env vars for easy wiring in scripts/CI
    # Env fallbacks keep names you're already using.
    src = (sys.argv[1] if len(sys.argv) > 1 else os.getenv("SRC_WH"))
    dst = (sys.argv[2] if len(sys.argv) > 2 else os.getenv("DUCK_DEV_DB"))
    if not src or not dst:
        print(
            "Usage:\n"
            "  python clone_warehouse.py /path/to/prod_wh.duckdb /path/to/dev_wh.duckdb\n"
            "Or with env vars:\n"
            "  SRC_WH=/path/to/prod_wh.duckdb DUCK_DEV_DB=/path/to/dev_wh.duckdb python clone_warehouse.py",
            file=sys.stderr,
        )
        sys.exit(2)
    clone_wh(src, dst)

if __name__ == "__main__":
    main()
