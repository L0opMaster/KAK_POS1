-- Add khqr_image_url column to business_settings (idempotent)
SET @col_exists := (
  SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'business_settings'
    AND COLUMN_NAME = 'khqr_image_url'
);
SET @sql := IF(@col_exists = 0,
  'ALTER TABLE business_settings ADD COLUMN khqr_image_url TEXT NULL',
  'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
