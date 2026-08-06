-- Reference numbers for purchasing documents
ALTER TABLE purchase_orders
  ADD COLUMN reference_number VARCHAR(30) NULL UNIQUE AFTER id;

ALTER TABLE goods_receipts
  ADD COLUMN reference_number VARCHAR(30) NULL UNIQUE AFTER id;

-- Transfer improvements
ALTER TABLE stock_transfers
  ADD COLUMN transfer_number VARCHAR(30) NULL UNIQUE AFTER id,
  ADD COLUMN notes TEXT NULL AFTER status;

-- Audit trail on stock movements
ALTER TABLE stock_movements
  ADD COLUMN created_by VARCHAR(100) NULL AFTER reason;

-- Due date on supplier invoices
ALTER TABLE supplier_invoices
  ADD COLUMN due_date DATE NULL AFTER invoice_date;

-- Payment method on supplier payments
ALTER TABLE supplier_payments
  ADD COLUMN payment_method VARCHAR(60) NULL AFTER reference;
