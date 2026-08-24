# CASTER — Market Intelligence Pipeline

## What This Is

CASTER is a deterministic, local-first MLS data pipeline. It ingests manual
CSV exports, normalizes inconsistent field formats, and stores canonical
records with full snapshot history for point-in-time market queries.

No frontend. No API. No external consumers yet — the pipeline is the product.

MLS listing data is used under a personal-use subscriber license
(MLSListings / SAMCAR). See `README.md#data-handling-and-mls-compliance`
for the sourcing and licensing rationale — it's why this stays
local/homelab rather than a public cloud deploy.

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
- API layer deferred until an external consumer project is ready
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

All six values are enforced in code by a Rails enum on `Listing`
(`app/models/listing.rb`) and, as defense-in-depth, by a database CHECK
constraint named `listings_listing_status_check`.

Note there is no `Listing::STATUS` constant — the enum itself is the
source of truth, and Rails exposes the mapping as `Listing.listing_statuses`.

As implemented, in Rails 8.1 keyword syntax:

```ruby
enum :listing_status, {
  active:     "A",
  sold:       "S",
  pending:    "P",
  expired:    "E",
  withdrawn:  "W",
  contingent: "C"
}
```

The enum is declared without `validate: true` on purpose: assigning an
off-vocabulary value raises `ArgumentError` at assignment time rather than
being collected as a validation error, per the loud-failures principle. The
separate `validates :listing_status, presence: true` still covers nil/blank.

Only `A` and `S` occur in data today; `P`/`E`/`W`/`C` are accepted but not
yet produced by any feed.

`listing_snapshots` deliberately has neither the enum nor the constraint —
it is an append-only historical record, not a live business object.

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

All six pipeline phases are built and covered by RSpec specs. The
pipeline has also been deployed to the homelab (see Deployment below) —
that happened in the most recent commit and is not yet exercised against
a real dataset end-to-end in that environment as far as is confirmed.

### Completed

- Phase 1 — Rails scaffold + all five migrations
- Phase 2 — `FeedProfile`, `FeedColumn`, `FeedProfileValidator`
- Phase 3 — `Ingester` service, `caster:ingest` rake task
- Phase 4 — `ListingNormalizer`, `Normalizer` service, snapshot writes
- Phase 5 — `MarketSummaryQuery`, `PriceTrendQuery` (query objects, no SQL views)
- Phase 6 — `caster:run`, `caster:validate` rake tasks
- `db/seeds.rb` — `FeedProfile` + 30 `FeedColumn` rows for the MLSListings
  Matrix feed
- `listing_status` Rails enum on `Listing` + `listings_listing_status_check`
  database CHECK constraint

### Not Started / Stubbed

- Comps, absorption rate, inventory-level query objects
- Multi-feed-profile / multi-MLS-source support
- API layer (blocked on a future external-consumer project)
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

Shipped in a recent commit:

- Raw Kubernetes manifests in `k8s/dev/` (`caster.yaml`, `postgres.yaml`) —
  hand-written, not generated by Kamal
- Deploys to a `development` namespace on Watchtower, the homelab k3s cluster
- `imagePullPolicy: Never` + `docker.io/library/caster:latest` — image is
  built locally and loaded into the cluster, not pulled from a registry.
  **This is current state** — see "Next step" below for the planned change.
- Postgres uses a `hostPath` PersistentVolume (`/data/caster-postgres`) —
  homelab-local storage, not a managed database
- This is consistent with the "local-first / homelab, not public cloud"
  posture required by the MLS data license (see README)

**Next step, not yet done:** replace the `imagePullPolicy: Never` /
locally-built-image approach with a local `registry:2` container registry
running on Watchtower (fronted by Traefik), so images get pushed/pulled
through a real registry instead of relying on the image already being
present on the node. This is a decision/plan only — no manifest or
config changes for it exist in the repo yet.

**`config/deploy.yml` (Kamal) is present but unconfigured scaffold** —
placeholder IP (`192.168.0.1`), placeholder registry (`localhost:5555`).
It is not the deployment path actually in use. Treat the `k8s/dev/`
manifests as the real deployment mechanism unless/until Kamal is
deliberately wired up.

---

## Known Issues

- **CI still targets Minitest.** Both `.github/workflows/ci.yml`
  (`bin/rails db:test:prepare test`) and `config/ci.rb` (`bin/rails test`,
  run via `bin/ci`) invoke the Minitest test task. The suite was fully
  migrated to RSpec and there is no `test/` directory left. These
  commands likely no-op (0 tests, exit 0) rather than fail — meaning CI
  may be silently not running the spec suite at all. This contradicts
  the project's own "schema drift = loud failure, not silent skip"
  principle applied to itself. Worth a fix: point both at
  `bundle exec rspec`.

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

Tracked in the project's GitHub issues:

- `roadmap` — seed automation, comps/absorption/inventory queries,
  multi-feed support, API layer, scheduled ingestion
- `refactor` — Sandi/Olsen audit secondary findings (Arel.sql
  whitelist, imperative-loop cleanup, orchestrator extraction, error base
  class, status constant, CSV-header-only read)
- `parity` — convention parity with a sibling project (idiom
  comments, `.call` service convention, DI, FactoryBot, this file's depth)
- `test` — missing specs for `FeedProfileValidator` and `Ingester`

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
has not yet been confirmed — treat it as the remaining gap to close, not
as done. See External Blockers — the dataset itself isn't finalized yet
either.

---

## What CASTER Is NOT

- Not a real-time data system — manual CSV cadence is fine
- Not a frontend application — no UI, no dashboard
- Not multi-tenant — single user, single MLS source
- Not an analytics platform — query objects surface signals, nothing more
- Not deployed via Kamal — `config/deploy.yml` is unused scaffold; the real
  deploy path is the hand-written `k8s/dev/` manifests
- Not deployed to public cloud — homelab k3s only, per the MLS data license

---

## Working Agreement

These constraints apply to any agent working in this repository.

**Write-first: interview-relevant code belongs to the project owner.**
The owner writes all service objects, migrations, and test assertions
themselves — this is deliberate, to keep those skills sharp rather than
offload them.

An agent may draft:
- Config files (Rails config, CI config, `.rubocop.yml`, Docker/k8s manifests)
- Test scaffolding *skeletons* — `describe`/`context` blocks, fixture
  structure — but not the assertions inside them
- DB seeds (`db/seeds.rb`) — data, not domain logic
- Boilerplate (Gemfile entries, README updates, directory scaffolding)

An agent must **never** write, in full or in a form that would just be
accepted as-is:
- Service object bodies (`Ingester`, `Normalizer`, `ListingNormalizer`,
  `FeedProfileValidator`, a future `Pipeline` orchestrator, etc.)
- Migrations
- Test assertions (the `expect(...)` lines — scaffolding around them is fine)

**Rhythm: propose → review → micro-step.** Work in small proposed steps
with an explicit pause between them for review, not large unreviewed
jumps. Don't chain several implementation steps together and present
them as one fait accompli — stop after each step and let the owner look
before continuing.

**`# TODO(owner): implement this` markers.** When a marker like this is
left in code, it means that piece is the owner's to fill in. Never come
back later and autonomously implement what a marker was holding open —
it exists specifically to preserve that implementation path. Leave it
alone unless explicitly asked to fill it in.
