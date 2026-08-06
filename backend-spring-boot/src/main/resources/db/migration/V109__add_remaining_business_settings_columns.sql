-- BusinessSettings gained a batch of "Loyverse-inspired settings" fields
-- (cash rounding, favorites, sale screen layout, receipt display toggles,
-- discount presets, PIN requirement, kitchen display, low stock alerts) that
-- were never migrated into the schema, same class of bug as V108: any
-- SELECT against business_settings failed with "Unknown column", silently
-- swallowed in SaleService.toResponse(), surfacing as
-- "Transaction rolled back because it has been marked as rollback-only" on
-- every sale create/pay.

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'business_settings' AND COLUMN_NAME = 'cash_rounding_mode');
SET @sql := IF(@col_exists = 0,
    'ALTER TABLE business_settings ADD COLUMN cash_rounding_mode VARCHAR(20) NULL DEFAULT ''NONE'' AFTER auto_print_receipt',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'business_settings' AND COLUMN_NAME = 'cash_rounding_interval');
SET @sql := IF(@col_exists = 0,
    'ALTER TABLE business_settings ADD COLUMN cash_rounding_interval INT NOT NULL DEFAULT 0 AFTER cash_rounding_mode',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'business_settings' AND COLUMN_NAME = 'enable_favorites');
SET @sql := IF(@col_exists = 0,
    'ALTER TABLE business_settings ADD COLUMN enable_favorites TINYINT(1) NOT NULL DEFAULT 0 AFTER cash_rounding_interval',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'business_settings' AND COLUMN_NAME = 'sale_screen_layout');
SET @sql := IF(@col_exists = 0,
    'ALTER TABLE business_settings ADD COLUMN sale_screen_layout VARCHAR(20) NULL DEFAULT ''GRID'' AFTER enable_favorites',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'business_settings' AND COLUMN_NAME = 'product_grid_columns');
SET @sql := IF(@col_exists = 0,
    'ALTER TABLE business_settings ADD COLUMN product_grid_columns INT NOT NULL DEFAULT 4 AFTER sale_screen_layout',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'business_settings' AND COLUMN_NAME = 'receipt_show_customer');
SET @sql := IF(@col_exists = 0,
    'ALTER TABLE business_settings ADD COLUMN receipt_show_customer TINYINT(1) NOT NULL DEFAULT 1 AFTER product_grid_columns',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'business_settings' AND COLUMN_NAME = 'receipt_show_barcode');
SET @sql := IF(@col_exists = 0,
    'ALTER TABLE business_settings ADD COLUMN receipt_show_barcode TINYINT(1) NOT NULL DEFAULT 0 AFTER receipt_show_customer',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'business_settings' AND COLUMN_NAME = 'receipt_paper_width');
SET @sql := IF(@col_exists = 0,
    'ALTER TABLE business_settings ADD COLUMN receipt_paper_width INT NOT NULL DEFAULT 58 AFTER receipt_show_barcode',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'business_settings' AND COLUMN_NAME = 'discount_presets');
SET @sql := IF(@col_exists = 0,
    'ALTER TABLE business_settings ADD COLUMN discount_presets TEXT NULL AFTER receipt_paper_width',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'business_settings' AND COLUMN_NAME = 'require_discount_reason');
SET @sql := IF(@col_exists = 0,
    'ALTER TABLE business_settings ADD COLUMN require_discount_reason TINYINT(1) NOT NULL DEFAULT 0 AFTER discount_presets',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'business_settings' AND COLUMN_NAME = 'require_pin_for_pos');
SET @sql := IF(@col_exists = 0,
    'ALTER TABLE business_settings ADD COLUMN require_pin_for_pos TINYINT(1) NOT NULL DEFAULT 0 AFTER require_discount_reason',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'business_settings' AND COLUMN_NAME = 'enable_kitchen_display');
SET @sql := IF(@col_exists = 0,
    'ALTER TABLE business_settings ADD COLUMN enable_kitchen_display TINYINT(1) NOT NULL DEFAULT 0 AFTER require_pin_for_pos',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'business_settings' AND COLUMN_NAME = 'kitchen_printer_name');
SET @sql := IF(@col_exists = 0,
    'ALTER TABLE business_settings ADD COLUMN kitchen_printer_name VARCHAR(100) NULL AFTER enable_kitchen_display',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'business_settings' AND COLUMN_NAME = 'low_stock_alert');
SET @sql := IF(@col_exists = 0,
    'ALTER TABLE business_settings ADD COLUMN low_stock_alert TINYINT(1) NOT NULL DEFAULT 1 AFTER kitchen_printer_name',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'business_settings' AND COLUMN_NAME = 'low_stock_alert_email');
SET @sql := IF(@col_exists = 0,
    'ALTER TABLE business_settings ADD COLUMN low_stock_alert_email VARCHAR(150) NULL AFTER low_stock_alert',
    'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
