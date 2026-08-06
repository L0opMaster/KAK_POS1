ALTER TABLE expenses
    MODIFY status VARCHAR(20) NOT NULL DEFAULT 'APPROVED';

UPDATE expenses
SET status = 'APPROVED',
    approved_by_id = COALESCE(approved_by_id, created_by_id),
    approved_at = COALESCE(approved_at, updated_at, created_at, NOW(6))
WHERE active = TRUE
  AND status = 'DRAFT';

ALTER TABLE other_incomes
    MODIFY status VARCHAR(20) NOT NULL DEFAULT 'APPROVED';

UPDATE other_incomes
SET status = 'APPROVED',
    approved_by_id = COALESCE(approved_by_id, created_by_id),
    approved_at = COALESCE(approved_at, updated_at, created_at, NOW(6))
WHERE active = TRUE
  AND status = 'DRAFT';

UPDATE purchases
SET status = 'APPROVED'
WHERE status = 'DRAFT';

UPDATE purchase_rfqs
SET status = 'SUBMITTED'
WHERE status = 'DRAFT';

UPDATE purchase_orders
SET status = 'SUBMITTED'
WHERE status = 'DRAFT';
