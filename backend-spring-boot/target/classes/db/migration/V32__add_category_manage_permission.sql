-- V32: Add missing category manage permission for OWNER role

-- Ensure PERM_CATEGORY_MANAGE permission exists
INSERT INTO permissions (name, description)
SELECT 'PERM_CATEGORY_MANAGE', 'Manage categories'
WHERE NOT EXISTS (
  SELECT 1 FROM permissions WHERE name = 'PERM_CATEGORY_MANAGE'
);

-- Grant PERM_CATEGORY_MANAGE to OWNER role
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.name = 'PERM_CATEGORY_MANAGE'
WHERE r.name = 'OWNER'
  AND NOT EXISTS (
    SELECT 1 FROM role_permissions rp
    WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );

-- Grant PERM_CATEGORY_MANAGE to MANAGER role
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.name = 'PERM_CATEGORY_MANAGE'
WHERE r.name = 'MANAGER'
  AND NOT EXISTS (
    SELECT 1 FROM role_permissions rp
    WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );
