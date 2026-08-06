-- V33: Modifiers (groups/options) and product assignments

CREATE TABLE IF NOT EXISTS modifier_groups (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  name_en VARCHAR(120) NOT NULL,
  name_km VARCHAR(120) NOT NULL,
  required BOOLEAN NOT NULL DEFAULT FALSE,
  multi_select BOOLEAN NOT NULL DEFAULT FALSE,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  display_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL,
  INDEX idx_modifier_groups_active (active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS modifier_options (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  group_id BIGINT NOT NULL,
  name_en VARCHAR(120) NOT NULL,
  name_km VARCHAR(120) NOT NULL,
  price_delta DECIMAL(18,2) NOT NULL DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  display_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL,
  CONSTRAINT fk_modifier_options_group FOREIGN KEY (group_id) REFERENCES modifier_groups(id) ON DELETE CASCADE,
  INDEX idx_modifier_options_active (active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS product_modifier_groups (
  product_id BIGINT NOT NULL,
  group_id BIGINT NOT NULL,
  PRIMARY KEY (product_id, group_id),
  CONSTRAINT fk_product_modifier_groups_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
  CONSTRAINT fk_product_modifier_groups_group FOREIGN KEY (group_id) REFERENCES modifier_groups(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Permissions for modifier management
INSERT INTO permissions (name, description)
SELECT 'PERM_MODIFIER_MANAGE', 'Manage modifier groups and options'
WHERE NOT EXISTS (
  SELECT 1 FROM permissions WHERE name = 'PERM_MODIFIER_MANAGE'
);

-- Grant to OWNER and MANAGER
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.name = 'PERM_MODIFIER_MANAGE'
WHERE r.name IN ('OWNER', 'MANAGER')
  AND NOT EXISTS (
    SELECT 1 FROM role_permissions rp
    WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );
