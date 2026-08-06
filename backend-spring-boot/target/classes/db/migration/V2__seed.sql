-- V2__seed.sql
-- Seed data for KAKNNEA POS MVP

-- Roles
INSERT INTO roles (name, description, active) VALUES
  ('OWNER', 'Business Owner - Full system access', TRUE),
  ('MANAGER', 'Store Manager - Sales and reports', TRUE),
  ('CASHIER', 'Point of Sale Operator', TRUE),
  ('ACCOUNTANT', 'Financial reports and audits', TRUE);

-- Permissions
INSERT INTO permissions (name, description) VALUES
  ('PRODUCT_MANAGE', 'Manage products and inventory'),
  ('POS_SALE', 'Create and process sales'),
  ('CUSTOMER_MANAGE', 'Manage customer accounts'),
  ('REPORTS_VIEW', 'View financial reports'),
  ('USERS_MANAGE', 'Manage user accounts'),
  ('SETTINGS_MANAGE', 'System settings'),
  ('INVENTORY_ADJUST', 'Adjust stock levels'),
  ('SHIFT_MANAGE', 'Manage cashier shifts'),
  ('PAYMENT_PROCESS', 'Process payments'),
  ('VOID_SALE', 'Void sales transactions');

-- Role Permissions (OWNER has all permissions)
INSERT INTO role_permissions (role_id, permission_id) VALUES
  (1, 1), (1, 2), (1, 3), (1, 4), (1, 5), (1, 6), (1, 7), (1, 8), (1, 9), (1, 10),
  -- MANAGER
  (2, 1), (2, 2), (2, 3), (2, 4), (2, 7), (2, 8), (2, 9),
  -- CASHIER
  (3, 2), (3, 3), (3, 9),
  -- ACCOUNTANT
  (4, 4);

-- Users (Password: Password123!)
-- Bcrypt hash of "Password123!" with strength 10
INSERT INTO users (email, password_hash, full_name, phone, active, created_at) VALUES
  ('owner@kaknnea.local', '$2a$10$wSr0RBFuDlX17/BqATEoseZLW.j74GsTVj7KV19HK.tyiPBCymlP.', 'Owner User', '+855 10 123 001', TRUE, NOW()),
  ('manager@kaknnea.local', '$2a$10$wSr0RBFuDlX17/BqATEoseZLW.j74GsTVj7KV19HK.tyiPBCymlP.', 'Manager User', '+855 10 123 002', TRUE, NOW()),
  ('cashier@kaknnea.local', '$2a$10$wSr0RBFuDlX17/BqATEoseZLW.j74GsTVj7KV19HK.tyiPBCymlP.', 'Cashier User', '+855 10 123 003', TRUE, NOW()),
  ('accountant@kaknnea.local', '$2a$10$wSr0RBFuDlX17/BqATEoseZLW.j74GsTVj7KV19HK.tyiPBCymlP.', 'Accountant User', '+855 10 123 004', TRUE, NOW());

-- User Roles
INSERT INTO user_roles (user_id, role_id) VALUES
  (1, 1), -- owner = OWNER role
  (2, 2), -- manager = MANAGER role
  (3, 3), -- cashier = CASHIER role
  (4, 4); -- accountant = ACCOUNTANT role

-- Business Settings
INSERT INTO business_settings (business_name, business_address, business_phone, business_email, tax_id, default_currency, default_language, created_at) VALUES
  ('KAKNNEA POS System', 'Phnom Penh, Cambodia', '+855 23 123 456', 'info@kaknnea.local', 'TAX-KH-2024', 'KHR', 'km', NOW());

-- Categories
INSERT INTO categories (name_km, name_en, display_order, active, created_at) VALUES
  ('ភេសជ្ជៈ', 'Beverages', 1, TRUE, NOW()),
  ('អាហារស្ងuff', 'Food', 2, TRUE, NOW()),
  ('សម្ភារៈលម្អ', 'Accessories', 3, TRUE, NOW());

-- Products (10 sample products)
INSERT INTO products (category_id, sku, barcode, name_km, name_en, price, cost, active, created_at) VALUES
  (1, 'SKU-001', '8850000101', 'កាហ្វេទឹកកក', 'Iced Coffee', 2.50, 1.00, TRUE, NOW()),
  (1, 'SKU-002', '8850000102', 'តែទឹកដោះគោ', 'Milk Tea', 2.00, 0.80, TRUE, NOW()),
  (1, 'SKU-003', '8850000103', 'ទឹកក្រូច', 'Lemonade', 1.50, 0.50, TRUE, NOW()),
  (2, 'SKU-004', '8850000104', 'បងាឡាប្រហែល', 'Rice Cake', 1.00, 0.40, TRUE, NOW()),
  (2, 'SKU-005', '8850000105', 'នំលក់មាច់', 'Donuts', 1.25, 0.50, TRUE, NOW()),
  (2, 'SKU-006', '8850000106', 'សាច់ក្រក', 'Grilled Meat', 5.00, 2.50, TRUE, NOW()),
  (3, 'SKU-007', '8850000107', 'ស្ពring ប្លាស្ទិក', 'Plastic Cup', 0.50, 0.15, TRUE, NOW()),
  (3, 'SKU-008', '8850000108', 'ស្ពring ក្រដាស', 'Paper Cup', 0.30, 0.10, TRUE, NOW()),
  (1, 'SKU-009', '8850000109', 'ម៉ាច់ចលោះ', 'Smoothie', 3.00, 1.20, TRUE, NOW()),
  (2, 'SKU-010', '8850000110', 'សម្លរា', 'Sandwich', 3.50, 1.50, TRUE, NOW());

-- Stocks (Initialize stock for all products)
INSERT INTO stocks (product_id, quantity, fifo_value, created_at) VALUES
  (1, 100, 100.00, NOW()),
  (2, 80, 64.00, NOW()),
  (3, 120, 60.00, NOW()),
  (4, 150, 60.00, NOW()),
  (5, 100, 50.00, NOW()),
  (6, 50, 125.00, NOW()),
  (7, 200, 30.00, NOW()),
  (8, 300, 30.00, NOW()),
  (9, 60, 72.00, NOW()),
  (10, 40, 60.00, NOW());

-- Customers (Walk-in and sample customers)
INSERT INTO customers (type, name, business_name, phone, credit_limit, credit_balance, active, created_at) VALUES
  ('INDIVIDUAL', 'Walk-in Customer', NULL, '000000000', 0.00, 0.00, TRUE, NOW()),
  ('INDIVIDUAL', 'John Smith', NULL, '+855 10 555 001', 100.00, 0.00, TRUE, NOW()),
  ('BUSINESS', 'ABC Restaurant', NULL, '+855 23 555 002', 500.00, 0.00, TRUE, NOW()),
  ('INDIVIDUAL', 'Khmer Clinic', 'Health Clinic', '+855 78 555 003', 200.00, 0.00, TRUE, NOW());

