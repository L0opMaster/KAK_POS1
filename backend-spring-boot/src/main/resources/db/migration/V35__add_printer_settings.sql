ALTER TABLE invoice_settings
  ADD COLUMN printer_name VARCHAR(100) NULL,
  ADD COLUMN printer_type VARCHAR(20) NULL,
  ADD COLUMN printer_address VARCHAR(100) NULL,
  ADD COLUMN default_invoice_format VARCHAR(20) NULL,
  ADD COLUMN default_receipt_format VARCHAR(20) NULL;

UPDATE invoice_settings
SET default_invoice_format = 'STANDARD'
WHERE default_invoice_format IS NULL;

UPDATE invoice_settings
SET default_receipt_format = 'THERMAL'
WHERE default_receipt_format IS NULL;
