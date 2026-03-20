# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "fastmcp>=2.0.0",
#     "duckdb>=1.2.0",
# ]
# ///
"""
CASTER — Real Estate Intelligence Platform
MCP Tool Server

Entry point for all agent-facing analytical tools.
Uses DuckDB for in-process OLAP queries against local Parquet files.

Run with:
    uv run server.py
"""

import duckdb
import fastmcp
from pathlib import Path
from typing import Annotated

# ---------------------------------------------------------------------------
# Server initialization
# ---------------------------------------------------------------------------

mcp = fastmcp.FastMCP(
    name="CASTER",
    instructions=(
        "You are a real estate market intelligence assistant. "
        "Use the available tools to query MLS listing data and surface "
        "actionable pricing and inventory signals by geography."
    ),
)

# ---------------------------------------------------------------------------
# DuckDB connection — single in-process instance, thread-safe for reads
# ---------------------------------------------------------------------------

DB = duckdb.connect(database=":memory:", read_only=False)

# Default Parquet path — override via environment variable in production
LISTINGS_PARQUET = Path(__file__).parent / "data" / "listings.parquet"


def _ensure_sample_data() -> None:
    """
    Bootstraps a minimal in-memory Parquet file for local development.
    In production, this is replaced by a real MLS export on disk or in S3.

    DuckDB can query remote Parquet via:
        SELECT * FROM read_parquet('s3://bucket/listings/*.parquet')
    """
    if LISTINGS_PARQUET.exists():
        return  # Real data present — skip synthetic generation

    LISTINGS_PARQUET.parent.mkdir(parents=True, exist_ok=True)

    DB.execute("""
        COPY (
            SELECT
                zip_code,
                list_price,
                bedrooms,
                bathrooms,
                sqft,
                days_on_market,
                listing_status
            FROM (VALUES
                ('90210', 2850000, 4, 3.5, 3200, 12, 'active'),
                ('90210', 3100000, 5, 4.0, 4100, 5,  'active'),
                ('90210', 2650000, 3, 2.5, 2800, 22, 'active'),
                ('10001', 1250000, 2, 2.0, 1100, 8,  'active'),
                ('10001', 1475000, 3, 2.0, 1400, 14, 'active'),
                ('10001', 980000,  1, 1.0, 750,  3,  'active'),
                ('78701', 625000,  3, 2.5, 2100, 18, 'active'),
                ('78701', 540000,  2, 2.0, 1800, 31, 'active'),
                ('78701', 710000,  4, 3.0, 2600, 9,  'active')
            ) AS t(zip_code, list_price, bedrooms, bathrooms, sqft,
                   days_on_market, listing_status)
        ) TO ? (FORMAT PARQUET)
    """, [str(LISTINGS_PARQUET)])

    print(f"[CASTER] Sample Parquet written to {LISTINGS_PARQUET}")


# ---------------------------------------------------------------------------
# MCP Tools
# ---------------------------------------------------------------------------

@mcp.tool()
def get_market_signal(
    zip_code: Annotated[str, "5-digit US ZIP code to query (e.g. '90210')"],
) -> dict:
    """
    Returns aggregate pricing and inventory signals for a given ZIP code.

    Executes an OLAP query directly against a local Parquet file using
    DuckDB's vectorized columnar engine — no separate database server required.

    Returns average list price, median list price, active listing count,
    and average days on market for all active listings in the ZIP.
    """
    _ensure_sample_data()

    parquet_path = str(LISTINGS_PARQUET)

    result = DB.execute("""
        SELECT
            zip_code,
            COUNT(*)                            AS active_listings,
            ROUND(AVG(list_price), 2)           AS avg_list_price,
            ROUND(MEDIAN(list_price), 2)        AS median_list_price,
            ROUND(AVG(days_on_market), 1)       AS avg_days_on_market,
            ROUND(AVG(list_price / NULLIF(sqft, 0)), 2) AS avg_price_per_sqft
        FROM read_parquet(?)
        WHERE zip_code = ?
          AND listing_status = 'active'
        GROUP BY zip_code
    """, [parquet_path, zip_code]).fetchone()

    if result is None:
        return {
            "zip_code": zip_code,
            "error": "No active listings found for this ZIP code.",
            "signal": None,
        }

    columns = [
        "zip_code",
        "active_listings",
        "avg_list_price",
        "median_list_price",
        "avg_days_on_market",
        "avg_price_per_sqft",
    ]

    signal = dict(zip(columns, result))

    # Simple derived signal: buyer vs. seller market heuristic
    # DOM < 15 days → seller's market; > 30 days → buyer's market
    dom = signal["avg_days_on_market"]
    if dom < 15:
        market_condition = "seller"
    elif dom > 30:
        market_condition = "buyer"
    else:
        market_condition = "balanced"

    return {
        "zip_code": zip_code,
        "signal": {
            **signal,
            "market_condition": market_condition,
        },
    }


# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    print("[CASTER] Starting MCP server...")
    print(f"[CASTER] Parquet source: {LISTINGS_PARQUET}")
    mcp.run()
