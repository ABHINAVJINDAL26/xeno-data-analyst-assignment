# Comm-Log Send Reconciliation

**Xeno Data Analyst Internship — Take-Home Assignment**

Reconciles the October 2026 `target_base` metric for merchant `501`'s Diwali campaigns against the finance-reported figure of **22**, starting from a naive count and working through the retry-chain and approval-status logic that explains the gap.

---

## TL;DR

| | |
|---|---|
| **Merchant** | 501 |
| **Period** | October 2026 |
| **Campaigns** | All Diwali campaigns |
| **Finance-reported `target_base`** | 22 |
| **Naive query result** | 30 |
| **Reproduced result** | **22** ✅ |

---

## Repository Structure

```
.
├── README.md                   # this file — write-up and findings
├── investigation_queries.sql   # every query run during the investigation, in order
├── final_reconciliation.sql    # single query that returns target_base = 22
└── data/
    ├── comm_log.db              # SQLite database (campaign, communication_log)
    ├── campaign.csv              # same data, CSV form
    └── communication_log.csv     # same data, CSV form
```

---

## How to Reproduce

**Option A — SQLite:**

```bash
sqlite3 data/comm_log.db
.read final_reconciliation.sql
```

**Option B — any SQL client:** open `data/comm_log.db` (e.g. DB Browser for SQLite) and run the contents of `final_reconciliation.sql` directly. It returns a single column, `target_base`, with the value `22`.

All queries used along the way — including the ones that were later reasoned away — are in `investigation_queries.sql`, in the order they were run.

---

## Objective

Finance's `target_base` metric answers: *for a given underlying communication (a campaign plus every retry chained off it), how many distinct customers were reached?* This repo reproduces that number from the raw data rather than taking it on faith, and documents every adjustment made to get there.

---

## Data

### `campaign`

One row per campaign. A campaign can be a retry of an earlier campaign, tracked via `parent_id`.

| Column | Meaning |
|---|---|
| `id` | Campaign id |
| `merchant_id` | Owning merchant |
| `parent_id` | If set, this campaign is a retry of `parent_id`. `NULL` means not a retry of anything (it may still have its own retries pointing at it) |
| `name` | Human-readable label |
| `creation_status` | Approval workflow state (`approved`, `approval_awaiting`, …) |
| `processing_status` | Send-pipeline state (`processed` = finished) |

### `communication_log`

One row per individual send attempt.

| Column | Meaning |
|---|---|
| `id` | Row id |
| `merchant_id` | Owning merchant |
| `communication_id` | FK → `campaign.id` |
| `customer_id` | Customer targeted |
| `communication_type` | `'2'` = Campaign (only type in scope) |
| `delivery_status` | `900` = delivered, `1100` = soft failure |
| `sent_time` / `scheduled_time` | Timestamps |
| `credit_used` | Billing credits |
| `channel` | Send channel |

### Reporting Rules

1. Scope: merchant `501`, October 2026, `communication_type = '2'`.
2. A campaign only counts toward reporting once `creation_status` is finalized (`approved`, `aborted`, `resumed`, or `stopped`) **and** `processing_status = 'processed'`. A campaign still `approval_awaiting` does not count, even if send rows already exist for it.
3. If campaign B has `parent_id = A`, B is a retry of the same underlying communication as A. A chain can be more than two levels deep.
4. For a retry chain, a customer who took several attempts to finally get delivered (or never delivered) still counts **once** for that chain.
5. A campaign with no retry chain at all (nothing points at it, and it points at nothing) is standalone — every send under it is its own event, even if the same customer appears more than once.

---

## Campaign Map

| Campaign | Parent | Name | Status |
|---|---|---|---|
| 9001 | — | Diwali Cart Recovery – Wave 1 | approved / processed |
| 9002 | 9001 | Diwali Cart Recovery – Retry A | approved / processed |
| 9003 | 9002 | Diwali Cart Recovery – Retry B | approved / processed |
| 9004 | 9001 | Diwali Cart Recovery – Retry C (pending) | **approval_awaiting** / processed |
| 9101 | — | Diwali Flash Sale – Standalone | approved / processed |
| 9201 | — | Diwali Wave 2 | approved / processed |
| 9202 | 9201 | Diwali Wave 2 – Retry | approved / processed |

Two retry chains exist — `9001 → 9002 → 9003` ("Family A") and `9201 → 9202` ("Family B") — plus one standalone campaign (`9101`) and one campaign not yet eligible for reporting (`9004`).

---

## Investigation

### 1. Start with the naive count

The first pass was a flat row count with no business rules applied — just merchant, month, and communication type.

```
Naive count = 30
```

### 2. Check campaign eligibility

Inspecting `campaign` shows `9004` has `creation_status = approval_awaiting`, while every other campaign is `approved`. Per rule #2, `9004` doesn't count toward reporting yet, even though 4 rows already exist for it in `communication_log` (customers C11–C14) — the send pipeline ran ahead of the approval workflow.

```
Count after excluding 9004 = 26
```

### 3. Map the retry chains

Checking `parent_id` across all 7 campaigns confirms the two retry chains and the standalone campaign described above.

**Family A (`9001 → 9002 → 9003`):** `C2` and `C3` each appear more than once in this chain. Tracing the full history: `C3` failed under `9001`, failed again under `9002`, and finally delivered under `9003`; `C2` failed under `9001` and delivered on retry under `9002`. Per rule #4, each is one underlying communication reaching one customer — not three.

```
Family A distinct customers = 10   (13 raw rows)
```

**Family B (`9201 → 9202`):** `D1` failed under `9201` and delivered on retry under `9202`. `D2`–`D5` delivered on the first attempt.

```
Family B distinct customers = 5   (6 raw rows)
```

### 4. Standalone campaign 9101

`9101` has no parent and nothing points at it, so rule #5 applies — every send counts individually.

```
Standalone events = 7
```

Customer `C20` appears twice under `9101` — delivered Oct 10, delivered again Oct 20. There's no failed attempt and no chained campaign row between them, so this isn't a retry; it's a genuine re-target, and per rule #5 both sends count separately.

### 5. Reconciliation Bridge

| Step | Description | Result | Reason |
|---|---|---|---|
| 0 | Naive count of all `communication_log` rows for merchant 501, October 2026 | 30 | Starting point — no adjustments |
| 1 | Excluded campaign 9004 (4 rows) | 26 | `creation_status = approval_awaiting` — never cleared approval |
| 2 | Collapsed Family A (9001→9002→9003) — 13 rows → 10 distinct customers | 23 | Same underlying communication retried across the chain |
| 3 | Collapsed Family B (9201→9202) — 6 rows → 5 distinct customers | 22 | Same logic as Family A |
| final | Left standalone 9101 untouched (7 rows) | **22** | No retry chain; repeated customer is a genuine re-target, not a retry |

**10 (Family A) + 5 (Family B) + 7 (standalone 9101) = 22**

---

## Final Query

See `final_reconciliation.sql`. Run as-is against `data/comm_log.db`:

```
target_base = 22
```

---

## What Surprised Me

- **Campaign 9004 had send activity before it was approved.** Four rows already existed in `communication_log` for a campaign still sitting at `creation_status = approval_awaiting`. This was the adjustment that mattered most — missing it would have landed the count at 26, not 22.
- **A repeated customer isn't always a retry.** `C20`'s two sends under standalone campaign `9101` looked, at first glance, like the same kind of duplicate that needed collapsing in the retry chains. It took checking the actual rows (delivery status, timestamps, absence of a chained campaign) to confirm it was a legitimate second send, not a retry. Applying the retry-collapsing logic outside of actual `parent_id` chains would have silently under-counted this campaign.

The bigger risk in this kind of reconciliation isn't missing an adjustment — it's applying the right adjustment to the wrong scope.

---

## Notes / Limitations

- The investigation is scoped to the data provided in `data/comm_log.db`; no assumptions were made about campaigns or customers outside merchant 501 / October 2026.
- Queries were run and verified in DB Browser for SQLite; all reported result counts were confirmed against actual query output, not estimated.
- `final_reconciliation.sql` intentionally avoids CTEs/recursion — with only 7 campaigns in scope, the retry chains were mapped by hand from `investigation_queries.sql` (Step 2) and referenced directly by ID, which keeps the final query simple to read and verify.
