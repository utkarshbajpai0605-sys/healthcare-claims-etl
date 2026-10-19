CREATE DATABASE IF NOT EXISTS healthcare_project;

USE healthcare_project;

CREATE TABLE IF NOT EXISTS source_claims (
    claim_id VARCHAR(10) PRIMARY KEY,
    patient_id VARCHAR(10),
    amount DECIMAL(10,2),
    status VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS target_claims (
    claim_id VARCHAR(10) PRIMARY KEY,
    patient_id VARCHAR(10),
    amount DECIMAL(10,2),
    status VARCHAR(20)
);

INSERT INTO source_claims
(claim_id, patient_id, amount, status)
VALUES
('C101', 'P001', 5000, 'Approved'),
('C102', 'P002', 3000, 'Pending'),
('C103', 'P003', 7000, 'Approved'),
('C104', 'P004', 2000, 'Rejected'),
('C105', 'P005', 4500, 'Approved');

INSERT INTO target_claims
(claim_id, patient_id, amount, status)
VALUES
('C101', 'P001', 5000, 'Approved'),
('C102', 'P002', 3000, 'Pending'),
('C104', 'P004', 2000, 'Rejected'),
('C105', 'P005', 4500, 'Approved');

SELECT * FROM source_claims;

SELECT * FROM target_claims;

SELECT 'Source' AS dataset,
       COUNT(*) AS total_records
FROM source_claims

UNION ALL

SELECT 'Target' AS dataset,
       COUNT(*) AS total_records
FROM target_claims;

SELECT s.claim_id,
       s.patient_id,
       s.amount,
       s.status
FROM source_claims s
LEFT JOIN target_claims t
    ON s.claim_id = t.claim_id
WHERE t.claim_id IS NULL;

SELECT
    claim_id,
    COUNT(*) AS occurrences
FROM source_claims
GROUP BY claim_id
HAVING COUNT(*) > 1;

SELECT *
FROM source_claims
WHERE amount IS NULL
   OR amount <= 0;
   
SELECT *
FROM source_claims
WHERE status IS NULL
   OR status NOT IN (
       'Approved',
       'Pending',
       'Rejected'
   );   

USE healthcare_project;

CREATE TABLE IF NOT EXISTS raw_claims_staging (
    claim_id VARCHAR(10),
    patient_id VARCHAR(10),
    amount DECIMAL(10,2),
    status VARCHAR(20)
);

INSERT INTO raw_claims_staging
    (claim_id, patient_id, amount, status)
VALUES
    ('C201', 'P101', 5000, 'Approved'),
    ('C202', 'P102', 3000, 'Pending'),
    ('C203', 'P103', 7000, 'Approved'),
    ('C202', 'P102', 3000, 'Pending'),
    ('C204', 'P104', 2500, 'Approved'),
    ('C203', 'P103', 7000, 'Approved');
    
SELECT *
FROM raw_claims_staging;

SELECT
    claim_id,
    COUNT(*) AS occurrences
FROM raw_claims_staging
GROUP BY claim_id
HAVING COUNT(*) > 1;

INSERT INTO raw_claims_staging
    (claim_id, patient_id, amount, status)
VALUES
    ('C301', 'P201', 5000, 'Approved'),
    ('C302', 'P202', 0, 'Pending'),
    ('C303', 'P203', -1500, 'Approved'),
    ('C304', 'P204', NULL, 'Pending'),
    ('C305', 'P205', 2500, 'Approved');
    
SELECT
    claim_id,
    patient_id,
    amount,
    status
FROM raw_claims_staging
WHERE amount IS NULL
   OR amount <= 0;
    
SELECT
    claim_id,
    status
FROM raw_claims_staging
WHERE status IS NULL
   OR TRIM(status) = ''
   OR TRIM(status) NOT IN (
       'Approved',
       'Pending',
       'Rejected'
   );

   
SELECT
    status,
    COUNT(*) AS record_count
FROM raw_claims_staging
GROUP BY status
ORDER BY record_count DESC;

USE healthcare_project;

SELECT
    'DUPLICATE_CLAIM_ID' AS issue_type,
    claim_id,
    CONCAT('Occurrences: ', COUNT(*)) AS issue_details
FROM raw_claims_staging
GROUP BY claim_id
HAVING COUNT(*) > 1

UNION ALL

SELECT
    'INVALID_AMOUNT' AS issue_type,
    claim_id,
    CONCAT(
        'Amount: ',
        COALESCE(CAST(amount AS CHAR), 'NULL')
    ) AS issue_details
FROM raw_claims_staging
WHERE amount IS NULL
   OR amount <= 0

UNION ALL

SELECT
    'INVALID_STATUS' AS issue_type,
    claim_id,
    CONCAT(
        'Status: ',
        COALESCE(NULLIF(TRIM(status), ''), 'NULL/blank')
    ) AS issue_details
FROM raw_claims_staging
WHERE status IS NULL
   OR TRIM(status) = ''
   OR TRIM(status) NOT IN (
       'Approved',
       'Pending',
       'Rejected'
   )

ORDER BY issue_type, claim_id;

SELECT
    status,
    COUNT(*) AS record_count
FROM raw_claims_staging
GROUP BY status
ORDER BY record_count DESC;

USE healthcare_project;

SELECT
    'DUPLICATE_CLAIM_ID' AS issue_type,
    claim_id,
    CONCAT('Occurrences: ', COUNT(*)) AS issue_details
FROM raw_claims_staging
GROUP BY claim_id
HAVING COUNT(*) > 1

UNION ALL

SELECT
    'INVALID_AMOUNT' AS issue_type,
    claim_id,
    CONCAT(
        'Amount: ',
        COALESCE(CAST(amount AS CHAR), 'NULL')
    ) AS issue_details
FROM raw_claims_staging
WHERE amount IS NULL
   OR amount <= 0

UNION ALL

SELECT
    'INVALID_STATUS' AS issue_type,
    claim_id,
    CONCAT(
        'Status: ',
        COALESCE(NULLIF(TRIM(status), ''), 'NULL/blank')
    ) AS issue_details
FROM raw_claims_staging
WHERE status IS NULL
   OR TRIM(status) = ''
   OR TRIM(status) NOT IN (
       'Approved',
       'Pending',
       'Rejected'
   )

ORDER BY issue_type, claim_id;

USE healthcare_project;

CREATE TABLE IF NOT EXISTS clean_claims (
    claim_id VARCHAR(10) PRIMARY KEY,
    patient_id VARCHAR(10),
    amount DECIMAL(10,2),
    status VARCHAR(20)
);

TRUNCATE TABLE clean_claims;

INSERT INTO clean_claims (
    claim_id,
    patient_id,
    amount,
    status
)
SELECT
    r.claim_id,
    r.patient_id,
    r.amount,
    r.status
FROM raw_claims_staging r
JOIN (
    SELECT claim_id
    FROM raw_claims_staging
    GROUP BY claim_id
    HAVING COUNT(*) = 1
) unique_claims
    ON r.claim_id = unique_claims.claim_id
WHERE r.amount > 0
  AND r.status IN (
      'Approved',
      'Pending',
      'Rejected'
  );
  
  SELECT *
FROM clean_claims
ORDER BY claim_id;

SELECT
    COUNT(*) AS clean_record_count,
    SUM(amount) AS clean_total_amount
FROM clean_claims;

SELECT
    claim_id,
    patient_id,
    amount,
    status
FROM clean_claims
ORDER BY claim_id;

  SELECT
    COUNT(*) AS record_count,
    SUM(amount) AS total_amount,
    MIN(amount) AS minimum_amount,
    MAX(amount) AS maximum_amount
FROM clean_claims;

CREATE TABLE IF NOT EXISTS claim_exceptions (
    claim_id VARCHAR(10),
    patient_id VARCHAR(10),
    amount DECIMAL(10,2),
    status VARCHAR(20),
    exception_reason VARCHAR(100)
);

SELECT
    claim_id,
    COUNT(*) AS occurrences
FROM raw_claims_staging
GROUP BY claim_id
HAVING COUNT(*) > 1;

INSERT INTO claim_exceptions (
    claim_id,
    patient_id,
    amount,
    status,
    exception_reason
)
SELECT
    claim_id,
    patient_id,
    amount,
    status,
    CASE
        WHEN amount IS NULL THEN 'Missing amount'
        WHEN amount = 0 THEN 'Zero amount requires review'
        WHEN amount < 0 THEN 'Negative amount requires review'
    END
FROM raw_claims_staging
WHERE amount IS NULL
   OR amount <= 0;
   
SELECT *
FROM claim_exceptions;
   
INSERT INTO claim_exceptions (
    claim_id,
    patient_id,
    amount,
    status,
    exception_reason
)
SELECT
    r.claim_id,
    r.patient_id,
    r.amount,
    r.status,
    'Duplicate claim ID requires investigation'
FROM raw_claims_staging r
JOIN (
    SELECT claim_id
    FROM raw_claims_staging
    GROUP BY claim_id
    HAVING COUNT(*) > 1
) d
    ON r.claim_id = d.claim_id;
    
SELECT
    exception_reason,
    COUNT(*) AS affected_records
FROM claim_exceptions
GROUP BY exception_reason;
    
SELECT
    COUNT(*) AS total_staging_records,
    COUNT(DISTINCT claim_id) AS distinct_claim_ids
FROM raw_claims_staging;

SELECT
    COUNT(*) AS accepted_records,
    SUM(amount) AS accepted_total_amount
FROM clean_claims;

SELECT
    COUNT(*) AS total_exception_entries,
    COUNT(DISTINCT claim_id) AS distinct_claims_flagged
FROM claim_exceptions;

SELECT
    COUNT(*) AS total_staging_records,
    COUNT(DISTINCT claim_id) AS distinct_claim_ids
FROM raw_claims_staging;

SELECT
    COUNT(*) AS accepted_records,
    SUM(amount) AS accepted_total_amount
FROM clean_claims;

USE healthcare_project;

SELECT
    COUNT(*) AS total_staging_records,
    COUNT(DISTINCT claim_id) AS distinct_claim_ids
FROM raw_claims_staging;

SELECT
    claim_id,
    patient_id,
    amount,
    status,
    CASE
        WHEN claim_id IS NULL THEN 'MISSING_CLAIM_ID'

        WHEN claim_id IN (
            SELECT claim_id
            FROM raw_claims_staging
            GROUP BY claim_id
            HAVING COUNT(*) > 1
        ) THEN 'DUPLICATE'

        WHEN amount IS NULL OR amount <= 0
            THEN 'INVALID_AMOUNT'

        WHEN status IS NULL
          OR TRIM(status) = ''
          OR TRIM(status) NOT IN (
              'Approved',
              'Pending',
              'Rejected'
          ) THEN 'INVALID_STATUS'

        ELSE 'ACCEPTED'
    END AS disposition
FROM raw_claims_staging
ORDER BY claim_id;

SELECT
    CASE
        WHEN claim_id IS NULL THEN 'MISSING_CLAIM_ID'
        WHEN claim_id IN (
            SELECT claim_id
            FROM raw_claims_staging
            GROUP BY claim_id
            HAVING COUNT(*) > 1
        ) THEN 'DUPLICATE'
        WHEN amount IS NULL OR amount <= 0
            THEN 'INVALID_AMOUNT'
        WHEN status IS NULL
          OR TRIM(status) = ''
          OR TRIM(status) NOT IN (
              'Approved',
              'Pending',
              'Rejected'
          ) THEN 'INVALID_STATUS'
        ELSE 'ACCEPTED'
    END AS disposition,
    COUNT(*) AS record_count
FROM raw_claims_staging
GROUP BY disposition
ORDER BY disposition;

CREATE OR REPLACE VIEW claim_disposition_report AS
SELECT
    claim_id,
    patient_id,
    amount,
    status,
    CASE
        WHEN claim_id IS NULL
            THEN 'MISSING_CLAIM_ID'

        WHEN claim_id IN (
            SELECT claim_id
            FROM raw_claims_staging
            GROUP BY claim_id
            HAVING COUNT(*) > 1
        ) THEN 'DUPLICATE'

        WHEN amount IS NULL OR amount <= 0
            THEN 'INVALID_AMOUNT'

        WHEN status IS NULL
          OR TRIM(status) = ''
          OR TRIM(status) NOT IN (
              'Approved',
              'Pending',
              'Rejected'
          ) THEN 'INVALID_STATUS'

        ELSE 'ACCEPTED'
    END AS disposition
FROM raw_claims_staging;

SELECT *
FROM claim_disposition_report;

SELECT
    disposition,
    COUNT(*) AS record_count
FROM claim_disposition_report
GROUP BY disposition
ORDER BY disposition;

SELECT
    claim_id,
    patient_id,
    amount,
    status
FROM clean_claims
ORDER BY claim_id;

SELECT
    COUNT(*) AS accepted_records,
    SUM(amount) AS accepted_total_amount
FROM clean_claims;

SELECT
    status,
    COUNT(*) AS record_count,
    SUM(amount) AS total_amount
FROM clean_claims
GROUP BY status;

SELECT
    COUNT(*) AS approved_records
FROM clean_claims
WHERE status = 'Approved';

SELECT
    claim_id,
    amount,
    status,
    CASE
        WHEN claim_id IN (
            SELECT claim_id
            FROM raw_claims_staging
            GROUP BY claim_id
            HAVING COUNT(*) > 1
        ) THEN 'DUPLICATE'
        WHEN amount IS NULL OR amount <= 0
            THEN 'INVALID_AMOUNT'
        WHEN status IS NULL
          OR TRIM(status) = ''
          OR TRIM(status) NOT IN
             ('Approved', 'Pending', 'Rejected')
            THEN 'INVALID_STATUS'
        ELSE 'ACCEPTED'
    END AS disposition
FROM raw_claims_staging
ORDER BY claim_id;

SELECT
    COUNT(*) AS reported_records,
    SUM(amount) AS reported_total
FROM clean_claims
WHERE amount >= 3000;

SELECT 
    COUNT(*) AS reported_records, SUM(amount) AS reported_total
FROM
    clean_claims;
    
SELECT
    (SELECT COUNT(*)
     FROM clean_claims) AS clean_count,

    (SELECT COUNT(*)
     FROM claim_disposition_report
     WHERE disposition = 'ACCEPTED') AS expected_count;

