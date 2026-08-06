-- V87: Normalize legacy document numbers into a short, consistent format.
-- Preserve custom/manual references. Only rewrite known generated legacy patterns.

-- Sales / invoices
UPDATE sales
SET sale_number = CONCAT('INV-', LPAD(id, 5, '0'))
WHERE (status IS NULL OR UPPER(status) NOT IN ('HOLD', 'OPEN'))
  AND (
    sale_number IS NULL
    OR sale_number = ''
    OR sale_number REGEXP '^[0-9]+$'
    OR sale_number REGEXP '^SALE-[0-9]+$'
    OR sale_number REGEXP '^INV-[0-9]+$'
  );

-- Held tickets
UPDATE sales
SET sale_number = CONCAT('TKT-', LPAD(id, 5, '0'))
WHERE UPPER(COALESCE(status, '')) IN ('HOLD', 'OPEN')
  AND (
    sale_number IS NULL
    OR sale_number = ''
    OR sale_number REGEXP '^[0-9]+$'
    OR sale_number REGEXP '^TICKET-[0-9]+$'
    OR sale_number REGEXP '^TKT-[0-9]+$'
  );

-- Customer / sale payments
UPDATE payments
SET reference_number = CONCAT('PAY-', LPAD(id, 5, '0'))
WHERE reference_number IS NULL
   OR reference_number = ''
   OR reference_number LIKE 'COLLECT-%'
   OR reference_number REGEXP '^PAY-[0-9]+-[A-Z0-9]+$';

-- Purchase orders
UPDATE purchase_orders
SET reference_number = CONCAT('PO-', LPAD(id, 5, '0'))
WHERE reference_number IS NULL
   OR reference_number = ''
   OR reference_number REGEXP '^PO-[0-9]{4}-[0-9]+$';

-- Goods receipts
UPDATE goods_receipts
SET reference_number = CONCAT('GRN-', LPAD(id, 5, '0'))
WHERE reference_number IS NULL
   OR reference_number = ''
   OR reference_number REGEXP '^GRN-[0-9]{4}-[0-9]+$';

-- Customer adjustments
UPDATE customer_adjustments
SET reference_number = CONCAT('ADJ-', LPAD(id, 5, '0'))
WHERE reference_number IS NULL
   OR reference_number = ''
   OR reference_number LIKE 'ADJ-%-%';
