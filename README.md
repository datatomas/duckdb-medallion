🦆 Duck Lakehouse (Medallion) – README

A tiny, batteries-included DuckDB lakehouse that runs on a single machine.
It’s built around the medallion pattern (bronze → silver → gold), supports both Parquet + DuckDB catalogs, and gives you one-command workflows for:

Seeding a DEV DuckDB catalog from PROD (read-through views)

Taking physical dumps (editable copies) from PROD into DEV

Creating persistent views over your Parquet data lake

Running quick scrapers/loaders (optional) into bronze

No services, no clusters — just DuckDB + files. Fast, cheap, portable.

✨ What you get

bronze_views_from_prod.sql – creates bronze_views.* views in DEV that point to PROD tables (read-only).

bronze_dump_from_prod.sql – clones PROD bronze.* tables into DEV bronze.* tables (physical, editable).

bronze_views_from_parquet.sql – creates views over Parquet folders in your lake (auto-picks up new files).

One-liners to list, count, and sanity-check both views and tables.

Environment setup (paths, aliases) so you can work fast.

📁 Repo layout
duck-lakehouse/
├── README.md
├── dbs/
│   ├── bronze_dump_from_prod.sql         # physical clones into DEV
│   ├── bronze_views_from_prod.sql        # read-through views in DEV → PROD
│   ├── bronze_views_from_parquet.sql     # views over lake/Parquet
│   ├── duckdb_parquet_reader.py          # example reader utility (optional)
│   ├── duckdb_persistent_views.py        # programmatic view creation (optional)
│   └── scripts/
│       ├── make_dirs.sh                  # create lake + duck folders
│       ├── init_env.sh                   # export env vars into ~/.bashrc
│       └── refresh_dev_dump.sh           # run dump script safely
├── loaders/
│   └── nhl_tag_and_save.py               # CSV → Parquet or DuckDB (optional)
├── Makefile
└── .env.example

🧱 One-time setup

Folders (single 1.6TB disk; adjust if you like):

bash dbs/scripts/make_dirs.sh


make_dirs.sh creates:

/media/ares/data/db/
  ├─ duck/
  │   ├─ warehouse/   # PROD catalog
  │   ├─ dev/         # DEV catalog
  │   └─ tmp/
  └─ lake/
      ├─ bronze/
      ├─ silver/
      └─ gold/


Environment (paths you already use):

bash dbs/scripts/init_env.sh
source ~/.bashrc


That seeds:

export DUCK_WH_DB="/media/ares/data/db/duck/warehouse/sports_ml_warehouse.duckdb"
export DUCK_DEV_DB="/media/ares/data/db/duck/dev/sports_ml_warehouse.duckdb"
export LAKE_ROOT="/media/ares/data/db/lake"


Tip: copy .env.example → .env and source .env if you prefer shell-local envs.

🚀 Quickstart
1) Create read-through views in DEV pointing to PROD
duckdb "$DUCK_DEV_DB" \
  -init dbs/bronze_views_from_prod.sql


Check:

duckdb "$DUCK_DEV_DB" -c "
SELECT table_schema, table_name, 'VIEW' AS table_type
FROM information_schema.views
WHERE table_schema='bronze_views'
ORDER BY 1,2;

SELECT COUNT(*) FROM bronze_views.ufc_fighters;
SELECT COUNT(*) FROM bronze_views.ufc_fights;
"

2) Make physical DEV copies of PROD bronze tables (editable)
bash dbs/scripts/refresh_dev_dump.sh


This runs dbs/bronze_dump_from_prod.sql safely (drops→creates) to produce:

DEV: bronze.ufc_fighters (BASE TABLE)
DEV: bronze.ufc_fights   (BASE TABLE)
DEV: bronze.one_athletes (BASE TABLE)
DEV: bronze.one_fights   (BASE TABLE)


Check:

duckdb "$DUCK_DEV_DB" -c "
SELECT table_schema, table_name, table_type
FROM information_schema.tables
WHERE table_schema='bronze'
ORDER BY 1,2;

SELECT COUNT(*) AS fighters FROM bronze.ufc_fighters;
SELECT COUNT(*) AS fights   FROM bronze.ufc_fights;
"

3) Create views over Parquet (the “lake”)
duckdb "$DUCK_WH_DB" \
  -init dbs/bronze_views_from_parquet.sql


These read directly from:

$LAKE_ROOT/bronze/ufc/ufc_fighters/**/*.parquet
$LAKE_ROOT/bronze/ufc/ufc_fights/**/*.parquet
$LAKE_ROOT/bronze/one/one_athletes*.parquet
$LAKE_ROOT/bronze/one/one_fights*.parquet

🧱 Medallion pattern in this repo

Bronze (raw)

Parquet files in $LAKE_ROOT/bronze/...

DuckDB views in bronze_views_from_parquet.sql

Physical bronze tables in DEV (for experiments) cloned from PROD

Silver / Gold

You can add transformation SQLs (CTAS / MERGE) later under dbs/silver_*.sql, dbs/gold_*.sql.

Recommend writing materialized tables in DEV first, then promote.

🛠️ Everyday commands

List schemas/tables:

duckdb "$DUCK_DEV_DB" -c "
SELECT schema_name FROM information_schema.schemata ORDER BY 1;
SELECT table_schema, table_name, 'TABLE' AS kind
FROM information_schema.tables
UNION ALL
SELECT table_schema, table_name, 'VIEW'
FROM information_schema.views
ORDER BY 1,2,3;
"


Switch between catalogs:

duckdb "$DUCK_WH_DB"   # PROD
duckdb "$DUCK_DEV_DB"  # DEV


Attach PROD read-only in any session:

ATTACH '/media/ares/data/db/duck/warehouse/sports_ml_warehouse.duckdb' AS wh (READ_ONLY);

📦 Optional loader (CSV → Parquet or DuckDB)
# Parquet, single file
python loaders/nhl_tag_and_save.py --to parquet \
  --in "/home/ares/data/tomassuarez/Documents/Gitrepos/ml_kuda_sports_lab/datasets/nhldraft.csv" \
  --parquet-dir "$LAKE_ROOT/bronze/nhl"

# Parquet, partitioned by year
python loaders/nhl_tag_and_save.py --to parquet \
  --partition-by year \
  --parquet-dir "$LAKE_ROOT/bronze/nhl"

# DuckDB, append into PROD bronze
python loaders/nhl_tag_and_save.py --to duck \
  --duckdb-path "$DUCK_WH_DB" \
  --duckdb-schema bronze \
  --duckdb-table nhl_draft_tagged \
  --mode append


You can also set envs: NHL_DRAFT_CSV, NHL_DRAFT_OUT_DIR, NHL_WAREHOUSE_DB.

🧪 Make targets (optional)
# Makefile
.PHONY: views-prod-to-dev dump-dev-from-prod views-from-parquet

views-prod-to-dev:
	duckdb "$$DUCK_DEV_DB" -init dbs/bronze_views_from_prod.sql

dump-dev-from-prod:
	bash dbs/scripts/refresh_dev_dump.sh

views-from-parquet:
	duckdb "$$DUCK_WH_DB" -init dbs/bronze_views_from_parquet.sql

🧹 Maintenance

Refreshing DEV dumps: run make dump-dev-from-prod (or refresh_dev_dump.sh) whenever PROD updates.

Parquet views: they auto-pick up new files — no refresh needed.

Backups: copy whole .duckdb files into duck/backups/ (they’re single files).

🚑 Troubleshooting

“Conflicting lock is held”
Close Python/CLI sessions using the same DuckDB file, or kill PID shown in error.

Views show 0 rows
Check the ATTACH ... AS wh (READ_ONLY) path and that PROD file exists.

Parquet views empty
Verify $LAKE_ROOT and folder names; use read_parquet() ad-hoc to test.

📜 Licensing

MIT; do whatever you want. PRs welcome.

Included SQL / Bash (summaries)
dbs/bronze_views_from_prod.sql
PRAGMA threads=8;
ATTACH '/media/ares/data/db/duck/warehouse/sports_ml_warehouse.duckdb' AS wh (READ_ONLY);

CREATE SCHEMA IF NOT EXISTS bronze_views;

CREATE OR REPLACE VIEW bronze_views.ufc_fighters AS SELECT * FROM wh.bronze.ufc_fighters;
CREATE OR REPLACE VIEW bronze_views.ufc_fights   AS SELECT * FROM wh.bronze.ufc_fights;
CREATE OR REPLACE VIEW bronze_views.one_athletes AS SELECT * FROM wh.bronze.one_athletes;
CREATE OR REPLACE VIEW bronze_views.one_fights   AS SELECT * FROM wh.bronze.one_fights;

SELECT 'init views ready' AS ok;

SELECT table_schema, table_name, table_type
FROM information_schema.tables
WHERE table_schema='bronze_views'
ORDER BY 1,2;

dbs/bronze_dump_from_prod.sql
PRAGMA threads=8;
ATTACH '/media/ares/data/db/duck/warehouse/sports_ml_warehouse.duckdb' AS wh (READ_ONLY);

CREATE SCHEMA IF NOT EXISTS bronze;

DROP TABLE IF EXISTS bronze.ufc_fighters;
CREATE TABLE bronze.ufc_fighters AS SELECT DISTINCT * FROM wh.bronze.ufc_fighters;
CREATE UNIQUE INDEX IF NOT EXISTS pk_ufc_fighters ON bronze.ufc_fighters(fighter_id);

DROP TABLE IF EXISTS bronze.ufc_fights;
CREATE TABLE bronze.ufc_fights AS SELECT DISTINCT * FROM wh.bronze.ufc_fights;
CREATE UNIQUE INDEX IF NOT EXISTS pk_ufc_fights
  ON bronze.ufc_fights(fighter_id, opponent, event, round, time, method, result);

DROP TABLE IF EXISTS bronze.one_athletes;
CREATE TABLE bronze.one_athletes AS SELECT DISTINCT * FROM wh.bronze.one_athletes;

DROP TABLE IF EXISTS bronze.one_fights;
CREATE TABLE bronze.one_fights AS SELECT DISTINCT * FROM wh.bronze.one_fights;

CHECKPOINT;

SELECT 'cloned bronze.ufc_fighters' AS obj, COUNT(*) AS n FROM bronze.ufc_fighters
UNION ALL SELECT 'cloned bronze.ufc_fights',   COUNT(*) FROM bronze.ufc_fights
UNION ALL SELECT 'cloned bronze.one_athletes', COUNT(*) FROM bronze.one_athletes
UNION ALL SELECT 'cloned bronze.one_fights',   COUNT(*) FROM bronze.one_fights;

dbs/bronze_views_from_parquet.sql
PRAGMA threads=8;
CREATE SCHEMA IF NOT EXISTS bronze;

CREATE OR REPLACE VIEW bronze.ufc_fighters AS
SELECT * FROM read_parquet('/media/ares/data/db/lake/bronze/ufc/ufc_fighters/**/*.parquet',
                           hive_partitioning=true, union_by_name=true);

CREATE OR REPLACE VIEW bronze.ufc_fights AS
SELECT * FROM read_parquet('/media/ares/data/db/lake/bronze/ufc/ufc_fights/**/*.parquet',
                           hive_partitioning=true, union_by_name=true);

CREATE OR REPLACE VIEW bronze.one_athletes AS
SELECT * FROM read_parquet('/media/ares/data/db/lake/bronze/one/one_athletes*.parquet',
                           union_by_name=true);

CREATE OR REPLACE VIEW bronze.one_fights AS
SELECT * FROM read_parquet('/media/ares/data/db/lake/bronze/one/one_fights*.parquet',
                           union_by_name=true);

SELECT 'parquet views ready' AS ok;

dbs/scripts/refresh_dev_dump.sh
#!/usr/bin/env bash
set -euo pipefail
: "${DUCK_DEV_DB:?set DUCK_DEV_DB}"
: "${DUCK_WH_DB:?set DUCK_WH_DB}"

duckdb "$DUCK_DEV_DB" <<SQL
PRAGMA threads=8;
ATTACH '${DUCK_WH_DB}' AS wh (READ_ONLY);

CREATE SCHEMA IF NOT EXISTS bronze;

DROP TABLE IF EXISTS bronze.ufc_fighters;
CREATE TABLE bronze.ufc_fighters AS SELECT DISTINCT * FROM wh.bronze.ufc_fighters;
CREATE UNIQUE INDEX IF NOT EXISTS pk_ufc_fighters ON bronze.ufc_fighters(fighter_id);

DROP TABLE IF EXISTS bronze.ufc_fights;
CREATE TABLE bronze.ufc_fights AS SELECT DISTINCT * FROM wh.bronze.ufc_fights;
CREATE UNIQUE INDEX IF NOT EXISTS pk_ufc_fights
 ON bronze.ufc_fights(fighter_id, opponent, event, round, time, method, result);

DROP TABLE IF EXISTS bronze.one_athletes;
CREATE TABLE bronze.one_athletes AS SELECT DISTINCT * FROM wh.bronze.one_athletes;

DROP TABLE IF EXISTS bronze.one_fights;
CREATE TABLE bronze.one_fights AS SELECT DISTINCT * FROM wh.bronze.one_fights;

CHECKPOINT;
SQL
echo "✅ DEV bronze dumps refreshed."

dbs/scripts/make_dirs.sh
#!/usr/bin/env bash
set -euo pipefail
mkdir -p /media/ares/data/db/duck/{warehouse,dev,backups,tmp}
mkdir -p /media/ares/data/db/lake/{bronze,silver,gold}
echo "✅ folders ready."

dbs/scripts/init_env.sh
#!/usr/bin/env bash
set -euo pipefail
append() {
  grep -q "$1" ~/.bashrc || echo "$1" >> ~/.bashrc
}
append 'export DUCK_WH_DB="/media/ares/data/db/duck/warehouse/sports_ml_warehouse.duckdb"'
append 'export DUCK_DEV_DB="/media/ares/data/db/duck/dev/sports_ml_warehouse.duckdb"'
append 'export LAKE_ROOT="/media/ares/data/db/lake"'
echo "✅ env appended to ~/.bashrc (run: source ~/.bashrc)"
