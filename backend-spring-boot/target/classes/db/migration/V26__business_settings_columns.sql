-- Align business_settings columns with BusinessSettings entity

-- address
SET @bs_address_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'business_settings'
    AND COLUMN_NAME = 'address'
);
SET @bs_address_sql := IF(
  @bs_address_exists = 0,
  'ALTER TABLE business_settings ADD COLUMN address VARCHAR(255) NULL',
  'SELECT 1'
);
PREPARE stmt FROM @bs_address_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- phone
SET @bs_phone_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'business_settings'
    AND COLUMN_NAME = 'phone'
);
SET @bs_phone_sql := IF(
  @bs_phone_exists = 0,
  'ALTER TABLE business_settings ADD COLUMN phone VARCHAR(50) NULL',
  'SELECT 1'
);
PREPARE stmt FROM @bs_phone_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- tax_rate
SET @bs_tax_rate_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'business_settings'
    AND COLUMN_NAME = 'tax_rate'
);
SET @bs_tax_rate_sql := IF(
  @bs_tax_rate_exists = 0,
  'ALTER TABLE business_settings ADD COLUMN tax_rate DOUBLE NOT NULL DEFAULT 0',
  'SELECT 1'
);
PREPARE stmt FROM @bs_tax_rate_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- currency
SET @bs_currency_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'business_settings'
    AND COLUMN_NAME = 'currency'
);
SET @bs_currency_sql := IF(
  @bs_currency_exists = 0,
  'ALTER TABLE business_settings ADD COLUMN currency VARCHAR(10) NOT NULL DEFAULT "KHR"',
  'SELECT 1'
);
PREPARE stmt FROM @bs_currency_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- receipt_footer
SET @bs_receipt_footer_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'business_settings'
    AND COLUMN_NAME = 'receipt_footer'
);
SET @bs_receipt_footer_sql := IF(
  @bs_receipt_footer_exists = 0,
  'ALTER TABLE business_settings ADD COLUMN receipt_footer VARCHAR(255) NULL',
  'SELECT 1'
);
PREPARE stmt FROM @bs_receipt_footer_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Backfill new columns from legacy columns where available
UPDATE business_settings
SET address = COALESCE(address, business_address),
    phone = COALESCE(phone, business_phone),
    currency = COALESCE(currency, default_currency),
    tax_rate = COALESCE(tax_rate, 0)
WHERE id IS NOT NULL;
