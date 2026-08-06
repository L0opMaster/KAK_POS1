-- V90: Remove remaining sample expense rows from older demo data.
-- Match both the seeded expense number and known seeded description so real
-- production expenses with similar numbering are not removed accidentally.

DELETE FROM expenses
WHERE (expense_number = 'EXP-000001' AND description = 'Monthly shop rent – March 2026')
   OR (expense_number = 'EXP-000002' AND description = 'Staff salaries – February 2026')
   OR (expense_number = 'EXP-000003' AND description = 'Printer paper & ink cartridges')
   OR (expense_number = 'EXP-000004' AND description = 'Delivery fee – bulk inventory run')
   OR (expense_number = 'EXP-000005' AND description = 'Facebook & Instagram ads – March')
   OR (expense_number = 'EXP-000006' AND description = 'Air conditioner service – showroom unit')
   OR (expense_number = 'EXP-000007' AND description = 'ABA monthly account fee')
   OR (expense_number = 'EXP-000008' AND description = 'Team lunch – Q1 review meeting')
   OR (expense_number = 'EXP-000009' AND description = 'Emergency stock top-up – beverages')
   OR (expense_number = 'EXP-000010' AND description = 'Annual business license renewal')
   OR (expense_number = 'EXP-000011' AND description = 'Cleaning supplies – March restock')
   OR (expense_number = 'EXP-000012' AND description = 'POS system training – 2 new staff')
   OR (expense_number = 'EXP-000013' AND description = 'Replacement barcode scanner')
   OR (expense_number = 'EXP-000014' AND description = 'Takeaway boxes & bags – Q1 order');
