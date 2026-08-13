-- BusinessSettings gained a `website` field (the link shown at the bottom of
-- printed receipts, previously hardcoded as "www.kaknnea.com" in the
-- frontend). Same idempotent pattern as V109 — safe to re-run.

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'business_settings' AND COLUMN_NAME = 'website');
SET @sql := IF(@col_exists = 0,
    'ALTER TABLE business_settings ADD COLUMN website VARCHAR(255) NULL AFTER phone',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
