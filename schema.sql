-- schema.sql
-- Canonical schema for CASTER normalized listings.
-- This is the contract. The normalizer writes to this. MCP tools read from this.

CREATE TABLE IF NOT EXISTS listings (
    listing_id        VARCHAR,        -- MLS # as-is
    street_address    VARCHAR,
    status            VARCHAR,        -- S / A / P

    list_price        INTEGER,        -- stripped of $ and commas
    sale_price        INTEGER,        -- stripped of $ and commas
    square_feet       INTEGER,        -- stripped of commas
    lot_size_sqft     INTEGER,        -- stripped of "Lot SqFt" suffix and commas

    bedrooms          INTEGER,
    full_baths        INTEGER,        -- left side of Bths split on |
    half_baths        INTEGER,        -- right side of Bths split on |

    property_type     VARCHAR,        -- normalized ("Res. Single Family" -> "single_family")

    postal_city       VARCHAR,
    zip_code          VARCHAR,        -- stored as string, never integer
    area_number       VARCHAR,        -- MLS district ID
    area_name         VARCHAR,        -- human-readable district ("Cow Hollow")

    days_on_market    INTEGER,        -- nullable
    age_years         INTEGER,        -- nullable (~40% empty in sold exports)

    listing_date      DATE,
    expiration_date   DATE,
    sale_date         DATE,
    close_date        DATE,
    off_market_date   DATE
);
