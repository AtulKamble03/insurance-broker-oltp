# Insurance Broker OLTP — Project Plan

## Project Overview

| Item | Detail |
|---|---|
| **Project Name** | Insurance Broker OLTP — Learning Project |
| **Owner** | Atul Kamble |
| **Start Date** | 2026-06-02 |
| **Revised** | 2026-06-08 (pivoted from hospital to insurance broker domain) |
| **Goal** | Learn OLTP database design, ACID transactions, concurrency, and CDC through a real-world insurance broker schema |
| **GitHub Repo** | [github.com/AtulKamble03/insurance-broker-oltp](https://github.com/AtulKamble03/insurance-broker-oltp) |
| **Tech Stack** | SQL Server + SSMS |
| **Reference Project** | [COVID-19 ETL Data Warehouse](https://github.com/AtulKamble03/covid-etl-project) — OLAP counterpart |

---

## What We Are Building

A **normalised OLTP database** for an insurance broker — the kind of transactional system
that feeds an ETL pipeline like the COVID-19 warehouse.

```
Broker finds Customer
    ↓
Customer gets Quote
    ↓  (Quote accepted)
Application submitted
    ↓  (Application approved)
Enrollment created
    ↓
Policy issued
    ↓                    ↓
Claims filed        Premium payments tracked
    ↓
Claim payments settled
    ↓
Broker commission recorded
```

---

## Phase 1 — Concept Learning
**Status: ✅ Complete**

All 16 OLTP concepts learned and documented with insurance schema examples.
Reference: [`docs/concepts.md`](concepts.md)

| Concept | Done? |
|---|---|
| Denormalization — redundant FK vs redundant data values | ✅ |
| Atomicity — all steps succeed or all are undone | ✅ |
| Consistency — constraints keep data always valid | ✅ |
| Isolation — concurrent users don't corrupt each other | ✅ |
| Durability — committed data survives crashes | ✅ |
| Foreign Keys & Referential Integrity | ✅ |
| Normalization — 1NF, 2NF, 3NF with insurance examples | ✅ |
| Constraints — CHECK, UNIQUE, NOT NULL, DEFAULT | ✅ |
| Soft Delete — status column, never hard delete | ✅ |
| Indexes — speed up WHERE/JOIN/ORDER BY columns | ✅ |
| Locking — shared vs exclusive locks | ✅ |
| Isolation Levels — READ COMMITTED default, when to use SERIALIZABLE | ✅ |
| Deadlocks — how they happen, how to prevent | ✅ |
| Triggers — auto-log claim status changes | ✅ |
| Cascading — ON DELETE CASCADE, when to avoid it | ✅ |

---

## Phase 2 — Schema Design
**Status: ✅ Complete**

21-table insurance broker schema designed with team review.

| Task | Done? |
|---|---|
| Design full schema — 21 tables covering broker, customer, policy, claims, payments | ✅ |
| Review with team — validate business logic and relationships | ✅ |
| Save DBML to `docs/architecture/insurance_schema.dbml` | ✅ |
| Rename repo to `insurance-broker-oltp` on GitHub | ✅ |
| Push schema and concepts to GitHub | ✅ |

**Tables:**
```
broker              insurancecompany     insuranceplan
customer            dependent            customereligibility
quote               application          enrollment
policy              policydependent      proofdocument
claim               claimpayment         premiumpayment
commission          provider             providereligibility
network             providernetwork      contract
```

---

## Phase 3 — SQL DDL (Create Tables in SSMS)
**Status: 🔲 Not Started**

**Goal:** Translate the DBML schema into SQL Server DDL with proper constraints and indexes.

| Task | Done? |
|---|---|
| Create `insurance_db` database in SSMS | 🔲 |
| Write `sql/schema/create_tables.sql` — all 21 tables | 🔲 |
| Add CHECK constraints (status values, amount > 0, end_date > start_date) | 🔲 |
| Add indexes on high-frequency lookup columns | 🔲 |
| Run DDL in SSMS — verify all tables, FKs, constraints created | 🔲 |

**Key constraints to add:**
```sql
CHECK (status IN ('active', 'inactive', 'cancelled', 'suspended'))
CHECK (total_claimed_amount > 0)
CHECK (amount_paid <= amount_due)
CHECK (end_date > start_date)
UNIQUE (policy_number), UNIQUE (claim_number), UNIQUE (contract_number)
```

**Key indexes to add:**
```sql
idx_claim_policy       ON claim (policy_id, status)
idx_policy_customer    ON policy (customer_id, status)
idx_customer_name      ON customer (full_name)
idx_premiumpayment_due ON premiumpayment (due_date, status)
```

---

## Phase 4 — Test Data and Pre/Post State Demos
**Status: 🔲 Not Started**

**Goal:** Insert seed data and demonstrate the state of the database before and after transactions.

| Task | Done? |
|---|---|
| Write `sql/transactions/seed_data.sql` — insert brokers, companies, plans, customers | 🔲 |
| Demonstrate pre-state: query before transaction | 🔲 |
| Write full transaction: quote → application → enrollment → policy (all atomic) | 🔲 |
| Demonstrate post-state: query after COMMIT | 🔲 |
| Demonstrate rollback: introduce error mid-transaction, confirm pre-state restored | 🔲 |

---

## Phase 5 — ACID Transaction SQL
**Status: 🔲 Not Started**

**Goal:** Write real transaction SQL for key business operations. Understand commit and rollback.

| Task | Done? |
|---|---|
| Write `sql/transactions/submit_application.sql` — quote + application + eligibility check | 🔲 |
| Write `sql/transactions/issue_policy.sql` — enrollment + policy + commission record | 🔲 |
| Write `sql/transactions/file_claim.sql` — claim + claimpayment record | 🔲 |
| Write `sql/transactions/settle_claim.sql` — update claim + create claimpayment + update deductible | 🔲 |
| Write `sql/transactions/pay_premium.sql` — insert premiumpayment + update remaining balance | 🔲 |
| Test rollback on each — confirm pre-state is fully restored | 🔲 |

---

## Phase 6 — Advanced OLTP (Concurrency and Automation)
**Status: 🔲 Not Started**

**Goal:** Demonstrate isolation levels, deadlocks, and triggers in action.

| Task | Done? |
|---|---|
| Write `sql/transactions/isolation_levels.sql` — show READ COMMITTED vs SERIALIZABLE | 🔲 |
| Create deliberate deadlock — two sessions locking claim and claimpayment in opposite order | 🔲 |
| Write `sql/transactions/deadlock_demo.sql` | 🔲 |
| Create trigger — auto-log claim status changes to audit table | 🔲 |
| Write `sql/transactions/trigger_demo.sql` | 🔲 |

---

## Phase 7 — CDC (Change Data Capture)
**Status: 🔲 Not Started**

**Goal:** Capture every INSERT/UPDATE/DELETE on key tables. Understand how OLTP feeds ETL.

**Real-world connection:** In the COVID-19 project, the source was CSV files.
In production, the source is a CDC log from a system like this one.

| Task | Done? |
|---|---|
| Enable CDC on `insurance_db` | 🔲 |
| Enable CDC on `policy`, `claim`, `premiumpayment` | 🔲 |
| Insert a new policy — query CDC log to see the INSERT | 🔲 |
| Update a policy status — query CDC log to see before/after values | 🔲 |
| Write `sql/cdc/setup_cdc.sql` | 🔲 |
| Write `sql/cdc/query_changes.sql` | 🔲 |

---

## Key Files

| File | Purpose | Status |
|---|---|---|
| `docs/concepts.md` | 16 OLTP concepts with insurance examples | ✅ Done |
| `docs/architecture/insurance_schema.dbml` | Full 21-table schema | ✅ Done |
| `sql/schema/create_tables.sql` | DDL for all 21 tables | 🔲 Next |
| `sql/transactions/submit_application.sql` | ACID transaction example | 🔲 Phase 5 |
| `sql/transactions/settle_claim.sql` | ACID transaction example | 🔲 Phase 5 |
| `sql/cdc/setup_cdc.sql` | Change Data Capture setup | 🔲 Phase 7 |
