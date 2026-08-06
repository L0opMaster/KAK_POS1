-- V80: Remove sample/demo business data from all environments.
-- Keep schema and reference/master data, but remove fake transactional/demo rows.

-- Sample expenses from V77
DELETE FROM expenses
WHERE expense_number BETWEEN 'EXP-000001' AND 'EXP-000014';

-- Demo products from V78
DELETE FROM products
WHERE sku IN (
  'BEV-HOT-001','BEV-HOT-002','BEV-HOT-003','BEV-HOT-004','BEV-HOT-005',
  'BEV-CLD-001','BEV-CLD-002','BEV-CLD-003','BEV-CLD-004','BEV-CLD-005','BEV-CLD-006','BEV-CLD-007','BEV-CLD-008',
  'JUS-001','JUS-002','JUS-003','JUS-004','JUS-005',
  'FOOD-R-001','FOOD-R-002','FOOD-R-003','FOOD-R-004',
  'FOOD-N-001','FOOD-N-002','FOOD-N-003','FOOD-N-004',
  'FOOD-S-001','FOOD-S-002','FOOD-S-003','FOOD-S-004',
  'FOOD-D-001','FOOD-D-002','FOOD-D-003',
  'FRZ-001','FRZ-002','FRZ-003','FRZ-004','FRZ-005',
  'PKG-001','PKG-002','PKG-003','PKG-004'
);

-- Demo customers from V78
DELETE FROM customers
WHERE customer_code BETWEEN 'CUST-0001' AND 'CUST-0020';

-- Demo suppliers from V78
DELETE FROM suppliers
WHERE phone IN (
  '+855 12 345 001',
  '+855 12 345 002',
  '+855 12 345 003',
  '+855 12 345 004',
  '+855 12 345 005',
  '+855 12 345 006',
  '+855 12 345 007',
  '+855 12 345 008',
  '+855 12 345 009',
  '+855 12 345 010'
);
