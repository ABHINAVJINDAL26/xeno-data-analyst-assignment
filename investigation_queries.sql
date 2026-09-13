-- Xeno Data Analyst Internship Assignment
-- Comm-Log Send Reconciliation
-- Merchant: 501
-- Period: October 2026


-- STEP 0: Naive count
SELECT COUNT(*) 
FROM communication_log 
WHERE merchant_id = 501 
  AND sent_time >= '2026-10-01' AND sent_time < '2026-11-01'
  AND communication_type = '2';


-- STEP 1: Campaign table dekho (approval status check)
SELECT id, name, creation_status, processing_status 
FROM campaign 
WHERE merchant_id = 501;


-- STEP 1: 9004 ke sends count karo
SELECT COUNT(*) 
FROM communication_log 
WHERE communication_id = 9004;


-- STEP 1: 9004 exclude karke count
SELECT COUNT(*) 
FROM communication_log 
WHERE merchant_id = 501 
  AND sent_time >= '2026-10-01' AND sent_time < '2026-11-01'
  AND communication_type = '2'
  AND communication_id != 9004;


-- STEP 2: Retry chains dekho (parent_id)
SELECT id, parent_id, name 
FROM campaign 
WHERE merchant_id = 501 
ORDER BY id;


-- STEP 2: Family A mein repeat customers dekho
SELECT customer_id, COUNT(*) as attempts
FROM communication_log
WHERE communication_id IN (9001, 9002, 9003)
GROUP BY customer_id
HAVING COUNT(*) > 1;


-- STEP 2: Family A distinct customers
SELECT COUNT(DISTINCT customer_id)
FROM communication_log
WHERE communication_id IN (9001, 9002, 9003);


-- STEP 3: Family B distinct customers
SELECT COUNT(DISTINCT customer_id)
FROM communication_log
WHERE communication_id IN (9201, 9202);


-- STEP 4: Standalone 9101 as-is count
SELECT COUNT(*)
FROM communication_log
WHERE communication_id = 9101;


-- STEP 4: C20 ke repeated sends investigate karo
SELECT *
FROM communication_log
WHERE customer_id = 'C20';


-- FINAL CHECK: 22
SELECT
  (SELECT COUNT(DISTINCT customer_id) 
   FROM communication_log 
   WHERE communication_id IN (9001, 9002, 9003))
  +
  (SELECT COUNT(DISTINCT customer_id) 
   FROM communication_log 
   WHERE communication_id IN (9201, 9202))
  +
  (SELECT COUNT(*) 
   FROM communication_log 
   WHERE communication_id = 9101)
  AS target_base;
