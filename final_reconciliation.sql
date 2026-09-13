-- Xeno Data Analyst Internship Assignment
-- Final reconciliation query
-- Merchant: 501
-- Reporting period: October 2026

SELECT
    (
        SELECT COUNT(DISTINCT customer_id)
        FROM communication_log
        WHERE merchant_id = 501
          AND communication_id IN (9001, 9002, 9003)
          AND sent_time >= '2026-10-01'
          AND sent_time < '2026-11-01'
          AND communication_type = '2'
    )
    +
    (
        SELECT COUNT(DISTINCT customer_id)
        FROM communication_log
        WHERE merchant_id = 501
          AND communication_id IN (9201, 9202)
          AND sent_time >= '2026-10-01'
          AND sent_time < '2026-11-01'
          AND communication_type = '2'
    )
    +
    (
        SELECT COUNT(*)
        FROM communication_log
        WHERE merchant_id = 501
          AND communication_id = 9101
          AND sent_time >= '2026-10-01'
          AND sent_time < '2026-11-01'
          AND communication_type = '2'
    ) AS target_base;
