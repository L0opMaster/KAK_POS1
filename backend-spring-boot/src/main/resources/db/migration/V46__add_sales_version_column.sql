-- V46: Add optimistic lock version column to sales (idempotent)

SET @version_exists := (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'sales'
      AND COLUMN_NAME = 'version'
);

SET @sql := IF(
    @version_exists = 0,
    'ALTER TABLE sales ADD COLUMN version BIGINT NOT NULL DEFAULT 0',
    'SELECT 1'
);

PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
