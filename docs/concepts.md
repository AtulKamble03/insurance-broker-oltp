# Core OLTP Concepts — Insurance Broker Schema

Reference document. Updated as we learn each concept.

## Quick Index

| # | Concept | One line |
|---|---|---|
| 1 | Denormalization | Store redundant data to reduce joins |
| 2 | Atomicity | All steps succeed or all are undone |
| 3 | Denormalization + Atomicity | How they relate |
| 4 | Consistency | Data is always valid — constraints enforce this |
| 5 | Isolation | Concurrent users don't corrupt each other |
| 6 | Durability | Committed data survives crashes |
| 7 | Foreign Key & Referential Integrity | Child row must point to a real parent |
| 8 | Normalization (1NF → 3NF) | Eliminate redundancy and anomalies |
| 9 | Constraints | Rules the database enforces automatically |
| 10 | Soft Delete | Mark as inactive instead of physically deleting |
| 11 | Indexes | Speed up lookups without changing data |
| 12 | Locking | Prevent two users corrupting the same row |
| 13 | Isolation Levels | How much one transaction can see of another |
| 14 | Deadlock | Two transactions blocking each other forever |
| 15 | Triggers | Automatic actions when data changes |
| 16 | Cascading | Automatically propagate changes to child rows |

---

## 1. Denormalization

**Plain English:**
Intentionally storing a copy of data that you could get via joins — so at query time, you skip those joins entirely.

**Rule of thumb:**
Use denormalization when a query runs thousands of times a day and always needs the same shortcut. Accept the redundancy for the speed gain.

**In our schema:**
`customer_id` is stored directly in `claim`, `premiumpayment`, and `claimpayment`
— even though it could be derived via `policy.customer_id`.

```sql
-- Normalized (pure): 2 joins
SELECT c.full_name
FROM claim cl
JOIN policy   p ON p.policy_id   = cl.policy_id
JOIN customer c ON c.customer_id = p.customer_id

-- Denormalized: 1 join — same result
SELECT c.full_name
FROM claim cl
JOIN customer c ON c.customer_id = cl.customer_id
```

**Trade-off:**

| | Normalized | Denormalized |
|---|---|---|
| Joins needed | Many | Few |
| Read speed | Slower | Faster |
| Update risk | Safe (one place) | Must update all copies |

---

## 2. Atomicity

**Plain English:**
A group of operations that must ALL succeed or ALL fail — nothing in between.
If any one step fails, the entire group is rolled back as if nothing happened.

**The analogy:**
Bank transfer — debit one account AND credit another. Both happen, or neither happens.
You never want one without the other.

**In our schema — example: customer submits an application:**

```sql
BEGIN TRANSACTION

  UPDATE quote SET status = 'converted' WHERE quote_id = 5001
  INSERT INTO application (quote_id, customer_id, plan_id, status)
       VALUES (5001, 201, 10, 'submitted')
  INSERT INTO customereligibility (customer_id, plan_id, status)
       VALUES (201, 10, 'pending')

COMMIT   -- all 3 saved permanently
-- or
ROLLBACK -- all 3 undone, back to pre-state
```

**Pre-state:** quote = 'draft', no application, no eligibility record
**Post-state (COMMIT):** quote = 'converted', application exists, eligibility exists
**Rollback:** database snaps back to pre-state — as if nothing happened

---

## 3. Denormalization + Atomicity — How They Relate

**Key distinction — what our schema actually denormalizes:**

Our schema stores `customer_id` (the INT primary key) in multiple tables.
`customer_id` is a surrogate key — it is assigned once and NEVER changes.
So there is NO "update all copies" problem for `customer_id`.

```
claim.customer_id        = 201  ← never changes
premiumpayment.customer_id = 201  ← never changes
claimpayment.customer_id = 201  ← never changes
customer.customer_id     = 201  ← the source — never changes
```

**If instead we stored `customer_name` in multiple tables** — THAT would create
an update problem. If the name changes, you must update every copy atomically:

```sql
-- Hypothetical bad design: name stored in 3 places
BEGIN TRANSACTION
  UPDATE claim          SET customer_name = 'Atul K.' WHERE customer_id = 201
  UPDATE premiumpayment SET customer_name = 'Atul K.' WHERE customer_id = 201
  UPDATE claimpayment   SET customer_name = 'Atul K.' WHERE customer_id = 201
COMMIT
-- If any UPDATE fails → ROLLBACK → all 3 stay as old name → consistent
```

**Our schema avoids this problem entirely** by denormalizing on the FK (immutable)
not on the actual data value. `customer_name` lives in ONE place — the `customer` table.

**Summary:**
- Denormalization on FK (customer_id) = safe, no update problem
- Denormalization on data values (customer_name) = risky, needs atomicity to stay consistent
- Our schema does the safe kind

---

## 4. Consistency

**Plain English:**
The database is always in a valid state — before and after every transaction.
No partial data, no broken rules, no impossible values.

**The analogy:**
A speedometer can't show negative speed. The car's system enforces that.
Consistency means the database enforces its own rules the same way.

**Who enforces consistency?**
Constraints — CHECK, NOT NULL, UNIQUE, FOREIGN KEY. The database rejects anything that breaks a rule.

**In our schema:**

```sql
-- claim.status can only be specific values
ALTER TABLE claim ADD CONSTRAINT chk_claim_status
CHECK (status IN ('submitted', 'under_review', 'approved', 'rejected', 'settled'));

-- A claim cannot have negative amount
ALTER TABLE claim ADD CONSTRAINT chk_claim_amount
CHECK (total_claimed_amount > 0);

-- premium_payment.amount_paid cannot exceed amount_due
ALTER TABLE premiumpayment ADD CONSTRAINT chk_payment_amount
CHECK (amount_paid <= amount_due);
```

If you try to insert a claim with `status = 'unknown'` or `total_claimed_amount = -5000`,
SQL Server rejects it immediately — database stays consistent.

---

## 5. Isolation

**Plain English:**
When two users are working at the same time, they don't interfere with each other.
Each transaction sees a clean, stable view of the data.

**The analogy:**
Two bank tellers processing different customers simultaneously.
Each teller works on their own customer's record — they don't accidentally overwrite each other.

**In our schema — real scenario:**

Two agents process claims at the same time:

```
Agent A: UPDATE claim SET status = 'approved', approved_amount = 45000 WHERE claim_id = 101
Agent B: UPDATE claim SET status = 'rejected', rejection_reason = 'duplicate' WHERE claim_id = 101
```

Without isolation: both write at the same time → one overwrites the other → corrupted data.
With isolation: SQL Server queues them — Agent B waits until Agent A's transaction finishes.

---

## 6. Durability

**Plain English:**
Once a transaction is committed, it stays committed — even if the server crashes immediately after.
The data is written to disk, not just held in memory.

**The analogy:**
Signing a contract. Once both parties sign, it's legally binding even if the office burns down
— because a copy was filed at the registry (the transaction log on disk).

**In our schema:**

```sql
BEGIN TRANSACTION
  INSERT INTO policy (policy_number, customer_id, plan_id, status)
  VALUES ('POL-2026-001', 201, 10, 'active')
COMMIT
-- Policy is now on disk. Server can restart. Policy still exists.
```

SQL Server writes every committed transaction to the **transaction log** on disk before confirming COMMIT.
This is what makes durability possible.

---

## 7. Foreign Key & Referential Integrity

**Plain English:**
A foreign key says: "this value must already exist in the parent table."
The database enforces this automatically — no orphan records allowed.

**The analogy:**
A library card system. You can only borrow a book if you have a valid membership.
The system won't let you borrow under a membership ID that doesn't exist.

**In our schema:**

```sql
-- claim.customer_id must exist in customer.customer_id
-- claim.policy_id must exist in policy.policy_id
-- claim.provider_id must exist in provider.provider_id

-- This INSERT fails automatically:
INSERT INTO claim (customer_id, policy_id, provider_id, ...)
VALUES (9999, 1, 1, ...)
-- Error: FK violation — customer_id 9999 does not exist in customer table
```

**Difference from atomicity:**

| | Foreign Key | Atomicity |
|---|---|---|
| What it does | Rejects invalid references | Rolls back all steps if one fails |
| Who controls it | Database constraint | Your BEGIN/COMMIT/ROLLBACK |
| When it fires | On every single INSERT/UPDATE | Only inside a transaction block |

---

## 8. Normalization (1NF → 3NF)

**Plain English:**
A set of rules to eliminate redundancy and anomalies from a table.
Each rule builds on the previous one.

**The three forms — using insurance examples:**

### 1NF — No repeating groups, atomic values

**Bad (violates 1NF):**
```
customer_id | plan_1      | plan_2       | plan_3
201         | Health Gold | Life Basic   | NULL
```
Problem: What if a customer has 4 plans? You need to add a column.

**Fixed (1NF):**
```
customer_id | plan_id
201         | Health Gold
201         | Life Basic
```
One row per fact. Our `enrollment` table does this correctly.

### 2NF — Every non-key column depends on the WHOLE primary key

**Bad (violates 2NF) — composite PK: (policy_id, customer_id):**
```
policy_id | customer_id | premium_amount | customer_name
```
`customer_name` depends only on `customer_id`, not on `policy_id`.
That's a partial dependency — 2NF violation.

**Fixed:** Move `customer_name` to the `customer` table.
`policy` only stores `customer_id` as FK.

### 3NF — No transitive dependencies (non-key → non-key)

**Bad (violates 3NF):**
```
broker_id | broker_name | company_id | company_name
```
`company_name` depends on `company_id`, not on `broker_id`.
That's a transitive dependency — 3NF violation.

**Fixed:** Our schema has separate `broker` and `insurancecompany` tables.
`brokerinsurancecompany` links them — no name stored twice.

---

## 9. Constraints

**Plain English:**
Rules the database enforces on every INSERT and UPDATE — automatically, without any application code.

**Types used in our schema:**

```sql
-- PRIMARY KEY: every row must be uniquely identifiable
policy_id integer PRIMARY KEY

-- UNIQUE: no two rows can have the same value
policy_number varchar UNIQUE NOT NULL
claim_number  varchar UNIQUE NOT NULL

-- NOT NULL: this column cannot be left empty
provider_name varchar NOT NULL

-- FOREIGN KEY: value must exist in parent table
customer_id integer REFERENCES customer(customer_id)

-- CHECK: value must meet a condition
CHECK (status IN ('active', 'inactive', 'suspended'))
CHECK (total_claimed_amount > 0)
CHECK (end_date > start_date)

-- DEFAULT: value if not provided
status varchar DEFAULT 'active'
created_at timestamp DEFAULT GETDATE()
```

**Why constraints matter:**
Application code can have bugs. Constraints cannot be bypassed — they protect data integrity at the lowest level.

---

## 10. Soft Delete

**Plain English:**
Instead of physically deleting a row, you mark it as inactive.
The data is preserved for audit, history, and compliance — it just doesn't appear in active queries.

**The analogy:**
An insurance company never destroys old policy files. They mark them "closed" and move them to storage.
Hard delete = shredding. Soft delete = archiving.

**In our schema — every table has `status varchar`:**

```sql
-- Hard delete (BAD for insurance — data is gone forever)
DELETE FROM policy WHERE policy_id = 10

-- Soft delete (CORRECT)
UPDATE policy SET status = 'cancelled' WHERE policy_id = 10

-- Active queries filter by status
SELECT * FROM policy WHERE status = 'active'

-- Audit queries can still see everything
SELECT * FROM policy WHERE policy_id = 10  -- cancelled policy still visible
```

**Why insurance systems always use soft delete:**
Regulators can ask for records from 10 years ago. Hard deletes destroy compliance evidence.

---

## 11. Indexes

**Plain English:**
An index is a lookup structure that lets SQL Server find rows without scanning the entire table.
Think of it as the index at the back of a book — you go straight to the page instead of reading every page.

**Without index:** SQL Server reads every row in `claim` to find claim_id = 101.
**With index:** SQL Server jumps directly to that row.

**In our schema — where indexes matter most:**

```sql
-- Customer lookups by name (broker searches for a customer)
CREATE INDEX idx_customer_name ON customer (full_name);

-- All claims for a policy (most common claim query)
CREATE INDEX idx_claim_policy ON claim (policy_id, status);

-- All policies for a customer
CREATE INDEX idx_policy_customer ON policy (customer_id, status);

-- Premium payments due (daily batch job)
CREATE INDEX idx_premiumpayment_due ON premiumpayment (due_date, status);

-- Claim by claim_number (used in every claim lookup)
-- Already covered by UNIQUE constraint — creates index automatically
```

**Rule of thumb:** Index columns you filter on (WHERE), join on (JOIN ... ON), or sort on (ORDER BY).

---

## 12. Locking

**Plain English:**
When a transaction is updating a row, SQL Server locks it so no other transaction can change it at the same time.
This prevents two users from corrupting the same record simultaneously.

**Two lock types:**

| Lock type | Who gets it | What it allows |
|---|---|---|
| Shared (S) | Readers (SELECT) | Multiple readers at once — fine |
| Exclusive (X) | Writers (INSERT/UPDATE/DELETE) | Only one writer — others must wait |

**In our schema — claim settlement:**

```sql
-- Agent A settles claim 101
BEGIN TRANSACTION
  UPDATE claim SET status = 'settled', approved_amount = 45000 WHERE claim_id = 101
  -- SQL Server places EXCLUSIVE lock on claim row 101
  -- Agent B trying to update the same row must WAIT here

  INSERT INTO claimpayment (claim_id, amount_approved, status)
  VALUES (101, 45000, 'pending')
COMMIT
-- Lock released — Agent B can now proceed
```

---

## 13. Isolation Levels

**Plain English:**
A setting that controls how much of another transaction's in-progress data your transaction can see.
More isolation = safer data, but slower (more waiting).
Less isolation = faster, but you might read data that gets rolled back.

**Four levels — from least to most strict:**

| Level | What you can see | Risk |
|---|---|---|
| READ UNCOMMITTED | Other transactions' uncommitted changes | Dirty reads — you see data that gets rolled back |
| READ COMMITTED (default) | Only committed data | Safe for most cases |
| REPEATABLE READ | Same rows return same values throughout your transaction | Prevents others updating your rows mid-transaction |
| SERIALIZABLE | Completely isolated — as if no one else exists | Slowest, safest |

**In our schema — why READ COMMITTED is right for insurance:**

```sql
-- Default: READ COMMITTED
-- Agent A reads a claim being updated by Agent B
-- Agent A waits until Agent B commits — then reads the final value
-- No dirty data, no phantom records

SET TRANSACTION ISOLATION LEVEL READ COMMITTED  -- this is already the default
SELECT * FROM claim WHERE status = 'submitted'
```

**When to use SERIALIZABLE:** Premium calculation — you cannot afford to have another transaction
insert new policies mid-calculation that change the total.

---

## 14. Deadlock

**Plain English:**
Two transactions are each waiting for the other to release a lock — so neither can proceed.
SQL Server detects this and kills one transaction (the "deadlock victim") to let the other finish.

**The analogy:**
Two cars at a single-lane bridge from opposite sides. Neither can go forward.
Someone has to reverse — SQL Server decides who reverses (rollback).

**In our schema — how it happens:**

```sql
-- Transaction A: updates claim first, then claimpayment
BEGIN TRANSACTION
  UPDATE claim        SET status = 'approved' WHERE claim_id = 101  -- locks claim 101
  UPDATE claimpayment SET status = 'approved' WHERE claim_id = 101  -- waits for B to release claimpayment

-- Transaction B (at the same time): updates claimpayment first, then claim
BEGIN TRANSACTION
  UPDATE claimpayment SET amount_paid = 45000  WHERE claim_id = 101  -- locks claimpayment 101
  UPDATE claim        SET settled_at = GETDATE() WHERE claim_id = 101 -- waits for A to release claim

-- Result: A waits for B. B waits for A. DEADLOCK.
-- SQL Server kills one, rolls it back, lets the other finish.
```

**How to prevent deadlocks:** Always access tables in the same order across all transactions.
Both A and B should update `claim` before `claimpayment` — never the reverse.

---

## 15. Triggers

**Plain English:**
A piece of SQL that fires automatically when a row is inserted, updated, or deleted.
You write it once — the database runs it every time the event happens.

**The analogy:**
An alarm system. You don't manually call the police — inserting the burglar triggers the call automatically.

**In our schema — auto-log when a claim status changes:**

```sql
CREATE TRIGGER trg_claim_status_change
ON claim
AFTER UPDATE
AS
BEGIN
  IF UPDATE(status)  -- only fires when status column changes
  BEGIN
    INSERT INTO claim_audit_log (claim_id, old_status, new_status, changed_at)
    SELECT
        d.claim_id,
        d.status       AS old_status,
        i.status       AS new_status,
        GETDATE()      AS changed_at
    FROM deleted d                        -- 'deleted' = the row BEFORE update
    JOIN inserted i ON i.claim_id = d.claim_id  -- 'inserted' = the row AFTER update
    WHERE d.status <> i.status
  END
END
```

Every time a claim moves from `submitted` → `approved` → `settled`, the log captures it automatically.
No application code needed.

---

## 16. Cascading

**Plain English:**
When you update or delete a parent row, cascading automatically applies the same change to all child rows.
You touch one row — the database handles the rest.

**The analogy:**
Cancelling a hotel booking. The hotel automatically cancels all your room service orders too.
You don't cancel each order manually.

**In our schema — if a policy is cancelled:**

```sql
-- Without cascade: you must manually delete children first
DELETE FROM claimpayment  WHERE claim_id IN (SELECT claim_id FROM claim WHERE policy_id = 10)
DELETE FROM claim         WHERE policy_id = 10
DELETE FROM premiumpayment WHERE policy_id = 10
DELETE FROM policy        WHERE policy_id = 10

-- With ON DELETE CASCADE: one delete handles all children
ALTER TABLE claim ADD CONSTRAINT fk_claim_policy
  FOREIGN KEY (policy_id) REFERENCES policy(policy_id)
  ON DELETE CASCADE

DELETE FROM policy WHERE policy_id = 10
-- SQL Server automatically deletes all claim rows for policy 10
```

**Warning:** Use cascade carefully in insurance systems. Accidental deletes cascade silently.
Most insurance systems prefer soft delete (status = 'cancelled') over hard cascade deletes.

---

## Summary — OLTP Concept Map

```
SCHEMA DESIGN                    TRANSACTION CONTROL
─────────────────                ──────────────────────────────────
Normalization (1NF→3NF)          Atomicity    — all or nothing
  └─ remove redundancy           Consistency  — always valid state
Denormalization                  Isolation    — users don't interfere
  └─ add redundancy for speed    Durability   — survives crashes
Constraints
  └─ enforce rules automatically
Soft Delete
  └─ never destroy data          PERFORMANCE & CONCURRENCY
Indexes                          ──────────────────────────────────
  └─ speed up lookups            Locking          — exclusive access
Foreign Keys                     Isolation Levels — how much to share
  └─ enforce relationships       Deadlocks        — detect and resolve
Triggers
  └─ automate on data change     AUTOMATION
Cascading                        ──────────────────────────────────
  └─ propagate changes           Triggers   — fire on INSERT/UPDATE/DELETE
                                 Cascading  — propagate to child rows
```
