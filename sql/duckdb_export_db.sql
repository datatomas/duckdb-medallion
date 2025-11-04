
-- export_to_dev.sql
-- Run this while connected to: /home/ares/data/db/duck/warehouse/sports_ml_warehouse.duckdb
-- Usage: duckdb /home/ares/data/db/duck/warehouse/sports_ml_warehouse.duckdb < export_to_dev.sql

-- ============================================================================
-- STEP 1: EXPORT TO TEMP DIRECTORY
-- ============================================================================
EXPORT DATABASE '/tmp/duckdb_export_sports_ml' (FORMAT PARQUET);

-- ============================================================================
-- STEP 2: ATTACH DEV DATABASE AND IMPORT
-- ============================================================================
ATTACH '/home/ares/data/db/duck/warehouse/dev_sports_ml_wh.duckdb' AS dev;

IMPORT DATABASE '/tmp/duckdb_export_sports_ml' INTO dev;

-- ============================================================================
-- STEP 3: OPTIMIZE AND CHECKPOINT
-- ============================================================================
CHECKPOINT dev;
