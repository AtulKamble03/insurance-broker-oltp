# Learning Plan — Insurance Broker OLTP

Learning objectives per phase. Use this alongside `concepts.md` as a reference.

---

## Phase 1 — OLTP Concepts ✅ Complete

All concepts documented in [`docs/concepts.md`](concepts.md) with insurance schema examples.

| Concept | What you learned |
|---|---|
| Denormalization | Storing `customer_id` in `claim` directly — avoids joins, safe because FK never changes |
| Atomicity | Quote + Application + Eligibility — all committed together or all rolled back |
| Consistency | CHECK constraints enforce valid status values and amounts at DB level |
| Isolation | Two agents updating the same claim — SQL Server queues them safely |
| Durability | COMMIT writes to disk — policy survives a server crash |
| Foreign Keys | `claim.customer_id` must exist in `customer` — DB rejects orphan records |
| Normalization | 1NF: one row per fact / 2NF: no partial dependencies / 3NF: no transitive deps |
| Constraints | CHECK, UNIQUE, NOT NULL, DEFAULT — rules enforced without application code |
| Soft Delete | `status = 'cancelled'` — never hard delete in insurance (regulatory compliance) |
| Indexes | Index `policy_id` on `claim` — direct lookup instead of full table scan |
| Locking | EXCLUSIVE lock during UPDATE — other writers wait, readers may proceed |
| Isolation Levels | READ COMMITTED is the default — safe for most insurance operations |
| Deadlocks | Always update `claim` before `claimpayment` — never reverse the order |
| Triggers | Auto-log every claim status change — no application code needed |
| Cascading | Use carefully — prefer soft delete over ON DELETE CASCADE in insurance |

---

## Phase 2 — Schema Design ✅ Complete

| What | Detail |
|---|---|
| Schema | 21 tables — broker, customer, quote, application, enrollment, policy, claim, payments, provider, network, commission |
| Designed with | Team review |
| Key patterns learned | Junction tables (brokerinsurancecompany, policydependent, providernetwork), soft delete on every table, business keys alongside surrogate PKs |
| Saved to | `docs/architecture/insurance_schema.dbml` |

---

## Phase 3 — SQL DDL 🔲 Next

**Goal:** Translate the DBML schema into executable SQL Server DDL.

**What you will learn:**
- `CREATE TABLE` with all constraint types in SQL Server syntax
- Difference between `INT IDENTITY` (surrogate) and `VARCHAR UNIQUE` (business key)
- How indexes are created and why column order in a composite index matters
- How FK constraints are defined and what `ON DELETE` options mean

---

## Phase 4 — Test Data and Pre/Post States 🔲 Upcoming

**Goal:** See the database change state before and after a transaction.

**What you will learn:**
- How to write `INSERT` statements for related tables in dependency order
- What the database looks like before (pre-state) and after (post-state) a transaction
- How `ROLLBACK` restores the exact pre-state — down to the last row
- Why `SCOPE_IDENTITY()` is used to link a newly inserted parent to its child

---

## Phase 5 — ACID Transaction SQL 🔲 Upcoming

**Goal:** Write and run real business transactions — quote submission, policy issuance, claim settlement.

**What you will learn:**
- `BEGIN TRANSACTION / COMMIT / ROLLBACK` syntax
- `TRY / CATCH` block for error handling inside transactions
- How to deliberately break a step and observe the rollback
- How FK violations trigger automatic rollback

**Key transactions to write:**

| Transaction | Tables touched |
|---|---|
| Submit application | quote, application, customereligibility |
| Issue policy | enrollment, policy, commission |
| File claim | claim, claimpayment |
| Settle claim | claim, claimpayment, policy (deductible) |
| Pay premium | premiumpayment, policy |

---

## Phase 6 — Advanced OLTP 🔲 Upcoming

**Goal:** Experience concurrency, deadlocks, and triggers hands-on in SSMS.

**What you will learn:**
- Open two SSMS sessions simultaneously — simulate two agents working on the same claim
- Set isolation levels per session — see what each level allows or blocks
- Create a deliberate deadlock — watch SQL Server pick a victim and roll it back
- Write a trigger — see it fire automatically on every status change, no manual call needed

---

## Phase 7 — CDC (Change Data Capture) 🔲 Future

**Goal:** Capture every data change in the OLTP system. Understand how this feeds an ETL pipeline.

**What you will learn:**
- Enable CDC at database and table level (`sp_cdc_enable_db`, `sp_cdc_enable_table`)
- Query the CDC change log (`cdc.fn_cdc_get_all_changes_...`)
- Understand LSN (Log Sequence Number) — how CDC tracks position in the transaction log
- How an ETL job reads from the CDC log instead of doing full table scans
- Connection to the COVID-19 warehouse — in production, the source would be CDC, not CSV files

---

## How This Connects to the COVID-19 Project

```
COVID-19 project (already built):
  CSV files → SSIS ETL → Star Schema (OLAP) → Power BI

Insurance broker project (building now):
  This system IS the OLTP source
  Its CDC log → ETL pipeline → Data Warehouse → Analytics

In production at Veradigm:
  Source OLTP (like this) → CDC → SSIS/ADF → Data Warehouse → Reports
```

Understanding both sides — the OLTP source and the OLAP warehouse —
is what makes you a complete data engineer.
