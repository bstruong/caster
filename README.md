# CASTER — Real Estate Intelligence Platform

Local-first MLS data pipeline. Ingests manual CSV exports, normalizes
inconsistent field formats, and stores canonical records with full
snapshot history for point-in-time queries.

## Stack

- **Ruby on Rails 8** — pipeline framework
- **PostgreSQL** — primary data store
- **Rake tasks** — pipeline execution

## Pipeline

```
CSV → Ingest → Validate → Normalize → Store → Snapshot → Aggregate
```

| Stage | Description |
|---|---|
| Ingest | Raw CSV row preserved as-is in `raw_listings` |
| Validate | Feed profile checked against CSV headers — loud failure on drift |
| Normalize | Raw fields mapped to canonical schema via `FeedProfile` |
| Store | Canonical record written to `listings` |
| Snapshot | Append-only record written to `listing_snapshots` |
| Aggregate | SQL views + query objects — read-only market signals |

## Status

| Phase | Description | Status |
|---|---|---|
| 1 — Rails Scaffold + Schema | Rails app + all five migrations | ✅ Complete |
| 2 — Feed Profile | `FeedProfile`, `FeedColumn`, validator | ✅ Complete |
| 3 — Ingest Layer | `RawListing` model, `Ingester` service, Rake task | ✅ Complete |
| 4 — Normalization Layer | `Normalizer`, `ListingNormalizer`, snapshots | ✅ Complete |
| 5 — Aggregate Layer | SQL views, query objects | 🔲 |
| 6 — Pipeline Wiring | End-to-end Rake tasks, structured logging | 🔲 |

## Setup

```bash
bundle install
rails db:create db:migrate
```

## Data

Manual CSV exports from MLSListings / Matrix. Place exports in `data/`.
Raw rows are preserved in `raw_listings` — never overwritten.
