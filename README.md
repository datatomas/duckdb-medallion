🦆 Duck Lakehouse (Medallion) – README

A practical DuckDB lakehouse implementation showing how to build a dev/prod workflow with the medallion architecture (Bronze → Silver → Gold). No clusters, no services—just DuckDB, Parquet files, and SQL.
What This Repo Shows
This is a working example of how to structure a local analytics stack using DuckDB's embedded database alongside a Parquet-based data lake. It demonstrates:

Dev/Prod separation - Work safely in a development catalog while keeping production data intact
Multiple data access patterns - Views over Parquet files, physical table dumps, and read-through views
Medallion architecture - Bronze (raw), Silver (cleaned), Gold (aggregated) layers
Zero infrastructure - Single-file databases, no servers, no authentication

The repo includes real SQL scripts, Python utilities, and shell helpers that handle common data engineering tasks on a single machine.
Project Structure
duckdb-medallion/
├── README.md
├── python/
│   ├── duckdb_init.py                    # Initialize production warehouse
│   ├── duckdb_parquet_reader.py          # Utility for reading Parquet files
│ ── sql/
│       ├── dev_init_bronze_catalog.sql   # Clone PROD bronze → DEV (editable tables)
│       ├── duckdb_views_prod_to_dev.sql  # Create read-through views in DEV → PROD
│       └── duckdb_views_from_parquet.sql # Create views over Parquet lake
├── scripts/
│   ├── init_env.sh                       # Set up environment variables
                  # Create directory structure
Quick Start
1. Clone and Set Up Directories
bashgit clone https://github.com/yourusername/duckdb-medallion.git
cd duckdb-medallion

# Create lakehouse directories
bash scripts/make_dirs.sh
```

This creates:
```
/media/ares/data/db/
├── duck/
│   ├── warehouse/          # Production catalog
│   ├── dev/                # Development catalog
│   ├── backups/            # Database backups
│   └── tmp/                # Temporary files
└── lake/
    ├── bronze/             # Raw Parquet files
    ├── silver/             # Cleaned data
    └── gold/               # Aggregated metrics
2. Configure Environment
bash# Set up environment variables
bash scripts/init_env.sh
source ~/.bashrc
This adds to your shell:
bashexport DUCK_WH_DB="/media/ares/data/db/duck/warehouse/sports_ml_warehouse.duckdb"
export DUCK_DEV_DB="/media/ares/data/db/duck/dev/sports_ml_warehouse.duckdb"
export LAKE_ROOT="/media/ares/data/db/lake"
3. Initialize Production Warehouse
bash# Create the production DuckDB catalog
python dbs/duckdb_init.py
This script:

Creates the warehouse database file
Sets up the bronze schema
Configures performance settings (threads, memory limits)
Establishes the base structure for your lakehouse

4. Verify Setup
bash# Check production database
duckdb "$DUCK_WH_DB" -c "
  PRAGMA database_list;
  SELECT schema_name FROM information_schema.schemata ORDER BY 1;
"
Three Ways to Work with Data
Pattern 1: Views Over Parquet (The Lake)
Create views that read directly from Parquet files. New files are picked up automatically.
bashduckdb "$DUCK_WH_DB" -init dbs/sql/duckdb_views_from_parquet.sql
duckdb_views_from_parquet.sql:
sqlPRAGMA threads=8;
CREATE SCHEMA IF NOT EXISTS bronze;

CREATE OR REPLACE VIEW bronze.ufc_fighters AS
SELECT * FROM read_parquet('/media/ares/data/db/lake/bronze/ufc/ufc_fighters/**/*.parquet',
                          hive_partitioning=true, 
                          union_by_name=true);

CREATE OR REPLACE VIEW bronze.ufc_fights AS
SELECT * FROM read_parquet('/media/ares/data/db/lake/bronze/ufc/ufc_fights/**/*.parquet',
                          hive_partitioning=true, 
                          union_by_name=true);
Query immediately:
bashduckdb "$DUCK_WH_DB" -c "
  SELECT COUNT(*) FROM bronze.ufc_fighters;
  SELECT * FROM bronze.ufc_fights LIMIT 5;
"
Pattern 2: Read-Through Views (DEV → PROD)
Create views in DEV that point to PROD tables. Read-only, zero storage in DEV.
bashduckdb "$DUCK_DEV_DB" -init dbs/sql/duckdb_views_prod_to_dev.sql
duckdb_views_prod_to_dev.sql:
sqlPRAGMA threads=8;
ATTACH '/media/ares/data/db/duck/warehouse/sports_ml_warehouse.duckdb' AS wh (READ_ONLY);

CREATE SCHEMA IF NOT EXISTS bronze_views;

CREATE OR REPLACE VIEW bronze_views.ufc_fighters AS 
SELECT * FROM wh.bronze.ufc_fighters;

CREATE OR REPLACE VIEW bronze_views.ufc_fights AS 
SELECT * FROM wh.bronze.ufc_fights;

CREATE OR REPLACE VIEW bronze_views.one_athletes AS 
SELECT * FROM wh.bronze.one_athletes;

CREATE OR REPLACE VIEW bronze_views.one_fights AS 
SELECT * FROM wh.bronze.one_fights;
Check what's available:
bashduckdb "$DUCK_DEV_DB" -c "
  SELECT table_schema, table_name, 'VIEW' AS table_type
  FROM information_schema.views
  WHERE table_schema = 'bronze_views'
  ORDER BY 1,2;
  
  SELECT COUNT(*) FROM bronze_views.ufc_fighters;
"
Pattern 3: Physical DEV Copies (Editable)
Clone PROD tables into DEV as physical, editable copies. Perfect for experimentation.
bashduckdb "$DUCK_DEV_DB" -init dbs/sql/dev_init_bronze_catalog.sql
dev_init_bronze_catalog.sql:
sqlPRAGMA threads=8;
ATTACH '/media/ares/data/db/duck/warehouse/sports_ml_warehouse.duckdb' AS wh (READ_ONLY);

CREATE SCHEMA IF NOT EXISTS bronze;

-- Clone tables with deduplication
DROP TABLE IF EXISTS bronze.ufc_fighters;
CREATE TABLE bronze.ufc_fighters AS 
SELECT DISTINCT * FROM wh.bronze.ufc_fighters;
CREATE UNIQUE INDEX IF NOT EXISTS pk_ufc_fighters ON bronze.ufc_fighters(fighter_id);

DROP TABLE IF EXISTS bronze.ufc_fights;
CREATE TABLE bronze.ufc_fights AS 
SELECT DISTINCT * FROM wh.bronze.ufc_fights;
CREATE UNIQUE INDEX IF NOT EXISTS pk_ufc_fights 
  ON bronze.ufc_fights(fighter_id, opponent, event, round, time, method, result);

DROP TABLE IF EXISTS bronze.one_athletes;
CREATE TABLE bronze.one_athletes AS 
SELECT DISTINCT * FROM wh.bronze.one_athletes;

DROP TABLE IF EXISTS bronze.one_fights;
CREATE TABLE bronze.one_fights AS 
SELECT DISTINCT * FROM wh.bronze.one_fights;

CHECKPOINT;
Now you have editable tables:
bashduckdb "$DUCK_DEV_DB" -c "
  SELECT table_schema, table_name, table_type
  FROM information_schema.tables
  WHERE table_schema='bronze'
  ORDER BY 1,2;
  
  -- These are real tables you can modify
  UPDATE bronze.ufc_fighters SET weight_class = 'Lightweight' WHERE fighter_id = 123;
"
Common Workflows
Working in DEV
bash# Open DEV database
duckdb "$DUCK_DEV_DB"
sql-- Attach PROD for comparison
ATTACH '/media/ares/data/db/duck/warehouse/sports_ml_warehouse.duckdb' AS wh (READ_ONLY);

-- Compare row counts
SELECT 'DEV' AS env, COUNT(*) FROM bronze.ufc_fights
UNION ALL
SELECT 'PROD', COUNT(*) FROM wh.bronze.ufc_fights;

-- Test transformations in DEV
CREATE TABLE silver.fight_stats AS
SELECT 
    fight_id,
    event_date,
    fighter_a,
    fighter_b,
    winner,
    CAST(round AS INTEGER) as round_num
FROM bronze.ufc_fights
WHERE event_date >= '2020-01-01';
Refreshing DEV from PROD
bash# Re-run the clone script to sync DEV with latest PROD data
duckdb "$DUCK_DEV_DB" -init dbs/sql/dev_init_bronze_catalog.sql

# Verify
duckdb "$DUCK_DEV_DB" -c "
  SELECT COUNT(*) AS fighters FROM bronze.ufc_fighters;
  SELECT COUNT(*) AS fights FROM bronze.ufc_fights;
"
Reading Parquet Directly
bash# Ad-hoc query without any database
duckdb -c "
  SELECT * 
  FROM read_parquet('/media/ares/data/db/lake/bronze/ufc/ufc_fighters.parquet')
  LIMIT 10;
"
Using Python
python# dbs/duckdb_parquet_reader.py
import duckdb

# Connect to warehouse
con = duckdb.connect('/media/ares/data/db/duck/warehouse/sports_ml_warehouse.duckdb')

# Query bronze layer
fighters = con.execute("""
    SELECT fighter_name, weight_class, wins, losses
    FROM bronze.ufc_fighters
    WHERE wins > 10
    ORDER BY wins DESC
    LIMIT 20
""").df()

print(fighters)

# Direct Parquet read
parquet_data = con.execute("""
    SELECT * 
    FROM read_parquet('/media/ares/data/db/lake/bronze/ufc/ufc_fighters/*.parquet')
""").df()
```

## Medallion Architecture in Practice

### Bronze Layer: Raw Data

Parquet files as ingested from source systems. Immutable, append-only.
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
Silver Layer: Cleaned Data (Coming Soon)
Validated, deduplicated, with data quality rules applied.
sql-- Example: dbs/sql/silver_fight_stats.sql
CREATE TABLE silver.fight_stats AS
SELECT 
    fight_id,
    event_date,
    fighter_a_id,
    fighter_b_id,
    winner_id,
    method,
    CAST(round AS INTEGER) as round_num
FROM bronze.ufc_fights
WHERE fight_id IS NOT NULL
  AND event_date >= '2020-01-01'
  AND method IS NOT NULL;
Gold Layer: Business Metrics (Coming Soon)
Aggregated, denormalized tables for analytics.
sql-- Example: dbs/sql/gold_win_rates.sql
CREATE TABLE gold.fighter_win_rates AS
SELECT 
    fighter_name,
    COUNT(*) as total_fights,
    SUM(CASE WHEN result = 'win' THEN 1 ELSE 0 END) as wins,
    ROUND(100.0 * wins / total_fights, 2) as win_rate_pct
FROM silver.fight_stats
GROUP BY fighter_name
HAVING total_fights >= 5
ORDER BY win_rate_pct DESC;
Useful Commands
Database Inspection
sql-- List all schemas
SELECT schema_name FROM information_schema.schemata ORDER BY 1;

-- List all tables and views
SELECT table_schema, table_name, table_type
FROM information_schema.tables
ORDER BY 1,2;

-- Show table definition
.schema bronze.ufc_fighters

-- Check current database
PRAGMA database_list;
Performance Tuning
sql-- Set memory limit
SET memory_limit='4GB';

-- Set thread count
SET threads=8;

-- Optimize tables
VACUUM;
ANALYZE;
CHECKPOINT;
Data Export
bash# Export to CSV
duckdb "$DUCK_WH_DB" -c "
  COPY (SELECT * FROM bronze.ufc_fighters) 
  TO '/tmp/fighters.csv' (HEADER, DELIMITER ',');
"

# Export to Parquet
duckdb "$DUCK_WH_DB" -c "
  COPY (SELECT * FROM gold.fighter_win_rates) 
  TO '/tmp/win_rates.parquet' (FORMAT PARQUET, COMPRESSION SNAPPY);
"
Maintenance
Backups
bash# Simple file copy (DuckDB is a single file)
cp $DUCK_WH_DB "/media/ares/data/db/duck/backups/warehouse_$(date +%Y%m%d).duckdb"
Monitoring Size
bash# Check database file size
du -sh /media/ares/data/db/duck/warehouse/*.duckdb

# Check lake size
du -sh /media/ares/data/db/lake/*
Troubleshooting
"Conflicting lock is held"
bash# Close all DuckDB sessions, then check for locks
ls -la /media/ares/data/db/duck/warehouse/*.lock
rm /media/ares/data/db/duck/warehouse/*.lock  # if safe
Views show 0 rows
sql-- Verify the ATTACH path
PRAGMA database_list;

-- Check if source file exists
SELECT * FROM wh.bronze.ufc_fighters LIMIT 1;
Parquet views empty
bash# Verify files exist
ls -lh /media/ares/data/db/lake/bronze/ufc/ufc_fighters/

# Test direct read
duckdb -c "SELECT COUNT(*) FROM read_parquet('/media/.../ufc_fighters.parquet');"
Why This Pattern Works
For Local Development

Test with production-sized datasets without cloud costs
Experiment freely in DEV without affecting PROD
Instant feedback loop (queries run in milliseconds)

For Small to Medium Production

No infrastructure to manage
Scales to 100GB+ on a single machine
Easy backups (copy one file)
Version control SQL transformations

For Learning Data Engineering

See medallion architecture in practice
Understand dev/prod separation
Learn SQL optimization techniques
No complex setup required

What DuckDB Is (and Isn't)
DuckDB is:

An embedded analytical database (like SQLite for analytics)
Columnar, vectorized, and fast on a single machine
Perfect for OLAP workloads, data science, and ETL
MIT licensed and free

DuckDB is not:

A transactional database (use Postgres for OLTP)
A distributed system (use Spark/Snowflake for true big data)
A real-time streaming engine (use Kafka/Flink for streaming)

Next Steps
This repo demonstrates the foundation. Future additions will include:

ML pipelines - Feature engineering from Silver/Gold layers
dbt integration - Declarative transformations with testing
Data quality checks - Great Expectations validation
Scheduling - Cron jobs or Airflow DAGs
Docker deployment - Containerized workflows
Azure Functions - Serverless analytics endpoints

License
MIT - Use this however you want.
Contributing
This is a learning project, but contributions welcome. Open an issue or PR if you have improvements.

Built to show that powerful analytics don't require complex infrastructure.RetryClaude does not have the ability to run the code it generates yet.Claude can make mistakes. Please double-check responses.
