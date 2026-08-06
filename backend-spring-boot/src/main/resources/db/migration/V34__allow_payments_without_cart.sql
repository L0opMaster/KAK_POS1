-- Allow customer repayments without a cart
ALTER TABLE payments
  MODIFY cart_id BIGINT NULL;
