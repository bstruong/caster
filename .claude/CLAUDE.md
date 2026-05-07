# CASTER — Market Intelligence Pipeline

## What This Is

CASTER is a deterministic, local-first MLS data pipeline. It ingests manual
CSV exports, normalizes inconsistent field formats, and stores canonical
records with full snapshot history for point-in-time market queries.

No frontend. No API. No external consumers yet — the pipeline is the product.

---

## Stack

- Ruby on Rails 8
- PostgreSQL
- Service objects for each pipeline stage
- Plain Ruby objects for domain logic
- ActiveRecord for persistence only
- Rake tasks for pipeline execution
- RSpec for testing (specs in `spec/`, fixtures in `spec/fixtures/`)

---

## Architecture

```
CSV → Ingest → Validate → Normalize → Store → Snapshot → Aggregate
```

| Stage | Responsibility |
|---|---|
| Ingest | Raw CSV row preserved as-is in `raw_listings` |
| Validate | Feed profile checked against CSV headers — loud failure on drift |
| Normalize | Raw fields mapped to canonical schema via `FeedProfile` |
| Store | Canonical record written to `listings` |
| Snapshot | Append-only record written to `listing_snapshots` |
| Aggregate | Query objects — read-only market signals |

Principles:

- Raw input preserved separately, never overwritten
- Canonical records in a separate table from raw input
- Schema drift = loud failure, not silent skip
- Snapshots are append-only — full history preserved
- Aggregates computed via ActiveRecord query objects, read-only

---

## Conventions

- No frontend
- Business logic lives in service objects, not models
- API layer deferred until ARCHER (external consumer) is ready
- All analytical queries handled by PostgreSQL — no DuckDB

---

## Data Model

### Schema Overview

Five tables: `feed_profiles`, `feed_columns`, `raw_listings`, `listings`,
`listing_snapshots`.

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
  splitting logic lives in the normalizer, not the `feed_columns` definition

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

---

## Current State

All six phases complete. Pipeline is tested end-to-end with real MLSListings
Matrix CSV exports.

### Completed

- Phase 1 — Rails scaffold + all five migrations
- Phase 2 — `FeedProfile`, `FeedColumn`, `FeedProfileValidator`
- Phase 3 — `Ingester` service, `caster:ingest` rake task
- Phase 4 — `ListingNormalizer`, `Normalizer` service, snapshot writes
- Phase 5 — `MarketSummaryQuery`, `PriceTrendQuery` (query objects, no SQL views)
- Phase 6 — `caster:run`, `caster:validate` rake tasks

### Rake Tasks

- `caster:run[file_path]` — full pipeline: validate → ingest → normalize
- `caster:validate[file_path]` — validation only, no ingestion
- `caster:ingest[file_path]` — ingest only, no normalization

### Query Objects

- `MarketSummaryQuery.new(zip_code:, area_name:, status: "A").call`
  Returns: listing count, avg/median list price, avg DOM, avg price/sqft
- `PriceTrendQuery.new(zip_code:, area_name:, status: "A").call`
  Returns: 12 monthly data points with avg/median price, DOM, list-to-sale ratio

---

## Roadmap

### Next

- Seed data automation — `db/seeds.rb` for `FeedProfile` and `FeedColumn`
  records so environment setup is repeatable without manual console work
- Six audit secondary findings (S1–S6) documented in
  `~/.claude/projects/-home-brian-projects-caster/memory/project_audit_findings.md`
  — small, mostly independent cleanups (Arel.sql whitelist, status constants,
  validator error base class, etc.)

### Future

- Additional query objects (comps, absorption rate, inventory levels)
- Support for multiple feed profiles / MLS sources
- API layer — deferred until ARCHER (external consumer) is ready
- Scheduled ingestion

---

## What CASTER Is NOT

- Not a real-time data system — manual CSV cadence is fine
- Not a frontend application — no UI, no dashboard
- Not multi-tenant — single user, single MLS source
- Not an analytics platform — query objects surface signals, nothing more
