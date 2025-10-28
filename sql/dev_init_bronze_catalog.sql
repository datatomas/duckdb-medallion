-- duckdb_dev_init_bronze.sql
PRAGMA threads=8;

-- Attach the warehouse (READ_ONLY) with a literal path
ATTACH '/media/user/data/db/duck/warehouse/sports_ml_warehouse.duckdb' AS wh (READ_ONLY);

-- Create dev schema (physical copies live here)
CREATE SCHEMA IF NOT EXISTS bronze;

-- Fresh copies (drop → create) so we never duplicate
DROP TABLE IF EXISTS bronze.ufc_fighters;
CREATE TABLE bronze.ufc_fighters AS
SELECT DISTINCT * FROM wh.bronze.ufc_fighters;
CREATE UNIQUE INDEX IF NOT EXISTS pk_ufc_fighters
  ON bronze.ufc_fighters(fighter_id);

DROP TABLE IF EXISTS bronze.ufc_fights;
CREATE TABLE bronze.ufc_fights AS
SELECT DISTINCT * FROM wh.bronze.ufc_fights;
CREATE UNIQUE INDEX IF NOT EXISTS pk_ufc_fights
  ON bronze.ufc_fights (fighter_id, opponent, event, round, time, method, result);




CHECKPOINT;

-- Optional quick counts (handy when running with -init)
SELECT 'bronze.ufc_fighters' AS obj, COUNT(*) AS n FROM bronze.ufc_fighters
UNION ALL SELECT 'bronze.ufc_fights',       COUNT(*) FROM bronze.ufc_fights
