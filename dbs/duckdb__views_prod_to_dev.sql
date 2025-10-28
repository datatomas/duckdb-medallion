PRAGMA threads=8;

-- Attach PROD warehouse as read-only
ATTACH '/media/user/data/db/duck/warehouse/sports_ml_warehouse.duckdb' AS wh (READ_ONLY);

-- Keep read-through views separate from any local tables
CREATE SCHEMA IF NOT EXISTS bronze_views;

CREATE OR REPLACE VIEW bronze_views.ufc_fighters AS SELECT * FROM wh.bronze.ufc_fighters;
CREATE OR REPLACE VIEW bronze_views.ufc_fights   AS SELECT * FROM wh.bronze.ufc_fights;
CREATE OR REPLACE VIEW bronze_views.one_athletes AS SELECT * FROM wh.bronze.one_athletes;
CREATE OR REPLACE VIEW bronze_views.one_fights   AS SELECT * FROM wh.bronze.one_fights;

SELECT 'init views ready' AS ok;

-- quick list (tables + views)
SELECT table_schema, table_name, table_type
FROM information_schema.tables
WHERE table_schema='bronze_views'
ORDER BY 1,2;
