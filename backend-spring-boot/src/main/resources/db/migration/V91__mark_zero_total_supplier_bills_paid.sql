UPDATE supplier_invoices
SET paid_amount = 0,
    outstanding_amount = 0,
    status = 'PAID'
WHERE UPPER(COALESCE(status, '')) <> 'VOID'
  AND COALESCE(total_amount, 0) = 0;
