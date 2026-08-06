SET @name_en_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'units'
      AND COLUMN_NAME = 'name_en'
);
SET @sql := IF(
    @name_en_exists = 0,
    'ALTER TABLE units ADD COLUMN name_en VARCHAR(120) NULL AFTER name',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @name_km_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'units'
      AND COLUMN_NAME = 'name_km'
);
SET @sql := IF(
    @name_km_exists = 0,
    'ALTER TABLE units ADD COLUMN name_km VARCHAR(120) NULL AFTER name_en',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @base_unit_id_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'units'
      AND COLUMN_NAME = 'base_unit_id'
);
SET @sql := IF(
    @base_unit_id_exists = 0,
    'ALTER TABLE units ADD COLUMN base_unit_id BIGINT NULL AFTER base_unit_group',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @is_base_unit_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'units'
      AND COLUMN_NAME = 'is_base_unit'
);
SET @sql := IF(
    @is_base_unit_exists = 0,
    'ALTER TABLE units ADD COLUMN is_base_unit BOOLEAN NOT NULL DEFAULT TRUE AFTER base_unit_id',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @conversion_factor_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'units'
      AND COLUMN_NAME = 'conversion_factor'
);
SET @sql := IF(
    @conversion_factor_exists = 0,
    'ALTER TABLE units ADD COLUMN conversion_factor DECIMAL(18, 6) NOT NULL DEFAULT 1.000000 AFTER is_base_unit',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

UPDATE units
SET name_en = COALESCE(NULLIF(name_en, ''), name),
    name_km = COALESCE(NULLIF(name_km, ''),
        CASE code
            WHEN 'EACH' THEN 'ឯកតា'
            WHEN 'BOX' THEN 'ប្រអប់'
            WHEN 'CASE' THEN 'កេស'
            WHEN 'PACK' THEN 'កញ្ចប់'
            WHEN 'BOTTLE' THEN 'ដប'
            WHEN 'KG' THEN 'គីឡូក្រាម'
            WHEN 'G' THEN 'ក្រាម'
            WHEN 'L' THEN 'លីត្រ'
            WHEN 'ML' THEN 'មីលីលីត្រ'
            ELSE name
        END),
    conversion_factor = CASE
        WHEN code IN ('G', 'ML') THEN 0.001000
        ELSE COALESCE(conversion_factor, 1.000000)
    END,
    is_base_unit = CASE
        WHEN code IN ('G', 'ML') THEN FALSE
        ELSE TRUE
    END;

UPDATE units child
JOIN units base ON base.code = CASE child.code
    WHEN 'G' THEN 'KG'
    WHEN 'ML' THEN 'L'
    ELSE NULL
END
SET child.base_unit_id = base.id
WHERE child.code IN ('G', 'ML');

UPDATE units
SET base_unit_id = NULL,
    is_base_unit = TRUE,
    conversion_factor = 1.000000
WHERE code NOT IN ('G', 'ML')
  AND (base_unit_id IS NOT NULL OR is_base_unit = FALSE OR conversion_factor <> 1.000000);

UPDATE units
SET name = name_en;

ALTER TABLE units
    MODIFY COLUMN name_en VARCHAR(120) NOT NULL,
    MODIFY COLUMN name_km VARCHAR(120) NOT NULL,
    MODIFY COLUMN base_unit_id BIGINT NULL,
    MODIFY COLUMN is_base_unit BOOLEAN NOT NULL DEFAULT TRUE,
    MODIFY COLUMN conversion_factor DECIMAL(18, 6) NOT NULL DEFAULT 1.000000;

SET @fk_exists := (
    SELECT COUNT(*)
    FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE()
      AND TABLE_NAME = 'units'
      AND CONSTRAINT_NAME = 'fk_units_base_unit'
);
SET @sql := IF(
    @fk_exists = 0,
    'ALTER TABLE units ADD CONSTRAINT fk_units_base_unit FOREIGN KEY (base_unit_id) REFERENCES units(id)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
