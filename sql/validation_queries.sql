USE healthcare_project;

-- Compare source and target record counts
SELECT 'Source' AS dataset,
       COUNT(*) AS total_records
FROM source_claims
UNION ALL
SELECT 'Target' AS dataset,
       COUNT(*) AS total_records
FROM target_claims;

-- Find source claims missing from the target
SELECT s.claim_id,
       s.patient_id,
       s.amount,
       s.status
FROM source_claims s
LEFT JOIN target_claims t
    ON s.claim_id = t.claim_id
WHERE t.claim_id IS NULL;

-- Find duplicate claim IDs
SELECT claim_id,
       COUNT(*) AS occurrences
FROM source_claims
GROUP BY claim_id
HAVING COUNT(*) > 1;

-- Find invalid amounts
SELECT *
FROM source_claims
WHERE amount IS NULL
   OR amount <= 0;

-- Find invalid statuses
SELECT *
FROM source_claims
WHERE status IS NULL
   OR status NOT IN (
       'Approved',
       'Pending',
       'Rejected'
   );
