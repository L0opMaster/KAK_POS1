-- Allow stores to hide the "Demo account" button on the login page.
SET @show_demo_account_exists := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'business_settings'
      AND COLUMN_NAME = 'show_demo_account'
);

SET @sql := IF(
    @show_demo_account_exists = 0,
    'ALTER TABLE business_settings ADD COLUMN show_demo_account TINYINT(1) NOT NULL DEFAULT 1 AFTER require_shift_for_sales',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
