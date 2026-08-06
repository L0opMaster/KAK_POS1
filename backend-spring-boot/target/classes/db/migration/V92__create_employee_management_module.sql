CREATE TABLE employees (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    employee_code VARCHAR(30) UNIQUE,
    full_name VARCHAR(140) NOT NULL,
    phone VARCHAR(40),
    email VARCHAR(150),
    position VARCHAR(80),
    department VARCHAR(80),
    hire_date DATE,
    base_salary DECIMAL(15,2) NOT NULL DEFAULT 0,
    pay_type VARCHAR(20) NOT NULL DEFAULT 'MONTHLY',
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    linked_user_id BIGINT NULL,
    notes TEXT,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_employee_user FOREIGN KEY (linked_user_id) REFERENCES users(id)
);

CREATE TABLE employee_expenses (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    expense_date DATE NOT NULL,
    description VARCHAR(255) NOT NULL,
    amount DECIMAL(15,2) NOT NULL DEFAULT 0,
    payment_method VARCHAR(30) DEFAULT 'CASH',
    reference VARCHAR(100),
    note TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by_id BIGINT NULL,
    approved_by_id BIGINT NULL,
    approved_at TIMESTAMP NULL,
    paid_at TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_employee_expense_employee FOREIGN KEY (employee_id) REFERENCES employees(id),
    CONSTRAINT fk_employee_expense_created_by FOREIGN KEY (created_by_id) REFERENCES users(id),
    CONSTRAINT fk_employee_expense_approved_by FOREIGN KEY (approved_by_id) REFERENCES users(id)
);

CREATE TABLE employee_advances (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    advance_date DATE NOT NULL,
    type VARCHAR(20) NOT NULL DEFAULT 'ADVANCE',
    amount DECIMAL(15,2) NOT NULL DEFAULT 0,
    remaining_balance DECIMAL(15,2) NOT NULL DEFAULT 0,
    repayment_method VARCHAR(30) NOT NULL DEFAULT 'PAYROLL_DEDUCTION',
    status VARCHAR(20) NOT NULL DEFAULT 'OPEN',
    note TEXT,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by_id BIGINT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_employee_advance_employee FOREIGN KEY (employee_id) REFERENCES employees(id),
    CONSTRAINT fk_employee_advance_created_by FOREIGN KEY (created_by_id) REFERENCES users(id)
);

CREATE TABLE employee_advance_payments (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    advance_id BIGINT NOT NULL,
    payment_date DATE NOT NULL,
    amount DECIMAL(15,2) NOT NULL DEFAULT 0,
    source VARCHAR(20) NOT NULL DEFAULT 'MANUAL',
    reference VARCHAR(100),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_employee_advance_payment_advance FOREIGN KEY (advance_id) REFERENCES employee_advances(id)
);

CREATE TABLE payroll_runs (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    pay_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    total_gross DECIMAL(15,2) NOT NULL DEFAULT 0,
    total_deductions DECIMAL(15,2) NOT NULL DEFAULT 0,
    total_net DECIMAL(15,2) NOT NULL DEFAULT 0,
    note TEXT,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by_id BIGINT NULL,
    approved_by_id BIGINT NULL,
    approved_at TIMESTAMP NULL,
    paid_at TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_payroll_run_created_by FOREIGN KEY (created_by_id) REFERENCES users(id),
    CONSTRAINT fk_payroll_run_approved_by FOREIGN KEY (approved_by_id) REFERENCES users(id)
);

CREATE TABLE payroll_lines (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    payroll_run_id BIGINT NOT NULL,
    employee_id BIGINT NOT NULL,
    base_pay DECIMAL(15,2) NOT NULL DEFAULT 0,
    bonus DECIMAL(15,2) NOT NULL DEFAULT 0,
    deductions DECIMAL(15,2) NOT NULL DEFAULT 0,
    advance_deduction DECIMAL(15,2) NOT NULL DEFAULT 0,
    net_pay DECIMAL(15,2) NOT NULL DEFAULT 0,
    note TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_payroll_line_run FOREIGN KEY (payroll_run_id) REFERENCES payroll_runs(id),
    CONSTRAINT fk_payroll_line_employee FOREIGN KEY (employee_id) REFERENCES employees(id),
    CONSTRAINT uq_payroll_line_employee UNIQUE (payroll_run_id, employee_id)
);

INSERT INTO permissions (name, description)
SELECT 'EMPLOYEE_VIEW', 'View employee profiles and balances'
WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE name = 'EMPLOYEE_VIEW');

INSERT INTO permissions (name, description)
SELECT 'EMPLOYEE_MANAGE', 'Manage employees, employee expenses, and advances'
WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE name = 'EMPLOYEE_MANAGE');

INSERT INTO permissions (name, description)
SELECT 'PAYROLL_VIEW', 'View payroll runs and payroll lines'
WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE name = 'PAYROLL_VIEW');

INSERT INTO permissions (name, description)
SELECT 'PAYROLL_MANAGE', 'Create, approve, and pay payroll runs'
WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE name = 'PAYROLL_MANAGE');

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p ON p.name IN ('EMPLOYEE_VIEW', 'EMPLOYEE_MANAGE', 'PAYROLL_VIEW', 'PAYROLL_MANAGE')
WHERE r.name IN ('OWNER', 'ADMIN')
  AND NOT EXISTS (SELECT 1 FROM role_permissions rp WHERE rp.role_id = r.id AND rp.permission_id = p.id);

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p ON p.name IN ('EMPLOYEE_VIEW', 'EMPLOYEE_MANAGE', 'PAYROLL_VIEW')
WHERE r.name = 'MANAGER'
  AND NOT EXISTS (SELECT 1 FROM role_permissions rp WHERE rp.role_id = r.id AND rp.permission_id = p.id);

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p ON p.name IN ('EMPLOYEE_VIEW', 'PAYROLL_VIEW', 'PAYROLL_MANAGE')
WHERE r.name = 'ACCOUNTANT'
  AND NOT EXISTS (SELECT 1 FROM role_permissions rp WHERE rp.role_id = r.id AND rp.permission_id = p.id);

CREATE INDEX idx_employee_status ON employees(status);
CREATE INDEX idx_employee_expense_employee ON employee_expenses(employee_id);
CREATE INDEX idx_employee_advance_employee ON employee_advances(employee_id);
CREATE INDEX idx_payroll_run_period ON payroll_runs(period_start, period_end);
