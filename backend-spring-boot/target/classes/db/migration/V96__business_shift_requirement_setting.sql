-- Optional shift enforcement for businesses that do not reconcile cashier drawers.
SET @require_shift_exists := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'business_settings'
      AND COLUMN_NAME = 'require_shift_for_sales'
);

SET @sql := IF(
    @require_shift_exists = 0,
    'ALTER TABLE business_settings ADD COLUMN require_shift_for_sales TINYINT(1) NOT NULL DEFAULT 1 AFTER default_language',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
