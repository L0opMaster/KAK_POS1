-- Add missing TRANSFER_MANAGE permission — StockTransferController's endpoints
-- require @PreAuthorize("hasAuthority('PERM_TRANSFER_MANAGE')") but this
-- permission was never seeded, so Transfer Orders was inaccessible to everyone.

INSERT IGNORE INTO permissions (name, description) VALUES
  ('TRANSFER_MANAGE', 'Create and process stock transfer orders');

-- Grant TRANSFER_MANAGE to OWNER and MANAGER, same as the other inventory permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r, permissions p
WHERE p.name = 'TRANSFER_MANAGE'
  AND r.name IN ('OWNER', 'MANAGER')
  AND NOT EXISTS (
    SELECT 1 FROM role_permissions rp WHERE rp.role_id = r.id AND rp.permission_id = p.id
  );
