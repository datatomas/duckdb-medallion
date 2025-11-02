CREATE SCHEMA IF NOT EXISTS bronze_parquet;
SET schema='bronze_parquet';

-- UFC
CREATE VIEW IF NOT EXISTS bronze_parquet.ufc_fights AS
SELECT * FROM read_parquet(
  '/media/user/data/db/lake/bronze/ufc_fights/**/*.parquet',
  union_by_name=true
);

CREATE VIEW IF NOT EXISTS bronze_parquet.ufc_fighters AS
SELECT * FROM read_parquet(
  '/media/user/data/db/lake/bronze/ufc_fighters/**/*.parquet',
  union_by_name=true
);
