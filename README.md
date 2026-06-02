# Hospital Patient Records — OLTP Learning Project

A hands-on learning project to understand **transactional database design**,
**normalisation**, **ACID transactions**, **CDC**, and **OLTP → Data Warehouse migration**.

Built alongside the [COVID-19 ETL Data Warehouse project](https://github.com/AtulKamble03/covid-etl-project)
to understand both sides of the data engineering stack.

---

## What You Will Learn

| Phase | Topic | Key Concepts |
|---|---|---|
| 1 | Normalisation | 1NF → 3NF, anomalies, schema design |
| 2 | ACID Transactions | Atomicity, consistency, isolation, durability |
| 3 | Concurrency | Isolation levels, locking, deadlock detection |
| 4 | Data Migration | Legacy → 3NF, transformation, validation |
| 5 | CDC | Change Data Capture, feeding ETL pipelines |
| 6 | OLTP vs OLAP | Same data, two different schemas, different purposes |

---

## Tech Stack

| Tool | Purpose | Cost |
|---|---|---|
| SQL Server Developer Edition | OLTP database | Free |
| SSMS | Query and manage | Free |
| Synthea | Synthetic patient data generator | Free (Apache 2.0) |
| Python (optional) | Generate additional synthetic data | Free |

---

## Data Source

**Synthea** — open-source synthetic patient generator by MITRE Corporation.
- License: Apache 2.0 — no restrictions
- No real patients — 100% synthetic, HIPAA-safe
- Generates: patients, encounters, conditions, medications, providers
- Download: [synthea.mitre.org](https://synthea.mitre.org)

---

## Project Phases

### Phase 1 — Schema Design (3NF)
Design and create a normalised hospital database:
- `patients`, `doctors`, `visits`, `diagnoses`, `medications`, `prescriptions`
- Proper FK relationships, CHECK constraints, indexes

### Phase 2 — Load Synthea Data
Load synthetic patient data and map it to the 3NF schema.
Learn data transformation and migration from a flat/denormalised source.

### Phase 3 — ACID Transactions
Write SQL transactions for real hospital operations:
- Admit patient, record diagnosis, prescribe medication — all or nothing
- Test rollback scenarios

### Phase 4 — Change Data Capture (CDC)
Enable CDC on key tables. Capture INSERT/UPDATE/DELETE events.
Understand how OLTP systems feed ETL pipelines.

### Phase 5 — Mini Data Warehouse
Build a simple star schema from the OLTP tables.
Compare query complexity: 3NF (8 joins) vs star schema (2 joins).

---

## Repo Structure

```
hospital-oltp-project/
├── data/
│   ├── raw/           # Original Synthea output (not committed)
│   └── synthea/       # Processed CSV files (not committed)
├── sql/
│   ├── schema/        # CREATE TABLE scripts (3NF design)
│   ├── migration/     # Legacy → 3NF migration scripts
│   ├── transactions/  # ACID transaction examples
│   ├── cdc/           # Change Data Capture setup and queries
│   └── analytical/    # Mini star schema + analytical queries
├── docs/
│   └── architecture/  # ERD, design decisions, learning notes
├── scripts/
│   └── generate/      # Python scripts to generate additional data
└── tests/             # Validation queries
```

---

## OLTP vs OLAP — Quick Comparison

| | This Project (OLTP) | COVID-19 Warehouse (OLAP) |
|---|---|---|
| Schema | 8 normalised tables (3NF) | 5 tables (star schema) |
| Purpose | Record daily operations | Analyse historical data |
| Transactions | ACID required | Bulk load only |
| Query pattern | Precise row lookups | Millions-row aggregations |
| Users | Doctors, nurses (1000+) | Analysts (10-20) |
