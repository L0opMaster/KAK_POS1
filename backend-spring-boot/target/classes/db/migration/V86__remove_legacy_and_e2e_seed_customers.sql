-- V86: Remove legacy sample customers and E2E-generated seed customers.
-- Keep real customer data intact by targeting only known demo/test markers.

-- Payments linked to sales from seeded customers
DELETE FROM payments
WHERE sale_id IN (
  SELECT sale_id FROM (
    SELECT s.id AS sale_id
    FROM sales s
    JOIN customers c ON c.id = s.customer_id
    WHERE c.customer_code LIKE 'E2E%'
      OR c.customer_code BETWEEN 'CUST-0001' AND 'CUST-0020'
      OR c.display_name LIKE 'E2E Seed Customer %'
      OR c.display_name LIKE 'ZZZ Searchable %'
      OR c.name_en LIKE 'E2E Seed Customer %'
      OR c.name_en LIKE 'ZZZ Searchable %'
      OR c.name_en IN ('Walk-in Customer', 'John Smith', 'ABC Restaurant', 'Khmer Clinic')
      OR c.phone IN ('000000000', '+855 10 555 001', '+855 23 555 002', '+855 78 555 003')
  ) seeded_sales
);

DELETE FROM sale_items
WHERE sale_id IN (
  SELECT sale_id FROM (
    SELECT s.id AS sale_id
    FROM sales s
    JOIN customers c ON c.id = s.customer_id
    WHERE c.customer_code LIKE 'E2E%'
      OR c.customer_code BETWEEN 'CUST-0001' AND 'CUST-0020'
      OR c.display_name LIKE 'E2E Seed Customer %'
      OR c.display_name LIKE 'ZZZ Searchable %'
      OR c.name_en LIKE 'E2E Seed Customer %'
      OR c.name_en LIKE 'ZZZ Searchable %'
      OR c.name_en IN ('Walk-in Customer', 'John Smith', 'ABC Restaurant', 'Khmer Clinic')
      OR c.phone IN ('000000000', '+855 10 555 001', '+855 23 555 002', '+855 78 555 003')
  ) seeded_sales
);

DELETE FROM sales
WHERE customer_id IN (
  SELECT customer_id FROM (
    SELECT c.id AS customer_id
    FROM customers c
    WHERE c.customer_code LIKE 'E2E%'
      OR c.customer_code BETWEEN 'CUST-0001' AND 'CUST-0020'
      OR c.display_name LIKE 'E2E Seed Customer %'
      OR c.display_name LIKE 'ZZZ Searchable %'
      OR c.name_en LIKE 'E2E Seed Customer %'
      OR c.name_en LIKE 'ZZZ Searchable %'
      OR c.name_en IN ('Walk-in Customer', 'John Smith', 'ABC Restaurant', 'Khmer Clinic')
      OR c.phone IN ('000000000', '+855 10 555 001', '+855 23 555 002', '+855 78 555 003')
  ) seeded_customers
);

DELETE FROM carts
WHERE customer_id IN (
  SELECT customer_id FROM (
    SELECT c.id AS customer_id
    FROM customers c
    WHERE c.customer_code LIKE 'E2E%'
      OR c.customer_code BETWEEN 'CUST-0001' AND 'CUST-0020'
      OR c.display_name LIKE 'E2E Seed Customer %'
      OR c.display_name LIKE 'ZZZ Searchable %'
      OR c.name_en LIKE 'E2E Seed Customer %'
      OR c.name_en LIKE 'ZZZ Searchable %'
      OR c.name_en IN ('Walk-in Customer', 'John Smith', 'ABC Restaurant', 'Khmer Clinic')
      OR c.phone IN ('000000000', '+855 10 555 001', '+855 23 555 002', '+855 78 555 003')
  ) seeded_customers
);

DELETE FROM customer_credit_allocations
WHERE customer_id IN (
  SELECT customer_id FROM (
    SELECT c.id AS customer_id
    FROM customers c
    WHERE c.customer_code LIKE 'E2E%'
      OR c.customer_code BETWEEN 'CUST-0001' AND 'CUST-0020'
      OR c.display_name LIKE 'E2E Seed Customer %'
      OR c.display_name LIKE 'ZZZ Searchable %'
      OR c.name_en LIKE 'E2E Seed Customer %'
      OR c.name_en LIKE 'ZZZ Searchable %'
      OR c.name_en IN ('Walk-in Customer', 'John Smith', 'ABC Restaurant', 'Khmer Clinic')
      OR c.phone IN ('000000000', '+855 10 555 001', '+855 23 555 002', '+855 78 555 003')
  ) seeded_customers
);

DELETE FROM customer_adjustments
WHERE customer_id IN (
  SELECT customer_id FROM (
    SELECT c.id AS customer_id
    FROM customers c
    WHERE c.customer_code LIKE 'E2E%'
      OR c.customer_code BETWEEN 'CUST-0001' AND 'CUST-0020'
      OR c.display_name LIKE 'E2E Seed Customer %'
      OR c.display_name LIKE 'ZZZ Searchable %'
      OR c.name_en LIKE 'E2E Seed Customer %'
      OR c.name_en LIKE 'ZZZ Searchable %'
      OR c.name_en IN ('Walk-in Customer', 'John Smith', 'ABC Restaurant', 'Khmer Clinic')
      OR c.phone IN ('000000000', '+855 10 555 001', '+855 23 555 002', '+855 78 555 003')
  ) seeded_customers
);

DELETE FROM customer_credit_opening_balances
WHERE customer_id IN (
  SELECT customer_id FROM (
    SELECT c.id AS customer_id
    FROM customers c
    WHERE c.customer_code LIKE 'E2E%'
      OR c.customer_code BETWEEN 'CUST-0001' AND 'CUST-0020'
      OR c.display_name LIKE 'E2E Seed Customer %'
      OR c.display_name LIKE 'ZZZ Searchable %'
      OR c.name_en LIKE 'E2E Seed Customer %'
      OR c.name_en LIKE 'ZZZ Searchable %'
      OR c.name_en IN ('Walk-in Customer', 'John Smith', 'ABC Restaurant', 'Khmer Clinic')
      OR c.phone IN ('000000000', '+855 10 555 001', '+855 23 555 002', '+855 78 555 003')
  ) seeded_customers
);

DELETE FROM customer_credit_accounts
WHERE customer_id IN (
  SELECT customer_id FROM (
    SELECT c.id AS customer_id
    FROM customers c
    WHERE c.customer_code LIKE 'E2E%'
      OR c.customer_code BETWEEN 'CUST-0001' AND 'CUST-0020'
      OR c.display_name LIKE 'E2E Seed Customer %'
      OR c.display_name LIKE 'ZZZ Searchable %'
      OR c.name_en LIKE 'E2E Seed Customer %'
      OR c.name_en LIKE 'ZZZ Searchable %'
      OR c.name_en IN ('Walk-in Customer', 'John Smith', 'ABC Restaurant', 'Khmer Clinic')
      OR c.phone IN ('000000000', '+855 10 555 001', '+855 23 555 002', '+855 78 555 003')
  ) seeded_customers
);

DELETE FROM delivery_notes
WHERE customer_id IN (
  SELECT customer_id FROM (
    SELECT c.id AS customer_id
    FROM customers c
    WHERE c.customer_code LIKE 'E2E%'
      OR c.customer_code BETWEEN 'CUST-0001' AND 'CUST-0020'
      OR c.display_name LIKE 'E2E Seed Customer %'
      OR c.display_name LIKE 'ZZZ Searchable %'
      OR c.name_en LIKE 'E2E Seed Customer %'
      OR c.name_en LIKE 'ZZZ Searchable %'
      OR c.name_en IN ('Walk-in Customer', 'John Smith', 'ABC Restaurant', 'Khmer Clinic')
      OR c.phone IN ('000000000', '+855 10 555 001', '+855 23 555 002', '+855 78 555 003')
  ) seeded_customers
);

DELETE FROM eod_customer_credits
WHERE customer_id IN (
  SELECT customer_id FROM (
    SELECT c.id AS customer_id
    FROM customers c
    WHERE c.customer_code LIKE 'E2E%'
      OR c.customer_code BETWEEN 'CUST-0001' AND 'CUST-0020'
      OR c.display_name LIKE 'E2E Seed Customer %'
      OR c.display_name LIKE 'ZZZ Searchable %'
      OR c.name_en LIKE 'E2E Seed Customer %'
      OR c.name_en LIKE 'ZZZ Searchable %'
      OR c.name_en IN ('Walk-in Customer', 'John Smith', 'ABC Restaurant', 'Khmer Clinic')
      OR c.phone IN ('000000000', '+855 10 555 001', '+855 23 555 002', '+855 78 555 003')
  ) seeded_customers
);

DELETE FROM eod_invoice_snapshots
WHERE customer_id IN (
  SELECT customer_id FROM (
    SELECT c.id AS customer_id
    FROM customers c
    WHERE c.customer_code LIKE 'E2E%'
      OR c.customer_code BETWEEN 'CUST-0001' AND 'CUST-0020'
      OR c.display_name LIKE 'E2E Seed Customer %'
      OR c.display_name LIKE 'ZZZ Searchable %'
      OR c.name_en LIKE 'E2E Seed Customer %'
      OR c.name_en LIKE 'ZZZ Searchable %'
      OR c.name_en IN ('Walk-in Customer', 'John Smith', 'ABC Restaurant', 'Khmer Clinic')
      OR c.phone IN ('000000000', '+855 10 555 001', '+855 23 555 002', '+855 78 555 003')
  ) seeded_customers
);

DELETE FROM customers
WHERE customer_code LIKE 'E2E%'
  OR customer_code BETWEEN 'CUST-0001' AND 'CUST-0020'
  OR display_name LIKE 'E2E Seed Customer %'
  OR display_name LIKE 'ZZZ Searchable %'
  OR name_en LIKE 'E2E Seed Customer %'
  OR name_en LIKE 'ZZZ Searchable %'
  OR name_en IN ('Walk-in Customer', 'John Smith', 'ABC Restaurant', 'Khmer Clinic')
  OR phone IN ('000000000', '+855 10 555 001', '+855 23 555 002', '+855 78 555 003');
