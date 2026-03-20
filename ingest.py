import argparse
import duckdb

def main():
    parser = argparse.ArgumentParser(description="Ingest a raw MLS CSV export into caster.db")
    parser.add_argument("csv_path", help="Path to the MLS CSV file (e.g. data/CASTER_2.csv)")
    args = parser.parse_args()

    conn = duckdb.connect("caster.db")

    conn.execute("DROP TABLE IF EXISTS raw_listings")

    conn.execute("""
        CREATE TABLE raw_listings AS
        SELECT * FROM read_csv_auto(?)
    """, [args.csv_path])

    row_count = conn.execute("SELECT COUNT(*) FROM raw_listings").fetchone()[0]
    print(f"Rows loaded: {row_count}")

    print("\nInferred schema:")
    for row in conn.execute("DESCRIBE raw_listings").fetchall():
        print(f"  {row[0]:<30} {row[1]}")

if __name__ == "__main__":
    main()

