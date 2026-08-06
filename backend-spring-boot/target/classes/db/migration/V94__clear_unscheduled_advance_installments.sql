UPDATE employee_advances
SET installment_amount = NULL
WHERE installment_count IS NULL;
