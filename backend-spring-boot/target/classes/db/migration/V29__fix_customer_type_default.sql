-- V29__fix_customer_type_default.sql
-- Fix customers.type field to have a default value and NOT NULL constraint

-- Update any NULL values to 'RETAIL' (default customer type)
UPDATE customers SET type = 'RETAIL' WHERE type IS NULL OR type = '';

-- Modify the column to have a default value and be NOT NULL
ALTER TABLE customers 
MODIFY COLUMN type VARCHAR(20) NOT NULL DEFAULT 'RETAIL';
