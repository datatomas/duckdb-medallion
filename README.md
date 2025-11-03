# 🦆 Duck Lakehouse (Medallion)

A practical DuckDB lakehouse that shows how to build a **dev/prod workflow** using the **medallion architecture** (Bronze → Silver → Gold). No clusters or services — just DuckDB, Parquet, and SQL.

---

## What this repo demonstrates

* **Dev/Prod separation** – Work safely in a development catalog while keeping production intact.
* **Multiple data access patterns** – Views over Parquet files, read‑through views, and physical table copies.
* **Medallion layers** – Bronze (raw), Silver (cleaned), Gold (aggregated).
* **Zero infra** – Single‑file databases, no servers, no auth.

The repo includes real SQL scripts, Python utilities, and shell helpers to run common data‑engineering tasks on a single machine.

---

## Repo layout

```
duckdb-medallion/
├── README.md
├── python/
│   ├── duckdb_init.py                  # Initialize production warehouse
│   ├── duckdb_parquet_reader.py        # Utility examples (Parquet + DuckDB)
│   └── duckdb_disaster_clone.py        # Copy a DuckDB file (prod → dev/backup)
├── sql/
│   ├── dev_init_bronze_catalog.sql     # Clone PROD bronze → DEV (editable tables)
│   ├── duckdb_views_prod_to_dev.sql    # Read-through views in DEV → PROD
│   └── duckdb_clone_db_to_parquet.sql  # Views over Parquet lake
│   └── duckdb_clone_db_to_parquet.sql
└── scripts/
    ├── make_dirs.sh                    # Create lakehouse dir structure
    └── init_env.sh                     # Export environment variables
```

> Paths and names are examples; adjust to your system. Linux/macOS assumed.

---

## Prerequisites

* **DuckDB CLI** ≥ 0.10
* **Python** ≥ 3.10
* Python package: `duckdb`

```bash
pip install duckdb
```

---

## Quick start

### 1) Clone & create directories

```bash
git clone https://github.com/yourusername/duckdb-medallion.git
cd duckdb-medallion

# Create lakehouse directories
bash scripts/make_dirs.sh
```

This yields a structure like:

```
/media/ares/data/db/
├── duck/
│   ├── warehouse/        # Production catalog
│   ├── dev/              # Development catalog
│   ├── backups/          # Database backups
│   └── tmp/              # Temp files
└── lake/
    ├── bronze/           # Raw Parquet files / landing area
    ├── silver/           # Cleaned data
    └── gold/             # Aggregated data
```

**`scripts/make_dirs.sh`** (reference):

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT=/media/ares/data/db
mkdir -p "$ROOT/duck/warehouse" "$ROOT/duck/dev" "$ROOT/duck/backups" "$ROOT/duck/tmp"
mkdir -p "$ROOT/lake/bronze" "$ROOT/lake/silver" "$ROOT/lake/gold"
echo "Created base lakehouse directories under $ROOT"
```

### 2) Configure environment

```bash
bash scripts/init_env.sh
source ~/.bashrc   # or: source ~/.zshrc
```

**`scripts/init_env.sh`** (reference):

```bash
#!/usr/bin/env bash
cat >> "$HOME/.bashrc" <<'EOF'
export DUCK_WH_DB="/media/ares/data/db/duck/warehouse/sports_ml_warehouse.duckdb"
export DUCK_DEV_DB="/media/ares/data/db/duck/dev/sports_ml_warehouse.duckdb"
export LAKE_ROOT="/media/ares/data/db/lake"
EOF

echo "Environment vars appended to ~/.bashrc: DUCK_WH_DB, DUCK_DEV_DB, LAKE_ROOT"
```

### 3) Initialize the production warehouse

```bash
python python/duckdb_init.py
```

This script creates the warehouse database, sets up baseline schemas (e.g., `bronze`), and applies performance settings (threads, memory limits).

### 4) Verify the setup

```bash
duckdb "$DUCK_WH_DB" -c "
  PRAGMA database_list;
  SELECT schema_name FROM information_schema.schemata ORDER BY 1;
"
```

---

## Three data access patterns

### Pattern 1 — **Views over Parquet** (the lake)

Create views that read directly from Parquet files. New files are picked up automatically.

```bash
duckdb "$DUCK_WH_DB" -init sql/duckdb_views_from_parquet.sql
```

**`sql/duckdb_views_from_parquet.sql`**

```sql
PRAGMA threads=8;
CREATE SCHEMA IF NOT EXISTS bronze;

CREATE OR REPLACE VIEW bronze.ufc_fighters AS
SELECT * FROM read_parquet(
  '/media/ares/data/db/lake/bronze/ufc/ufc_fighters/**/*.parquet',
  hive_partitioning=true,
  union_by_name=true
);

CREATE OR REPLACE VIEW bronze.ufc_fights AS
SELECT * FROM read_parquet(
  '/media/ares/data/db/lake/bronze/ufc/ufc_fights/**/*.parquet',
  hive_partitioning=true,
  union_by_name=true
);
```

Query immediately:

```bash
duckdb "$DUCK_WH_DB" -c "
  SELECT COUNT(*) FROM bronze.ufc_fighters;
  SELECT * FROM bronze.ufc_fights LIMIT 5;
"
```

---

### Pattern 2 — **Read‑through views (DEV → PROD)**

Create DEV views that point at PROD tables. Read‑only and zero storage in DEV.

```bash
duckdb "$DUCK_DEV_DB" -init sql/duckdb_views_prod_to_dev.sql
```

**`sql/duckdb_views_prod_to_dev.sql`**

```sql
PRAGMA threads=8;
ATTACH '/media/ares/data/db/duck/warehouse/sports_ml_warehouse.duckdb' AS wh (READ_ONLY);

CREATE SCHEMA IF NOT EXISTS bronze_views;

CREATE OR REPLACE VIEW bronze_views.ufc_fighters AS SELECT * FROM wh.bronze.ufc_fighters;
CREATE OR REPLACE VIEW bronze_views.ufc_fights   AS SELECT * FROM wh.bronze.ufc_fights;
CREATE OR REPLACE VIEW bronze_views.one_athletes AS SELECT * FROM wh.bronze.one_athletes;
CREATE OR REPLACE VIEW bronze_views.one_fights   AS SELECT * FROM wh.bronze.one_fights;
```

Check what's available:

```bash
duckdb "$DUCK_DEV_DB" -c "
  SELECT table_schema, table_name, 'VIEW' AS table_type
  FROM information_schema.views
  WHERE table_schema = 'bronze_views'
  ORDER BY 1,2;

  SELECT COUNT(*) FROM bronze_views.ufc_fighters;
"
```

---

### Pattern 3 — **Physical DEV copies (editable)**

Clone PROD tables into DEV as materialized, editable copies. Great for experiment‑heavy work.

```bash
duckdb "$DUCK_DEV_DB" -init sql/dev_init_bronze_catalog.sql
```

**`sql/dev_init_bronze_catalog.sql`**

```sql
PRAGMA threads=8;
ATTACH '/media/ares/data/db/duck/warehouse/sports_ml_warehouse.duckdb' AS wh (READ_ONLY);

CREATE SCHEMA IF NOT EXISTS bronze;

-- Clone with basic deduplication
DROP TABLE IF EXISTS bronze.ufc_fighters;
CREATE TABLE bronze.ufc_fighters AS
SELECT DISTINCT * FROM wh.bronze.ufc_fighters;
CREATE UNIQUE INDEX IF NOT EXISTS pk_ufc_fighters ON bronze.ufc_fighters(fighter_id);

DROP TABLE IF EXISTS bronze.ufc_fights;
CREATE TABLE bronze.ufc_fights AS
SELECT DISTINCT * FROM wh.bronze.ufc_fights;
CREATE UNIQUE INDEX IF NOT EXISTS pk_ufc_fights ON bronze.ufc_fights
  (fighter_id, opponent, event, round, time, method, result);

DROP TABLE IF EXISTS bronze.one_athletes;
CREATE TABLE bronze.one_athletes AS
SELECT DISTINCT * FROM wh.bronze.one_athletes;

DROP TABLE IF EXISTS bronze.one_fights;
CREATE TABLE bronze.one_fights AS
SELECT DISTINCT * FROM wh.bronze.one_fights;

CHECKPOINT;
```

Now you have editable tables:

```bash
duckdb "$DUCK_DEV_DB" -c "
  SELECT table_schema, table_name, table_type
  FROM information_schema.tables
  WHERE table_schema='bronze'
  ORDER BY 1,2;

  -- Example edit (DEV only)
  UPDATE bronze.ufc_fighters SET weight_class = 'Lightweight' WHERE fighter_id = 123;
"
```

---

## Common workflows

### Working in DEV

```sql
-- In DEV
ATTACH '/media/ares/data/db/duck/warehouse/sports_ml_warehouse.duckdb' AS wh (READ_ONLY);

-- Compare row counts
SELECT 'DEV' AS env, COUNT(*) FROM bronze.ufc_fights
UNION ALL
SELECT 'PROD', COUNT(*) FROM wh.bronze.ufc_fights;

-- Build a trial Silver table in DEV
CREATE SCHEMA IF NOT EXISTS silver;
CREATE OR REPLACE TABLE silver.fight_stats AS
SELECT
    fight_id,
    event_date,
    fighter_a,
    fighter_b,
    winner,
    CAST(round AS INTEGER) AS round_num
FROM bronze.ufc_fights
WHERE event_date >= '2020-01-01';
```

### Refreshing DEV from PROD

```bash
# Re-run the clone script to sync DEV with current PROD
duckdb "$DUCK_DEV_DB" -init sql/dev_init_bronze_catalog.sql

# Verify
duckdb "$DUCK_DEV_DB" -c "
  SELECT COUNT(*) AS fighters FROM bronze.ufc_fighters;
  SELECT COUNT(*) AS fights   FROM bronze.ufc_fights;
"
```

### Reading Parquet directly (no DB)

```bash
duckdb -c "
  SELECT *
  FROM read_parquet('/media/ares/data/db/lake/bronze/ufc/ufc_fighters/*.parquet')
  LIMIT 10;
"
```

### Using Python

**`python/duckdb_parquet_reader.py`**

```python
import duckdb

con = duckdb.connect('/media/ares/data/db/duck/warehouse/sports_ml_warehouse.duckdb')

fighters = con.execute(
    """
    SELECT fighter_name, weight_class, wins, losses
    FROM bronze.ufc_fighters
    WHERE wins > 10
    ORDER BY wins DESC
    LIMIT 20
    """
).df()

print(fighters)

parquet_data = con.execute(
    """
    SELECT * FROM read_parquet('/media/ares/data/db/lake/bronze/ufc/ufc_fighters/*.parquet')
    """
).df()
```

---

## Disaster recovery / cloning

**Shell (simple copy)**

```bash
# Copy prod → backup (DuckDB is a single file)
cp "$DUCK_WH_DB" "/media/ares/data/db/duck/backups/warehouse_$(date +%Y%m%d).duckdb"
```
**Copy From DB to Parquet duckdb_clone_db_to_parquet.sql  reference **
export SNAPSHOT_DIR="/media/user/data/db/lake/disaster_recovery/dr_ml_sports_wh_medallion/$(date +%Y%m%d_%H%M%S)"


envsubst < /media/user/data/tomassuarez/Documents/Gitrepos/ml_kuda_sports_lab/src/ml_kuda_sports_lab/dbs/duckdb_clone_prod_to_dr_parquet.sql \
  | duckdb -batch ":memory:"


**Python (prod → dev)**

```bash
python python/duckdb_disaster_clone.py \
  /media/ares/data/db/duck/warehouse/sports_ml_warehouse.duckdb \
  /media/ares/data/db/duck/warehouse/dev_sports_ml_warehouse.duckdb
```

**`python/duckdb_disaster_clone.py`** (reference):

```python
import shutil, sys
src = sys.argv[1]
dst = sys.argv[2]
shutil.copy2(src, dst)
print(f"Copied {src} → {dst}")
```

---



## Medallion architecture in practice

### Bronze — Raw data

Parquet files as ingested from source systems. Immutable, append‑only.

```
$LAKE_ROOT/bronze/
├── ufc/
│   ├── ufc_fighters/
│   │   └── 2025-10-27.parquet
│   └── ufc_fights/
│       └── 2025-10-27.parquet
└── one_championship/
    ├── one_athletes.parquet
    └── one_fights.parquet
```

### Silver — Cleaned data (example)

```sql
CREATE SCHEMA IF NOT EXISTS silver;
CREATE OR REPLACE TABLE silver.fight_stats AS
SELECT
    fight_id,
    event_date,
    fighter_a_id,
    fighter_b_id,
    winner_id,
    method,
    CAST(round AS INTEGER) AS round_num
FROM bronze.ufc_fights
WHERE fight_id  IS NOT NULL
  AND method    IS NOT NULL
  AND event_date >= '2020-01-01';
```

### Gold — Business metrics (example)

```sql
CREATE SCHEMA IF NOT EXISTS gold;
CREATE OR REPLACE TABLE gold.fighter_win_rates AS
SELECT
    fighter_name,
    COUNT(*)                                           AS total_fights,
    SUM(CASE WHEN result = 'win' THEN 1 ELSE 0 END)    AS wins,
    ROUND(100.0 * wins / total_fights, 2)              AS win_rate_pct
FROM silver.fight_stats
GROUP BY fighter_name
HAVING total_fights >= 5
ORDER BY win_rate_pct DESC;
```

---

## Useful commands

### Inspect the database

```sql
-- List all schemas
SELECT schema_name FROM information_schema.schemata ORDER BY 1;

-- List all tables and views
SELECT table_schema, table_name, table_type
FROM information_schema.tables
ORDER BY 1,2;

-- Show table definition
.schema bronze.ufc_fighters

-- Check attached databases
PRAGMA database_list;
```

### Performance knobs

```sql
SET memory_limit='4GB';
SET threads=8;
VACUUM;
ANALYZE;
CHECKPOINT;
```

### Data export

```bash
# CSV
duckdb "$DUCK_WH_DB" -c "
  COPY (SELECT * FROM bronze.ufc_fighters)
  TO '/tmp/fighters.csv' (HEADER, DELIMITER ',');
"

# Parquet
duckdb "$DUCK_WH_DB" -c "
  COPY (SELECT * FROM gold.fighter_win_rates)
  TO '/tmp/win_rates.parquet' (FORMAT PARQUET, COMPRESSION SNAPPY);
"
```

---

## Troubleshooting

**"Conflicting lock is held"**

```bash
# Close all DuckDB sessions, then check/remove locks (if safe)
ls -la /media/ares/data/db/duck/warehouse/*.lock
rm -f   /media/ares/data/db/duck/warehouse/*.lock
```

**Views show 0 rows**

```sql
PRAGMA database_list;            -- verify ATTACH path
SELECT * FROM wh.bronze.ufc_fighters LIMIT 1;
```

**Parquet views empty**

```bash
ls -lh /media/ares/data/db/lake/bronze/ufc/ufc_fighters/

duckdb -c "SELECT COUNT(*) FROM read_parquet('/media/.../ufc_fighters.parquet');"
```

---

## Why this pattern works

**Local development**

* Test with production‑sized datasets without cloud costs.
* Experiment freely in DEV without touching PROD.
* Instant feedback (DuckDB queries are fast on a single machine).

**Small/medium production**

* No infra to manage; scales to 100GB+ on one box.
* Simple backups (copy a file).
* Version control your SQL.

**Learning data engineering**

* See medallion architecture in practice.
* Understand dev/prod separation.
* Learn SQL optimization and modeling patterns.

---

## What DuckDB is (and isn’t)

**DuckDB is** an embedded analytical database (SQLite for analytics), columnar and vectorized, MIT‑licensed, great for OLAP/ETL and data science.

**DuckDB isn’t** an OLTP database, a distributed system, or a real‑time streaming engine.

---

## Next steps (roadmap)

* ML pipelines (feature engineering from Silver/Gold)
* dbt integration (declarative transforms + tests)
* Data quality checks (Great Expectations)
* Scheduling (cron/Airflow)
* Docker packaging
* Optional serverless endpoints (e.g., Azure Functions)

---

## License

MIT — use however you like.

---

### Notes

* Replace example paths with your own.
* Keep `DUCK_WH_DB`, `DUCK_DEV_DB`, and `LAKE_ROOT` in sync with your directory layout.
* If you’re on Windows, use WSL or adjust paths accordingly.
