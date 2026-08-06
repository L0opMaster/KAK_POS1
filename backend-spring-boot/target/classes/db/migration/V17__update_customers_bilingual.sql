-- V17__update_customers_bilingual.sql
-- Migrate customers table to use bilingual name fields (name_en and name_km)

ALTER TABLE customers 
ADD COLUMN name_en VARCHAR(150) AFTER type,
ADD COLUMN name_km VARCHAR(150) AFTER name_en;

-- Migrate existing data: copy 'name' to both name_en and name_km
UPDATE customers 
SET name_en = COALESCE(name, 'Unknown'), 
    name_km = COALESCE(name, 'មិនស្គាល់');

-- Drop old columns
ALTER TABLE customers 
DROP COLUMN name,
DROP COLUMN business_name,
DROP COLUMN email,
DROP COLUMN address;

-- Add NOT NULL constraint after data migration
ALTER TABLE customers 
MODIFY COLUMN name_en VARCHAR(150) NOT NULL,
MODIFY COLUMN name_km VARCHAR(150) NOT NULL;
