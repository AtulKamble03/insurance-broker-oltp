# Core OLTP Concepts — Insurance Broker Schema

Reference document. Updated as we learn each concept.

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
