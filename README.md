# Comm-Log Send Reconciliation

Xeno Data Analyst Internship — Take-Home Assignment

## Objective

Reconcile the October 2026 communication log for merchant `501` against the finance-provided target base of `22`.

The investigation starts with the most naive count and then applies the required business rules step by step.

## Data Used

The analysis uses:

- `comm_log.db`
- `campaign.csv`
- `communication_log.csv`

The SQLite database contains two relevant tables:

- `campaign`
- `communication_log`

The `communication_id` in `communication_log` links to the campaign table.

## Investigation

### 1. Naive Count

The initial query counts all campaign communication records for merchant `501` during October 2026.

Result:

**30**

This is higher than the expected target base of 22, so further investigation is required.

### 2. Campaign Eligibility

The campaign table was checked for creation and processing status.

Campaign `9004` has:

- `creation_status = approval_awaiting`
- `processing_status = processed`

Since it has not reached a finalized creation state, its 4 communication records are excluded.

Reconciliation:

```text
30 - 4 = 26
