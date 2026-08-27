# CASTER — Market Intelligence Pipeline

## What This Is

CASTER is a deterministic, local-first MLS data pipeline. It ingests manual
CSV exports, normalizes inconsistent field formats, and stores canonical
records with full snapshot history for point-in-time market queries.

No frontend. No API. No external consumers yet — the pipeline is the product.

MLS listing data is used under a personal-use subscriber license (MLSListings
/ SAMCAR). See `README.md#data-handling-and-mls-compliance` for the sourcing
and licensing rationale — it's why this stays local/homelab rather than a
public cloud deploy.

---

## Stack

- Ruby 3.4.8, Ruby on Rails 8.1.3
- PostgreSQL (16 in local Docker Compose, 15-alpine in the k3s deployment)
- Service objects for each pipeline stage
- Plain Ruby objects for domain logic
- ActiveRecord for persistence only
- Rake tasks for pipeline execution
- RSpec for testing (specs in `spec/`, fixtures in `spec/fixtures/`) —
  fully migrated off Minitest; no `test/` directory remains

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
`listing_snapshots`. Verified against `db/schema.rb` (version
`2026_04_18_013157`).

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

No `Listing::STATUS` constant exists yet — status codes above are
convention only, not enforced in code (tracked as issue S5/D5).

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
  splitting logic lives in `ListingNormalizer#baths_pair`, not the
  `feed_columns` definition

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
- mls_number               string, not null, unique
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

All six pipeline phases are built and covered by RSpec specs. The pipeline
has also now been deployed to the homelab (see Deployment below) — that
happened in the most recent commit and is not yet exercised against a real
dataset end-to-end in that environment as far as this audit could confirm.

### Completed

- Phase 1 — Rails scaffold + all five migrations
- Phase 2 — `FeedProfile`, `FeedColumn`, `FeedProfileValidator`
- Phase 3 — `Ingester` service, `caster:ingest` rake task
- Phase 4 — `ListingNormalizer`, `Normalizer` service, snapshot writes
- Phase 5 — `MarketSummaryQuery`, `PriceTrendQuery` (query objects, no SQL views)
- Phase 6 — `caster:run`, `caster:validate` rake tasks

### Not Started / Stubbed

- `db/seeds.rb` — default Rails scaffold comment only, no `FeedProfile`/
  `FeedColumn` seed data (tracked as issue R1)
- `Listing::STATUS` constant / enum — status codes are convention-only today.
  **Planned, not yet implemented:** a Rails enum on `Listing`, verified
  against the current `listing_status` string column and its documented
  vocabulary (see Listing Status Vocabulary above):

  ```ruby
  enum listing_status: {
    active:      "A",
    sold:        "S",
    pending:     "P",
    expired:     "E",
    withdrawn:   "W",
    contingent:  "C"
  }
  ```

  No migration needed — `listing_status` is already a `string` column
  storing these raw values (confirmed in `db/schema.rb` and
  `spec/fixtures/listings.yml`, which use `A`/`S` today). Do not add this
  to `app/models/listing.rb` until asked.
- Comps, absorption rate, inventory-level query objects
- Multi-feed-profile / multi-MLS-source support
- API layer (blocked on ARCHER)
- Scheduled ingestion

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

## Deployment

Deployed to **Watchtower**, the homelab k3s cluster (earlier commit messages
used the name "THRONE" — left as-is in git history, not repeated here):

- The deployment manifests live in the **homelab-k3s** repo, not in this one:
  `manifests/watchtower/caster/` (9 files — app Deployment/Service/IngressRoute
  plus cert, and Postgres StatefulSet/PV/Service/init-ConfigMap plus
  SealedSecret)
- Deploys to the `caster` namespace
- `registry.watchtower.local/caster:latest` with `imagePullPolicy: Always` —
  images are built locally, pushed to the Watchtower registry, and pulled from
  it by the cluster
- Postgres runs as a StatefulSet backed by a `hostPath` PersistentVolume
  (`/mnt/appdata/caster/postgres`, 20Gi) — homelab-local storage, not a
  managed database
- This is consistent with the "local-first / homelab, not public cloud"
  posture required by the MLS data license (see README)

The local `registry:2` registry on Watchtower, fronted by Traefik, is live and
is the image path actually in use — deployed in homelab-k3s commit `82aabb3`.

**`config/deploy.yml` (Kamal) is present but unconfigured scaffold** —
placeholder IP (`192.168.0.1`), placeholder registry (`localhost:5555`). It is
not the deployment path in use, and neither is anything in this repo — the real
deployment mechanism is the homelab-k3s manifests listed above.

---

## Known Issues (found during this audit, not yet tracked as GitHub issues)

- **CI still targets Minitest.** Both `.github/workflows/ci.yml`
  (`bin/rails db:test:prepare test`) and `config/ci.rb` (`bin/rails test`,
  run via `bin/ci`) invoke the Minitest test task. The suite was fully
  migrated to RSpec (commit `8953743`) and there is no `test/` directory
  left. These commands likely no-op (0 tests, exit 0) rather than fail —
  meaning CI may be silently not running the spec suite at all. This
  contradicts the project's own "schema drift = loud failure, not silent
  skip" principle applied to itself. Worth a fix: point both at
  `bundle exec rspec`.
- **Dead memory-file reference.** The previous version of this file linked
  the S1–S6 audit findings to
  `~/.claude/projects/-home-brian-projects-caster/memory/project_audit_findings.md`.
  That path does not exist on this machine (no such project memory
  directory was found). The real, verified source of truth for that
  backlog is the GitHub issue tracker (see Roadmap below) — use that
  instead.

---

## External Blockers

- **MLS Matrix custom export field template is not finalized, and
  historical data has not been exported yet.** This is time-sensitive:
  it needs to happen before the MLS membership expires, independent of
  any code work here. Not something this repo's state can confirm or
  refute — documented as stated. Blocks getting real data into the
  pipeline regardless of how done the code is.

---

## Roadmap

Tracked in [GitHub issues](https://github.com/bstruong/caster/issues),
verified present at audit time:

- `roadmap` (R1–R7) — seed automation, comps/absorption/inventory queries,
  multi-feed support, API layer, scheduled ingestion
- `refactor` (S1–S6) — Sandi/Olsen audit secondary findings (Arel.sql
  whitelist, imperative-loop cleanup, orchestrator extraction, error base
  class, status constant, CSV-header-only read)
- `parity` (D1–D6) — convention parity with sibling project SABER (idiom
  comments, `.call` service convention, DI, FactoryBot, this file's depth;
  D5 = S5)
- `test` (T1–T2) — missing specs for `FeedProfileValidator` and `Ingester`

Cross-project view: [Personal Workboard](https://github.com/users/bstruong/projects/3).

The refactor wave's four primary items already shipped: `ListingNormalizer`
driven off `feed_columns`, `ListingScope`/`Cents` extraction, snapshot
creation extracted from `Normalizer`, and the send-dispatch registry
replacing case-on-type. Open items above are smaller cleanups.

---

## Definition of Done

Deployed to the homelab (Watchtower k3s cluster) and running the full
pipeline end-to-end against a fixed, finite, manually-exported MLS
dataset. The deployment infrastructure is now in place (see Deployment);
running the real pipeline against a real dataset inside that environment
has not been confirmed by this audit — treat it as the remaining gap to
close, not as done. See External Blockers below — the dataset itself
isn't finalized yet either.

---

## What CASTER Is NOT

- Not a real-time data system — manual CSV cadence is fine
- Not a frontend application — no UI, no dashboard
- Not multi-tenant — single user, single MLS source
- Not an analytics platform — query objects surface signals, nothing more
- Not deployed via Kamal — `config/deploy.yml` is unused scaffold; the real
  deploy path is the homelab-k3s `manifests/watchtower/caster/` manifests
- Not deployed to public cloud — homelab k3s only, per the MLS data license
