-- Seed extended POS payment methods (ABA, KHQR, etc.)
-- Only inserts if they don't already exist.

INSERT IGNORE INTO payment_methods (code, name, display_order, is_cash, active)
VALUES ('ABA', 'ABA Pay', 10, 0, 1);

INSERT IGNORE INTO payment_methods (code, name, display_order, is_cash, active)
VALUES ('KHQR', 'KHQR', 20, 0, 1);

INSERT IGNORE INTO payment_methods (code, name, display_order, is_cash, active)
VALUES ('WING', 'Wing', 30, 0, 1);

INSERT IGNORE INTO payment_methods (code, name, display_order, is_cash, active)
VALUES ('ACLEDA', 'ACLEDA Bank', 40, 0, 1);

INSERT IGNORE INTO payment_methods (code, name, display_order, is_cash, active)
VALUES ('TRUE_MONEY', 'TrueMoney', 50, 0, 1);

INSERT IGNORE INTO payment_methods (code, name, display_order, is_cash, active)
VALUES ('CHECK', 'Check', 60, 0, 1);

INSERT IGNORE INTO payment_methods (code, name, display_order, is_cash, active)
VALUES ('OTHER', 'Other', 999, 0, 1);
