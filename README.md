# CASTER — Real Estate Intelligence Platform

Local-first MLS data platform. Ingests manual CSV exports, normalizes 
inconsistent field formats, and exposes market signal tools via FastMCP 
for agent-driven natural language queries.

## Status

| Phase | Step | Status |
|---|---|---|
| 1 — Data Foundation | Step 1: Ingest raw CSV → DuckDB | ✅ Complete |
| 1 — Data Foundation | Step 2: Canonical schema (schema.sql) | ✅ Complete |
| 1 — Data Foundation | Step 3: Python normalizer | ✅ Complete |
| 1 — Data Foundation | Step 4: Load normalized data + sanity queries | ✅ Complete |
| 2 — Agent Integration | Step 5: LLM schema mapper | 🔲 |
| 2 — Agent Integration | Step 6: Harden MCP tools | 🔲 |
| 3 — Close the Loop | Step 7: agent.py query loop | 🔲 |
| 3 — Close the Loop | Step 8: README rewrite + resume bullets | 🔲 |

## Stack

- **DuckDB** — in-process analytical query engine
- **FastMCP** — typed MCP tool server for agent integration
- **Claude Haiku** — schema normalization + natural language queries
- **uv** — package and environment management

## Setup
```bash
uv sync
uv run python ingest.py data/CASTER_2.csv
uv run server.py
```

## Data

Manual CSV export from MLSListings / Matrix. Place exports in `data/`.
`caster.db` is gitignored — regenerate via `ingest.py`.

### Known limitations

- **Zip Code** — DuckDB infers this column as `BIGINT` during CSV ingest, which would silently drop leading zeros (e.g. `01234` → `1234`). Current MLS exports cover SF Bay Area zip codes which all start with `9`, so this is not an issue today. If coverage expands to other regions, force the column to `VARCHAR` in `ingest.py`.
