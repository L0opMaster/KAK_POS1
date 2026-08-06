-- V27: Add approval tracking columns to shifts table (idempotent)

-- Add approved_by_id column if missing
SET @col_exists := (
	SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
	WHERE TABLE_SCHEMA = DATABASE()
		AND TABLE_NAME = 'shifts'
		AND COLUMN_NAME = 'approved_by_id'
);

SET @sql := IF(@col_exists = 0,
	'ALTER TABLE shifts ADD COLUMN approved_by_id BIGINT NULL AFTER closed_by',
	'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Add approval_note column if missing
SET @note_exists := (
	SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
	WHERE TABLE_SCHEMA = DATABASE()
		AND TABLE_NAME = 'shifts'
		AND COLUMN_NAME = 'approval_note'
);

SET @sql := IF(@note_exists = 0,
	'ALTER TABLE shifts ADD COLUMN approval_note TEXT NULL AFTER approved_by_id',
	'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Add foreign key constraint if missing
SET @fk_exists := (
	SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
	WHERE TABLE_SCHEMA = DATABASE()
		AND TABLE_NAME = 'shifts'
		AND CONSTRAINT_NAME = 'fk_shift_approved_by'
);

SET @sql := IF(@fk_exists = 0,
	'ALTER TABLE shifts ADD CONSTRAINT fk_shift_approved_by FOREIGN KEY (approved_by_id) REFERENCES users(id)',
	'SELECT 1'
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
