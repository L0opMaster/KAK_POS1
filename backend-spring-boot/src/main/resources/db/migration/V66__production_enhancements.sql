-- Production order reference number and audit trail
ALTER TABLE production_orders
  ADD COLUMN order_number VARCHAR(30) NULL UNIQUE AFTER id,
  ADD COLUMN created_by   VARCHAR(100) NULL AFTER notes;
