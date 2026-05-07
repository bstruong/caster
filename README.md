# Real Estate Market Intelligence Platform: MLS Data Pipeline

MLS data pipeline. Ingests manual CSV exports, normalizes inconsistent field formats, and stores canonical records with full snapshot history for point-in-time queries.

## Data handling and MLS compliance

This project processes MLS listing data exported from MLSListings, the multiple listing service that serves SAMCAR (San Mateo County Association of REALTORS) and surrounding Northern California associations. MLS listing data is provided under a limited, personal-use license to subscribed real estate professionals. Subscribers hold a revocable license to use the data for purposes permitted under the rules of their MLS; they do not own the underlying data.

For this reason, this project is intentionally designed to run locally only:

- All ingestion, normalization, and storage happens on a single developer machine
- No cloud deployments, no managed databases, no external sync of MLS exports
- Sample CSVs and ingestion logs are excluded from version control via `.gitignore`
- This project is not an IDX, VOW, or syndication implementation, and it does not display, distribute, or share MLS data with any third party

Any extension of this project to cloud infrastructure would require explicit authorization from MLSListings under their vendor or licensee program. The design choices documented here reflect the conservative posture of a personal-use subscriber, not legal interpretation.

**Source documents:**

- [MLSListings Terms of Service](https://about.mlslistings.com/more/terms)
- [NAR Virtual Office Websites Policy](https://www.nar.realtor/handbook-on-multiple-listing-policy/virtual-office-websites-policy-governing-use-of-mls-data-in-connection-with-internet-brokerage)
- [MLSListings Copyright and Intellectual Property Policy](https://www.mlslistings.com/more/copyright-intellectual-property-policy)

## Stack

- **Ruby on Rails 8** — pipeline framework
- **PostgreSQL** — primary data store
- **Rake tasks** — pipeline execution
- **RSpec** — test framework (`bundle exec rspec`)

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
| Aggregate | Query objects — read-only market signals |

## Status

| Phase | Description | Status |
|---|---|---|
| 1 — Rails Scaffold + Schema | Rails app + all five migrations | ✅ Complete |
| 2 — Feed Profile | `FeedProfile`, `FeedColumn`, validator | ✅ Complete |
| 3 — Ingest Layer | `RawListing` model, `Ingester` service, Rake task | ✅ Complete |
| 4 — Normalization Layer | `Normalizer`, `ListingNormalizer`, snapshots | ✅ Complete |
| 5 — Aggregate Layer | `MarketSummaryQuery`, `PriceTrendQuery` | ✅ Complete |
| 6 — Pipeline Wiring | `caster:run`, `caster:validate`, full pipeline wiring | ✅ Complete |

## Setup

```bash
bundle install
rails db:create db:migrate
rails db:seed
```

## Usage

```bash
# Run full pipeline
rails caster:run[path/to/export.csv]

# Validate only (no ingestion)
rails caster:validate[path/to/export.csv]

# Query market data (Rails console)
MarketSummaryQuery.new(zip_code: "94131").call
MarketSummaryQuery.new(area_name: "Sunnyside", status: "S").call
PriceTrendQuery.new(zip_code: "94131").call
```

## Data

Manual CSV exports from MLSListings / Matrix. Place exports in `data/`.
Raw rows are preserved in `raw_listings` — never overwritten.

## Roadmap

| Item | Priority |
|---|---|
| Seed data automation (`db/seeds.rb`) | Next |
| Additional query objects (comps, absorption rate, inventory) | Future |
| Support for multiple feed profiles / MLS sources | Future |
| API layer (blocked on downstream consumer) | Future |
| Scheduled ingestion | Future |

## Refactoring backlog

Quality cleanup items from a Sandi Metz / Russ Olsen audit. Four primary
refactors shipped (`ListingNormalizer` driven off `feed_columns`,
`ListingScope` and `Cents` extraction, snapshot creation extracted from
`Normalizer`, send-dispatch registry replacing case-on-type). Six
secondary findings remain:

| ID | Item | File |
|---|---|---|
| S1 | Whitelist `Arel.sql` interpolation in `date_field` | `app/models/price_trend_query.rb` |
| S2 | Replace imperative array build with `each_with_object`; consider yielding rows | `app/services/ingester.rb` |
| S3 | Extract `Pipeline` orchestrator; deduplicate `FeedProfile.first!` lookups | `lib/tasks/caster.rake` |
| S4 | Collapse two `pluck` queries via `partition`; add shared error base class | `app/services/feed_profile_validator.rb` |
| S5 | Extract `Listing::STATUS` constant for status code single-source-of-truth | `app/models/listing.rb` |
| S6 | Stop reading entire CSV just to get headers | `lib/tasks/caster.rake` |

Suggested order: S5 → S1 → S4 → S2 → S3 + S6 (smallest scope and most pedagogical first).
