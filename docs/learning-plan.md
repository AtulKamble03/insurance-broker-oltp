# Learning Plan — OLTP, Normalisation & Database Migration

This is the full learning plan for this project.
The same plan is also referenced in the COVID-19 ETL project at:
`covid-etl-project/docs/learning-plan-oltp.md`

---

## What We Cover

### Phase 1 — Normalisation (Theory + Practice)
- **Why normalise?** Update anomalies, insert anomalies, delete anomalies
- **1NF:** Atomic values, no repeating groups
- **2NF:** No partial dependencies (full dependency on composite PK)
- **3NF:** No transitive dependencies (non-key → non-key)
- **BCNF, 4NF, 5NF:** Brief overview (3NF is the production target)
- **Exercise:** Split the legacy flat table into proper 3NF

**Real-world analogy:** A hospital form with "Medication 1, Medication 2, Medication 3" columns
violates 1NF. Separate medications table = correct design.

---

### Phase 2 — ACID Transactions
- **Atomicity:** All or nothing (prescribe drug + update inventory = both or neither)
- **Consistency:** Data always valid (balance can't go negative)
- **Isolation:** Concurrent users don't corrupt each other's work
- **Durability:** Committed data survives crashes
- **Isolation levels:** READ UNCOMMITTED → SERIALIZABLE
- **Locking:** Shared vs exclusive locks, deadlock detection

---

### Phase 3 — Data Migration
- **Legacy → 3NF:** Map flat tables to normalised schema
- **Transformation rules:** How to handle messy source data
- **Validation:** Row counts, FK checks, spot checks
- **Rollback plan:** What if step N fails?
- **Migration strategies:** Big bang vs phased vs parallel run vs strangler fig

---

### Phase 4 — Data Synchronisation & CDC
- **Why sync?** EHR + Lab + Pharmacy all need same patient data
- **Sync strategies:** Replication, CDC, message queues, API sync, ETL batch
- **CDC in SQL Server:** sp_cdc_enable_db, sp_cdc_enable_table, query change log
- **How CDC feeds ETL:** Connection between OLTP and data warehouse

---

### Phase 5 — OLTP vs OLAP (Connecting Both Projects)
- Same patient visit data in 3NF vs star schema
- Query complexity comparison
- When to use which
- How ETL bridges the two

---

## Data Source

**Synthea** — https://synthea.mitre.org
- Apache 2.0 license — completely free
- Generates 100% synthetic patients (no PHI, no HIPAA concerns)
- Outputs: patients.csv, encounters.csv, conditions.csv, medications.csv, providers.csv
- Same spirit as OWID for the COVID-19 project — open data, real codes, fake people

---

## Project Deliverables

| Deliverable | File location |
|---|---|
| 3NF schema DDL | `sql/schema/create_tables.sql` |
| Legacy flat table | `sql/migration/legacy_table.sql` |
| Migration scripts | `sql/migration/migrate_to_3nf.sql` |
| ACID transactions | `sql/transactions/patient_admission.sql` |
| CDC setup | `sql/cdc/enable_cdc.sql` |
| Mini star schema | `sql/analytical/star_schema.sql` |
| Analytical queries | `sql/analytical/report_queries.sql` |
| Validation tests | `tests/validate_migration.sql` |
