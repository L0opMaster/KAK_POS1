-- Extend expense categories with new ones not already covered by V74.
-- V74 already seeded: Rent & Utilities, Salaries & Wages, Supplies & Materials,
--   Marketing & Advertising, Transport & Delivery, Repairs & Maintenance,
--   Food & Entertainment, Bank & Finance Charges, Other.
-- Each INSERT uses NOT EXISTS to remain idempotent.

INSERT INTO expense_categories (name_en, name_km, color, active, created_at)
SELECT 'Office Supplies', 'សម្ភារៈការិយាល័យ', '#3b82f6', true, NOW()
WHERE NOT EXISTS (SELECT 1 FROM expense_categories WHERE name_en = 'Office Supplies');

INSERT INTO expense_categories (name_en, name_km, color, active, created_at)
SELECT 'Equipment & Fixtures', 'គ្រឿងបរិក្ខារ និងឧបករណ៍', '#8b5cf6', true, NOW()
WHERE NOT EXISTS (SELECT 1 FROM expense_categories WHERE name_en = 'Equipment & Fixtures');

INSERT INTO expense_categories (name_en, name_km, color, active, created_at)
SELECT 'Inventory Purchase', 'ការទិញស្តុក', '#f59e0b', true, NOW()
WHERE NOT EXISTS (SELECT 1 FROM expense_categories WHERE name_en = 'Inventory Purchase');

INSERT INTO expense_categories (name_en, name_km, color, active, created_at)
SELECT 'Packaging Materials', 'វត្ថុធាតុដើមវេចខ្ចប់', '#f97316', true, NOW()
WHERE NOT EXISTS (SELECT 1 FROM expense_categories WHERE name_en = 'Packaging Materials');

INSERT INTO expense_categories (name_en, name_km, color, active, created_at)
SELECT 'Taxes & Licenses', 'ពន្ធ និងអាជ្ញាបណ្ណ', '#ef4444', true, NOW()
WHERE NOT EXISTS (SELECT 1 FROM expense_categories WHERE name_en = 'Taxes & Licenses');

INSERT INTO expense_categories (name_en, name_km, color, active, created_at)
SELECT 'Cleaning & Hygiene', 'សំអាត និងអនាម័យ', '#14b8a6', true, NOW()
WHERE NOT EXISTS (SELECT 1 FROM expense_categories WHERE name_en = 'Cleaning & Hygiene');

INSERT INTO expense_categories (name_en, name_km, color, active, created_at)
SELECT 'Staff Meals & Benefits', 'អាហារ និងសុខុមាលភាពបុគ្គលិក', '#a3e635', true, NOW()
WHERE NOT EXISTS (SELECT 1 FROM expense_categories WHERE name_en = 'Staff Meals & Benefits');

INSERT INTO expense_categories (name_en, name_km, color, active, created_at)
SELECT 'Training & Development', 'បណ្តុះបណ្តាល និងអភិវឌ្ឍន៍', '#fb923c', true, NOW()
WHERE NOT EXISTS (SELECT 1 FROM expense_categories WHERE name_en = 'Training & Development');

INSERT INTO expense_categories (name_en, name_km, color, active, created_at)
SELECT 'Events & Promotions', 'ព្រឹត្តិការណ៍ និងការផ្សព្វផ្សាយ', '#84cc16', true, NOW()
WHERE NOT EXISTS (SELECT 1 FROM expense_categories WHERE name_en = 'Events & Promotions');
