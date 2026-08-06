ALTER TABLE employee_advances
    ADD COLUMN installment_count INT NULL AFTER repayment_method,
    ADD COLUMN installment_amount DECIMAL(15,2) NULL AFTER installment_count;

UPDATE employee_advances
SET installment_amount = remaining_balance
WHERE repayment_method = 'PAYROLL_DEDUCTION'
  AND installment_amount IS NULL
  AND remaining_balance > 0;
