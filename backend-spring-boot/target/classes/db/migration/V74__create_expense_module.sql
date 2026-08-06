-- Expense Categories
CREATE TABLE expense_categories (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name_en VARCHAR(120) NOT NULL,
    name_km VARCHAR(120) NOT NULL,
    color VARCHAR(20) DEFAULT '#6366f1',
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6)
);

INSERT INTO expense_categories (name_en, name_km, color, active, created_at) VALUES
('Rent & Utilities', 'ជួល និងប្រាក់ប្រើប្រាស់', '#6366f1', true, NOW()),
('Salaries & Wages', 'ប្រាក់ខែ និងប្រាក់ឈ្នួល', '#10b981', true, NOW()),
('Supplies & Materials', 'ការផ្គត់ផ្គង់ និងសម្ភារៈ', '#f59e0b', true, NOW()),
('Marketing & Advertising', 'ទីផ្សារ និងការផ្សាយពាណិជ្ជកម្ម', '#3b82f6', true, NOW()),
('Transport & Delivery', 'ដឹកជញ្ជូន និងចែកចាយ', '#f97316', true, NOW()),
('Repairs & Maintenance', 'ជួសជុល និងថែទាំ', '#8b5cf6', true, NOW()),
('Food & Entertainment', 'អាហារ និងកំសាន្ត', '#ec4899', true, NOW()),
('Bank & Finance Charges', 'ការគិតប្រាក់ធនាគារ', '#06b6d4', true, NOW()),
('Other', 'ផ្សេងៗ', '#94a3b8', true, NOW());

-- Expenses
CREATE TABLE expenses (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    expense_number VARCHAR(30) UNIQUE,
    expense_date DATE NOT NULL,
    category_id BIGINT NOT NULL,
    description VARCHAR(255) NOT NULL,
    amount DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    payment_method VARCHAR(30) NOT NULL DEFAULT 'CASH',
    reference VARCHAR(100),
    note TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    created_by_id BIGINT,
    approved_by_id BIGINT,
    approved_at DATETIME(6),
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6),
    CONSTRAINT fk_expense_category FOREIGN KEY (category_id) REFERENCES expense_categories(id),
    CONSTRAINT fk_expense_created_by FOREIGN KEY (created_by_id) REFERENCES users(id),
    CONSTRAINT fk_expense_approved_by FOREIGN KEY (approved_by_id) REFERENCES users(id)
);

CREATE INDEX idx_expense_date ON expenses(expense_date);
CREATE INDEX idx_expense_category ON expenses(category_id);
CREATE INDEX idx_expense_status ON expenses(status);
