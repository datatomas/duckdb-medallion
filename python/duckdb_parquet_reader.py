import duckdb
from pathlib import Path

# Define all datasets you want to iterate through
datasets = {
    "ufc_fighters": "/media/ares/data/db/lake/bronze/ufc/ufc_fighters.parquet",
    "ufc_fights": "/media/ares/data/db/lake/bronze/ufc/ufc_fights.parquet",
}

# Create an in-memory DuckDB connection
con = duckdb.connect(database=':memory:')

# Query template (can adapt later for each dataset)
QUERY = """
    SELECT 
        *
    FROM '{path}'
    LIMIT 10
"""

for name, path in datasets.items():
    p = Path(path)
    print(f"\n📊 Reading dataset: {name}")

    if not p.exists():
        print(f"⚠️  File not found: {p}")
        continue

    try:
        df = con.execute(QUERY.format(path=p)).df()
        print(df.to_string(index=False))
    except Exception as e:
        print(f"❌ Error reading {p}: {e}")
