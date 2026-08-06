-- BusinessSettings.autoPrintReceipt has had a JPA mapping for this column
-- (auto_print_receipt) with no matching migration, so every SELECT against
-- business_settings failed with "Unknown column" -- silently swallowed in
-- SaleService.toResponse(), which left the surrounding transaction marked
-- rollback-only and surfaced as "Transaction rolled back because it has been
-- marked as rollback-only" on every sale create/pay.
SET @auto_print_receipt_exists := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'business_settings'
      AND COLUMN_NAME = 'auto_print_receipt'
);

SET @sql := IF(
    @auto_print_receipt_exists = 0,
    'ALTER TABLE business_settings ADD COLUMN auto_print_receipt TINYINT(1) NOT NULL DEFAULT 0 AFTER require_shift_for_sales',
    'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
