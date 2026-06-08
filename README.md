# Insurance Broker OLTP — Learning Project

A hands-on project to understand **transactional database design** for a real-world
insurance broker system — covering normalisation, ACID transactions, concurrency,
and OLTP fundamentals.

Built alongside the [COVID-19 ETL Data Warehouse](https://github.com/AtulKamble03/covid-etl-project)
to understand both sides of the data engineering stack — the OLTP source and the OLAP warehouse.

---

## Domain

An insurance broker connects customers to insurance companies and plans.
The system tracks the full lifecycle:

```
Broker → Customer → Quote → Application → Enrollment → Policy → Claims → Payments
```

---

## What You Will Learn

| Phase | Topic | Status |
|---|---|---|
| 1 | OLTP Concepts | ✅ Complete |
| 2 | SQL DDL — Create tables with constraints and indexes | 🔲 Next |
| 3 | Test Data — Insert seed data, understand pre/post states | 🔲 Upcoming |
| 4 | ACID Transactions — Write and test real transaction SQL | 🔲 Upcoming |
| 5 | Advanced OLTP — Triggers, deadlocks, isolation levels in action | 🔲 Upcoming |
| 6 | CDC — Change Data Capture, feed to a data warehouse | 🔲 Future |

---

## Tech Stack

| Tool | Purpose |
|---|---|
| SQL Server Developer Edition | OLTP database |
| SSMS | Query, manage, test |
| dbdiagram.io | Schema design (DBML) |
| GitHub | Version control |

---

## Schema

**21 tables** covering the full insurance broker domain.

```
broker              insurancecompany     insuranceplan
customer            dependent            customereligibility
quote               application          enrollment
policy              policydependent      proofdocument
claim               claimpayment         premiumpayment
commission          provider             providereligibility
network             providernetwork      contract
```

Full schema: [`docs/architecture/insurance_schema.dbml`](docs/architecture/insurance_schema.dbml)

---

## Repo Structure

```
insurance-broker-oltp/
├── sql/
│   ├── schema/        # CREATE TABLE scripts with constraints and indexes
│   ├── transactions/  # ACID transaction examples (pre/post state demos)
│   ├── cdc/           # Change Data Capture setup and queries
│   └── analytical/    # Analytical queries
├── docs/
│   ├── concepts.md           # 16 core OLTP concepts with insurance examples
│   ├── project-plan.md       # Phase-by-phase plan with task status
│   ├── learning-plan.md      # Learning objectives per phase
│   └── architecture/
│       └── insurance_schema.dbml   # Full 21-table schema (dbdiagram.io)
└── tests/             # Validation queries
```

---

## Key Reference

[`docs/concepts.md`](docs/concepts.md) — 16 OLTP concepts explained in plain English
with examples from this schema. Use this as your reference throughout the project.

| Concept | One line |
|---|---|
| Denormalization | Store redundant FK to avoid joins |
| Atomicity | All steps succeed or all are undone |
| Consistency | Constraints keep data always valid |
| Isolation | Concurrent users don't corrupt each other |
| Durability | Committed data survives crashes |
| Foreign Keys | Child row must point to a real parent |
| Normalization | Eliminate redundancy — 1NF → 2NF → 3NF |
| Soft Delete | Status = 'inactive', never hard delete |
| Indexes | Speed up lookups on WHERE/JOIN columns |
| Locking | Exclusive access during writes |
| Isolation Levels | READ COMMITTED is the safe default |
| Deadlocks | Always access tables in the same order |
| Triggers | Automate actions on INSERT/UPDATE/DELETE |
| Cascading | Propagate changes to child rows |

---

## OLTP vs OLAP — How This Connects to the COVID-19 Project

| | This Project (OLTP) | COVID-19 Warehouse (OLAP) |
|---|---|---|
| Purpose | Record daily operations | Analyse historical data |
| Schema style | Normalised (3NF) | Star schema (Kimball) |
| Transactions | ACID required | Bulk load only |
| Users | Agents, brokers (1000s) | Analysts (10-20) |
| Query pattern | Single row lookups | Millions-row aggregations |
| Source of data | This system IS the source | Reads from systems like this |
