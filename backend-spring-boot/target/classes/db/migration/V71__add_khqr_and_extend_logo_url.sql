-- Add khqr_image_url column to business_settings
-- Also extend logo_url to TEXT so long upload URLs don't get truncated

SET @khqr_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'business_settings'
    AND COLUMN_NAME = 'khqr_image_url'
);
SET @khqr_sql := IF(
  @khqr_exists = 0,
  'ALTER TABLE business_settings ADD COLUMN khqr_image_url TEXT NULL',
  'SELECT 1'
);
PREPARE stmt FROM @khqr_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Extend logo_url from VARCHAR(255) to TEXT to support long upload paths
SET @logo_type := (
  SELECT DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'business_settings'
    AND COLUMN_NAME = 'logo_url'
);
SET @logo_sql := IF(
  @logo_type = 'varchar',
  'ALTER TABLE business_settings MODIFY COLUMN logo_url TEXT NULL',
  'SELECT 1'
);
PREPARE stmt FROM @logo_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
