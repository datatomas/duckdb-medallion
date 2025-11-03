PRAGMA threads=8;
ATTACH '/media/ares/data/db/duck/warehouse/sports_ml_wh.duckdb' AS wh (READ_ONLY);
USE wh;
EXPORT DATABASE '${SNAPSHOT_DIR}' (
  FORMAT PARQUET,
  COMPRESSION ZSTD
);
