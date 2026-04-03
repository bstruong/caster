"""
normalize.py
Reads raw_listings from caster.db, applies field transformations,
and writes cleaned rows into the canonical listings table.

Usage:
    uv run python normalize.py
"""

import duckdb
import pathlib
import datetime

DB_PATH = "caster.db"
SCHEMA_PATH = "schema.sql"


def load_schema(conn: duckdb.DuckDBPyConnection) -> None:
    """Drop listings if it exists, then recreate it from schema.sql."""
    conn.execute("DROP TABLE IF EXISTS listings")
    schema_sql = pathlib.Path(SCHEMA_PATH).read_text()
    conn.execute(schema_sql)
    print(f"Schema loaded from {SCHEMA_PATH}")


def fetch_raw_rows(conn: duckdb.DuckDBPyConnection) -> list[dict]:
    """
    Fetch all rows from raw_listings as a list of dicts keyed by column name.
    Using cursor.description to recover column names without hardcoding them.
    """
    cursor = conn.execute("SELECT * FROM raw_listings")
    columns = [desc[0] for desc in cursor.description]
    rows = [dict(zip(columns, row)) for row in cursor.fetchall()]
    print(f"Fetched {len(rows)} raw rows")
    return rows


PROPERTY_TYPE_MAP = {
    "Res. Single Family": "single_family",
}


def parse_date(value: str | None) -> datetime.date | None:
    if not value:
        return None

    if isinstance(value, datetime.date):
        return value

    return datetime.datetime.strptime(value, "%m/%d/%Y").date()


def parse_int(value: str | None) -> int | None:
    if not value:
        return None

    return int(value)


def transform_row(raw: dict) -> tuple:
    """
    Transform one raw_listings row into a values tuple for insertion.

    Column order must match the INSERT statement in insert_normalized():
        listing_id, status,
        list_price, sale_price, square_feet, lot_size_sqft,
        bedrooms, full_baths, half_baths,
        property_type,
        postal_city, zip_code, area_number, area_name,
        days_on_market, age_years,
        listing_date, expiration_date, sale_date, close_date, off_market_date

    Raw column reference:
        raw["S"]                  → status (keep as-is)
        raw["MLS #"]              → listing_id (keep as-is)
        raw["Street Address"]     → street_address (keep as-is)
        raw["Price"]              → list_price (strip "$" and "," → int)
        raw["Sale Price"]         → sale_price (strip "$" and "," → int)
        raw["DOM"]                → days_on_market (already int, nullable)
        raw["Beds Total"]         → bedrooms (already int)
        raw["Bths"]               → split on "|" → full_baths (int), half_baths (int)
        raw["Sq Ft Total"]        → square_feet (strip "," → int)
        raw["Lot Size"]           → lot_size_sqft (strip " Lot SqFt" suffix and "," → int)
        raw["Postal City"]        → postal_city (keep as-is)
        raw["Property Sub Type"]  → property_type (normalize to slug, e.g. "single_family")
        raw["Age"]                → age_years (already int, nullable)
        raw["Area #"]             → area_number (cast to str)
        raw["Area Name"]          → area_name (keep as-is)
        raw["Zip Code"]           → zip_code (cast to str)
        raw["column00"]           → DROP (row index artifact)

    Date fields — all nullable, sourced via raw.get() since not all exports include them:
        raw["Listing Date"]       → listing_date    (MM/DD/YYYY)
        raw["Expiration Date"]    → expiration_date (MM/DD/YYYY)
        raw["Sale Date"]          → sale_date       (MM/DD/YYYY)
        raw["Close Date"]         → close_date      (MM/DD/YYYY)
        raw["Off Market Date"]    → off_market_date (MM/DD/YYYY)
    """

    listing_id = raw["MLS #"]
    street_address = raw["Street Address"]
    status = raw["S"]

    list_price = parse_int(raw["Price"].replace("$", "").replace(",", ""))
    sale_price = parse_int((raw.get("Sale Price") or "").replace("$", "").replace(",", ""))
    days_on_market = parse_int(raw["DOM"])
    
    bedrooms = parse_int(raw["Beds Total"])
    bathrooms = raw["Bths"].split("|")
    full_baths = int(bathrooms[0])
    half_baths = int(bathrooms[1])
    square_feet = parse_int(raw["Sq Ft Total"].replace(",", ""))
    lot_size_sqft = parse_int(raw["Lot Size"].replace(" Lot SqFt", "").replace(",", ""))

    property_type = PROPERTY_TYPE_MAP.get(raw["Property Sub Type"], raw["Property Sub Type"]) 
    age_years = parse_int(raw["Age"])
    area_number = raw["Area #"]
    area_name = raw["Area Name"]
    postal_city = raw["Postal City"]
    zip_code = raw["Zip Code"]

    listing_date = parse_date(raw["Listing Date"])
    expiration_date = parse_date(raw["Expiration Date"])
    sale_date = parse_date(raw["Sale Date"])
    close_date = parse_date(raw["Close Date"])
    off_market_date = parse_date(raw["Off Market Date"])

    return (listing_id, street_address, status,
            list_price, sale_price, square_feet, lot_size_sqft,
            bedrooms, full_baths, half_baths,
            property_type,
            postal_city, zip_code, area_number, area_name,
            days_on_market, age_years,
            listing_date, expiration_date, sale_date, close_date, off_market_date)


def insert_normalized(conn: duckdb.DuckDBPyConnection, rows: list[tuple]) -> None:
    """
    Bulk-insert transformed rows into listings using parameterized executemany.
    Column order here must match transform_row() output exactly.
    """
    conn.executemany("""
        INSERT INTO listings (
            listing_id, street_address, status,
            list_price, sale_price, square_feet, lot_size_sqft,
            bedrooms, full_baths, half_baths,
            property_type,
            postal_city, zip_code, area_number, area_name,
            days_on_market, age_years,
            listing_date, expiration_date, sale_date, close_date, off_market_date
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, rows)
    print(f"Inserted {len(rows)} rows into listings")


def sanity_check(conn: duckdb.DuckDBPyConnection) -> None:
    """Run Step 4 sanity queries and print results."""
    raw_count = conn.execute("SELECT COUNT(*) FROM raw_listings").fetchone()[0]
    row_count = conn.execute("SELECT COUNT(*) FROM listings").fetchone()[0]

    print("\nSanity checks:")
    print(f"  raw_listings : {raw_count} rows")
    print(f"  listings     : {row_count} rows")
    print(f"  counts match : {row_count == raw_count}")

    # Field is from a hardcoded list — safe to interpolate, not user input
    for field in ("listing_id", "list_price", "area_name"):
        nulls = conn.execute(
            f"SELECT COUNT(*) FROM listings WHERE {field} IS NULL"
        ).fetchone()[0]
        print(f"  nulls in {field:<15}: {nulls}")

    sample = conn.execute("""
        SELECT listing_id, list_price, square_feet, lot_size_sqft,
               full_baths, half_baths, zip_code
        FROM listings LIMIT 1
    """).fetchone()

    print(f"\n  Sample row:")
    print(f"    listing_id    = {sample[0]!r}")
    print(f"    list_price    = {sample[1]!r}  (expect int)")
    print(f"    square_feet   = {sample[2]!r}  (expect int)")
    print(f"    lot_size_sqft = {sample[3]!r}  (expect int)")
    print(f"    full_baths    = {sample[4]!r}  (expect int)")
    print(f"    half_baths    = {sample[5]!r}  (expect int)")
    print(f"    zip_code      = {sample[6]!r}  (expect str)")


def main() -> None:
    conn = duckdb.connect(DB_PATH)

    print("Step 1: Load canonical schema")
    load_schema(conn)

    print("\nStep 2: Fetch raw rows")
    raw_rows = fetch_raw_rows(conn)

    print("\nStep 3: Transform rows")
    normalized = [transform_row(raw) for raw in raw_rows]

    print("\nStep 4: Insert normalized rows")
    insert_normalized(conn, normalized)

    sanity_check(conn)

    conn.close()
    print("\nDone.")


if __name__ == "__main__":
    main()
