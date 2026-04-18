# CASTER — Market Intelligence Pipeline

## Stack
- Ruby on Rails + PostgreSQL
- Service objects for each pipeline stage
- Plain Ruby objects for domain logic
- ActiveRecord for persistence only
- Rake tasks or ActiveJob for pipeline execution

## Architecture
- Ingest → Validate → Normalize → Store → Snapshot → Aggregate
- Raw input preserved separately, never overwritten
- Canonical records in a separate table
- Schema drift = loud failure, not silent skip
- Snapshots are append-only — full history preserved
- Aggregates computed via SQL views and ActiveRecord query objects, read-only

## Conventions
- No API layer
- No frontend
- Business logic lives in service objects, not models

## Data Model

### Schema Overview
Five tables: `feed_profiles`, `feed_columns`, `raw_listings`,
`listings`, `listing_snapshots`

### Locked Design Decisions
- Money stored as integer cents (`bigint`) — no floats, no decimals
- Tag fields (`building_type`, `parking_features`) stored as raw `text`
- All sale-related fields nullable — pipeline supports active and sold listings
- Raw CSV rows stored as `jsonb` in `raw_listings.raw_data`
- `listing_snapshots` is append-only — no updates, no deletes

### Listing Status Vocabulary
- `A` — Active
- `S` — Sold
- `P` — Pending (anticipated)
- `E` — Expired (anticipated)
- `W` — Withdrawn (anticipated)
- `C` — Contingent (anticipated)

### Normalization Rules
- `Price`, `Sale Price` → strip `$` and commas → multiply by 100 → `bigint`
- `Bths` → split on `|` → `full_baths integer`, `half_baths integer`
- `Sq Ft Total` → strip commas → integer. `0` or blank → `null`
- `Lot Size` → strip ` Lot SqFt` and commas → integer.
  Whitespace-only or blank → `null`
- `DOM` → blank or empty string → `null`
- `Age` → blank → `null`
- `Construction Type` → blank → `null`
- All dates → parse `MM/DD/YYYY` → `date`. Blank → `null`
- `S` column → map to `listing_status`
- `Bths` is the only raw column that maps to two canonical fields —
  splitting logic lives in the normalizer, not the feed_columns definition

### feed_profiles
- id
- name                    string, not null
- source_identifier       string, not null
- description             string
- created_at
- updated_at

### feed_columns
- id
- feed_profile_id         references feed_profiles, not null
- raw_column_name         string, not null
- canonical_field_name    string, not null
- required                boolean, default false
- created_at

### raw_listings
- id
- feed_profile_id         references feed_profiles, not null
- raw_data                jsonb, not null
- source_file             string
- ingested_at             timestamp, not null

### listings
- id
- raw_listing_id          references raw_listings, not null
- mls_number              string, not null, unique
- listing_status          string, not null
- street_address          string, not null
- city                    string, not null
- state                   string, not null
- zip_code                string, not null
- latitude                decimal(10, 7)
- longitude               decimal(10, 7)
- mls_area_id             string
- mls_area_name           string
- property_type           string
- property_sub_type       string
- bedrooms                integer
- full_baths              integer
- half_baths              integer
- sq_ft_total             integer
- lot_size_sqft           integer
- age_years               integer
- construction_type       string
- building_type           text
- parking_features        text
- parking_spaces          integer
- garage_spaces           integer
- list_price_cents        bigint, not null
- sale_price_cents        bigint
- listed_at               date, not null
- expires_at              date
- sale_agreed_at          date
- off_market_at           date
- closed_at               date
- days_on_market          integer
- created_at
- updated_at

### listing_snapshots
- id
- listing_id              references listings, not null
- raw_listing_id          references raw_listings, not null
- snapshot_date           date, not null
- listing_status          string, not null
- list_price_cents        bigint, not null
- sale_price_cents        bigint
- days_on_market          integer
- created_at

## Implementation Plan

### Phase 1 — Rails Scaffold + Database Schema
- `rails new caster --database=postgresql --skip-action-mailer
  --skip-action-mailbox --skip-action-text --skip-active-storage
  --skip-action-cable --skip-javascript`
- Migrations in dependency order: feed_profiles → feed_columns →
  raw_listings → listings → listing_snapshots
- Indexes, constraints, and foreign keys enforced at DB level
- No business logic yet — schema only

### Phase 2 — Feed Profile
- `FeedProfile` model — defines expected columns for a given MLS feed
- `FeedColumn` model — individual column definitions
- Plain Ruby object: `FeedProfileValidator` — compares CSV headers
  against profile, raises on drift
- Loud failure: unknown or missing required columns raise, never
  skip silently

### Phase 3 — Ingest Layer
- `RawListing` model — preserves original CSV row as jsonb
- Service object: `Ingester` — reads CSV, persists each row to
  `raw_listings`
- No transformation here — raw data lands exactly as received
- Rake task: `caster:ingest[file_path]`

### Phase 4 — Normalization Layer
- Service object: `Normalizer` — maps raw fields to canonical schema
  via `FeedProfile`
- Plain Ruby object: `ListingNormalizer` — field-by-field
  transformation logic
- Persists canonical record to `listings`
- Persists snapshot to `listing_snapshots` (append-only)
- Raw record untouched after normalization

### Phase 5 — Aggregate Layer
- SQL views: `market_summary`, `price_trends`, `inventory_levels`
- ActiveRecord query objects: `MarketSummaryQuery`, `PriceTrendQuery`
- Read-only — no writes in this layer
- Queryable via Rails console

### Phase 6 — Pipeline Wiring
- Rake task: `caster:run[file_path]` — orchestrates full pipeline
  end to end
- Calls: Ingester → FeedProfileValidator → Normalizer → aggregates
  refreshed
- Structured logging at each stage
- Rake task: `caster:validate[file_path]` — validation only, surfaces
  drift without ingesting
