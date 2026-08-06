-- Add EXPENSE_MANAGE and ADMIN permissions to the permissions table
-- ADMIN is used as a broad "elevated access" permission for the frontend nav guard
-- EXPENSE_MANAGE grants access to the expense module

INSERT IGNORE INTO permissions (name, description) VALUES
  ('EXPENSE_MANAGE', 'Record and approve business expenses'),
  ('ADMIN', 'Elevated administrative access'),
  ('REPORT_VIEW', 'View financial and operational reports'),
  ('SUPPLIER_MANAGE', 'Manage supplier and vendor records'),
  ('PURCHASE_MANAGE', 'Create and process purchase orders'),
  ('INVENTORY_MANAGE', 'Manage stock levels, transfers and adjustments'),
  ('OWNER', 'Full system owner access'),
  ('CUSTOMER_VIEW', 'View customer records');

-- Grant EXPENSE_MANAGE to OWNER (1), MANAGER (2), ACCOUNTANT (4)
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r, permissions p
WHERE p.name = 'EXPENSE_MANAGE'
  AND r.name IN ('OWNER', 'MANAGER', 'ACCOUNTANT')
  AND NOT EXISTS (
    SELECT 1 FROM role_permissions rp WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );

-- Grant ADMIN to OWNER only
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r, permissions p
WHERE p.name = 'ADMIN'
  AND r.name = 'OWNER'
  AND NOT EXISTS (
    SELECT 1 FROM role_permissions rp WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );

-- Grant REPORT_VIEW to OWNER and MANAGER (alias for existing REPORTS_VIEW)
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r, permissions p
WHERE p.name = 'REPORT_VIEW'
  AND r.name IN ('OWNER', 'MANAGER', 'ACCOUNTANT')
  AND NOT EXISTS (
    SELECT 1 FROM role_permissions rp WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );

-- Grant SUPPLIER_MANAGE and PURCHASE_MANAGE to OWNER and MANAGER
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r, permissions p
WHERE p.name IN ('SUPPLIER_MANAGE', 'PURCHASE_MANAGE', 'INVENTORY_MANAGE')
  AND r.name IN ('OWNER', 'MANAGER')
  AND NOT EXISTS (
    SELECT 1 FROM role_permissions rp WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );

-- Grant OWNER permission to OWNER role
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r, permissions p
WHERE p.name = 'OWNER'
  AND r.name = 'OWNER'
  AND NOT EXISTS (
    SELECT 1 FROM role_permissions rp WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );
