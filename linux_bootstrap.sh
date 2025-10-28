#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# 0) One-time folder structure (split layout on single 1.6TB disk)
# ---------------------------------------------------------------------------

echo "🧱 Creating base directories..."
mkdir -p /media/user/data/db/{duck/warehouse,duck/backups,lake/{bronze,silver,gold}}
mkdir -p /media/user/data/db/duck/tmp

# ---------------------------------------------------------------------------
# 1) Environment setup (no hardcoded paths)
# ---------------------------------------------------------------------------

echo "⚙️  Setting up environment variables in ~/.bashrc..."

if ! grep -q "DUCKDB_PATH" ~/.bashrc; then
cat <<'EOF' >> ~/.bashrc

# >>> DuckDB / Lakehouse Environment >>>
export DUCKDB_WH_PATH="/media/user/data/db/duck/warehouse/warehouse.duckdb"
export DUCKDB_DEV_PATH="/media/user/data/db/duck/warehouse/warehouse.duckdb"
export LAKE_ROOT="/media/user/data/db/lake"
export DUCK_TMP="/media/user/data/db/duck/tmp"
# <<< DuckDB / Lakehouse Environment <<<
EOF
fi

# Reload env to current session
source ~/.bashrc

echo "✅ DUCKDB_PATH: $DUCKDB_PATH"
echo "✅ LAKE_ROOT:   $LAKE_ROOT"
 
