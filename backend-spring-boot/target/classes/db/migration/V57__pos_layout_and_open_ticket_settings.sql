SET @pos_layout_exists := (
  SELECT COUNT(*)
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'business_settings'
    AND COLUMN_NAME = 'pos_layout_config'
);
SET @pos_layout_sql := IF(
  @pos_layout_exists = 0,
  'ALTER TABLE business_settings ADD COLUMN pos_layout_config LONGTEXT NULL',
  'SELECT 1'
);
PREPARE stmt FROM @pos_layout_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @open_ticket_exists := (
  SELECT COUNT(*)
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'business_settings'
    AND COLUMN_NAME = 'open_ticket_config'
);
SET @open_ticket_sql := IF(
  @open_ticket_exists = 0,
  'ALTER TABLE business_settings ADD COLUMN open_ticket_config LONGTEXT NULL',
  'SELECT 1'
);
PREPARE stmt FROM @open_ticket_sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
