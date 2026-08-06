-- Dedicated system administrator account for application setup and security configuration.
-- Password: Password123!

INSERT IGNORE INTO roles (name, description, active)
VALUES ('SYSTEM_ADMIN', 'System Administrator - unrestricted platform configuration', TRUE);

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p
WHERE r.name = 'SYSTEM_ADMIN'
  AND NOT EXISTS (
    SELECT 1
    FROM role_permissions rp
    WHERE rp.role_id = r.id
      AND rp.permission_id = p.id
  );

INSERT IGNORE INTO users (email, password_hash, full_name, phone, active, created_at)
VALUES (
  'system.admin@kaknnea.local',
  '$2a$10$wSr0RBFuDlX17/BqATEoseZLW.j74GsTVj7KV19HK.tyiPBCymlP.',
  'System Admin',
  '+855 10 123 000',
  TRUE,
  NOW()
);

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM users u
JOIN roles r ON r.name = 'SYSTEM_ADMIN'
WHERE u.email = 'system.admin@kaknnea.local'
  AND NOT EXISTS (
    SELECT 1
    FROM user_roles ur
    WHERE ur.user_id = u.id
      AND ur.role_id = r.id
  );
