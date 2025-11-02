PRAGMA threads=8;

-- Attach PROD warehouse read-only
ATTACH '/path/' AS wh (READ_ONLY);

-- Where to place the real tables in DEV:
CREATE SCHEMA IF NOT EXISTS bronze;

-- ── Materialize (overwrite if they already exist) ─────────────────────────────
DROP TABLE IF EXISTS bronze.ufc_fighters;
CREATE TABLE bronze.ufc_fighters AS
SELECT * FROM wh.bronze.ufc_fighters;

DROP TABLE IF EXISTS bronze.ufc_fights;
CREATE TABLE bronze.ufc_fights AS
SELECT * FROM wh.bronze.ufc_fights;

DROP TABLE IF EXISTS bronze.one_athletes;
CREATE TABLE bronze.one_athletes AS
SELECT * FROM wh.bronze.one_athletes;

DROP TABLE IF EXISTS bronze.one_fights;
CREATE TABLE bronze.one_fights AS
SELECT * FROM wh.bronze.one_fights;

-- Optional: stats + checkpoint (flush to disk)
ANALYZE;
CHECKPOINT;

-- Quick verification
SELECT table_schema, table_name, table_type
FROM information_schema.tables
WHERE table_schema = 'bronze'
ORDER BY 1,2;
