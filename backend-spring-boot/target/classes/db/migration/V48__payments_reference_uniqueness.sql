-- V48: enforce payment reference uniqueness for idempotent collection safety

-- 1) Normalize duplicate non-null reference numbers (keep first, suffix later rows with id)
UPDATE payments p
JOIN (
    SELECT id,
           ROW_NUMBER() OVER (PARTITION BY reference_number ORDER BY id) AS rn
    FROM payments
    WHERE reference_number IS NOT NULL
      AND reference_number <> ''
) d ON d.id = p.id
SET p.reference_number = CONCAT(LEFT(p.reference_number, 240), '-', p.id)
WHERE d.rn > 1;

-- 2) Add unique index if missing
SET @uk_ref_exists := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'payments'
      AND INDEX_NAME = 'uk_payments_reference_number'
);

SET @sql := IF(
    @uk_ref_exists = 0,
    'CREATE UNIQUE INDEX uk_payments_reference_number ON payments(reference_number)',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

