-- Seed sample expense records for demonstration.
-- Uses INSERT IGNORE so re-runs skip existing expense_numbers (unique key).

INSERT IGNORE INTO expenses (
  expense_number, expense_date, category_id, description,
  amount, payment_method, reference, note,
  status, created_by_id, active, created_at
) VALUES
('EXP-000001', '2026-03-01',
  (SELECT id FROM expense_categories WHERE name_en = 'Rent & Utilities' LIMIT 1),
  'Monthly shop rent – March 2026', 1500000.00, 'BANK_TRANSFER', 'TXN-20260301', 'Paid via ABA',
  'APPROVED', 1, true, '2026-03-01 09:00:00'),

('EXP-000002', '2026-03-03',
  (SELECT id FROM expense_categories WHERE name_en = 'Salaries & Wages' LIMIT 1),
  'Staff salaries – February 2026', 3200000.00, 'BANK_TRANSFER', 'SAL-FEB-2026', 'Monthly payroll',
  'APPROVED', 1, true, '2026-03-03 10:00:00'),

('EXP-000003', '2026-03-05',
  (SELECT id FROM expense_categories WHERE name_en = 'Office Supplies' LIMIT 1),
  'Printer paper & ink cartridges', 85000.00, 'CASH', 'REC-00123', NULL,
  'APPROVED', 1, true, '2026-03-05 11:30:00'),

('EXP-000004', '2026-03-08',
  (SELECT id FROM expense_categories WHERE name_en = 'Transport & Delivery' LIMIT 1),
  'Delivery fee – bulk inventory run', 120000.00, 'CASH', NULL, 'Paid to driver',
  'APPROVED', 1, true, '2026-03-08 14:00:00'),

('EXP-000005', '2026-03-10',
  (SELECT id FROM expense_categories WHERE name_en = 'Marketing & Advertising' LIMIT 1),
  'Facebook & Instagram ads – March', 450000.00, 'KHQR', 'FB-ADV-0310', NULL,
  'APPROVED', 1, true, '2026-03-10 09:15:00'),

('EXP-000006', '2026-03-12',
  (SELECT id FROM expense_categories WHERE name_en = 'Repairs & Maintenance' LIMIT 1),
  'Air conditioner service – showroom unit', 180000.00, 'CASH', NULL, 'Annual service call',
  'APPROVED', 1, true, '2026-03-12 16:00:00'),

('EXP-000007', '2026-03-14',
  (SELECT id FROM expense_categories WHERE name_en = 'Bank & Finance Charges' LIMIT 1),
  'ABA monthly account fee', 15000.00, 'BANK_TRANSFER', 'ABA-FEE-MAR', NULL,
  'APPROVED', 1, true, '2026-03-14 08:00:00'),

('EXP-000008', '2026-03-15',
  (SELECT id FROM expense_categories WHERE name_en = 'Food & Entertainment' LIMIT 1),
  'Team lunch – Q1 review meeting', 240000.00, 'CASH', NULL, '8 staff members',
  'APPROVED', 1, true, '2026-03-15 13:00:00'),

('EXP-000009', '2026-03-17',
  (SELECT id FROM expense_categories WHERE name_en = 'Inventory Purchase' LIMIT 1),
  'Emergency stock top-up – beverages', 2100000.00, 'BANK_TRANSFER', 'PO-0317-BEV', 'Urgent re-order',
  'APPROVED', 1, true, '2026-03-17 10:30:00'),

('EXP-000010', '2026-03-18',
  (SELECT id FROM expense_categories WHERE name_en = 'Taxes & Licenses' LIMIT 1),
  'Annual business license renewal', 350000.00, 'BANK_TRANSFER', 'TAX-LIC-2026', NULL,
  'APPROVED', 1, true, '2026-03-18 09:00:00'),

('EXP-000011', '2026-03-19',
  (SELECT id FROM expense_categories WHERE name_en = 'Cleaning & Hygiene' LIMIT 1),
  'Cleaning supplies – March restock', 65000.00, 'CASH', NULL, NULL,
  'DRAFT', 1, true, '2026-03-19 15:00:00'),

('EXP-000012', '2026-03-20',
  (SELECT id FROM expense_categories WHERE name_en = 'Training & Development' LIMIT 1),
  'POS system training – 2 new staff', 200000.00, 'CASH', 'TRN-0320', 'External trainer',
  'DRAFT', 1, true, '2026-03-20 09:00:00'),

('EXP-000013', '2026-03-21',
  (SELECT id FROM expense_categories WHERE name_en = 'Equipment & Fixtures' LIMIT 1),
  'Replacement barcode scanner', 420000.00, 'KHQR', 'INV-SCAN-001', NULL,
  'DRAFT', 1, true, '2026-03-21 11:00:00'),

('EXP-000014', '2026-03-22',
  (SELECT id FROM expense_categories WHERE name_en = 'Packaging Materials' LIMIT 1),
  'Takeaway boxes & bags – Q1 order', 310000.00, 'CASH', NULL, '500 units',
  'DRAFT', 1, true, '2026-03-22 08:30:00');
