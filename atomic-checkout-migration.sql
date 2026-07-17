-- Atomic Checkout Migration for KasirApp
-- This migration implements ACID-compliant checkout transactions
-- Solves release blockers: non-transactional updates, race conditions, no rollback

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Update sales table to include customer_id (if not already added by customers-migration)
-- Check if customers table exists first to avoid dependency error
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'customers') THEN
    ALTER TABLE sales ADD COLUMN IF NOT EXISTS customer_id UUID REFERENCES customers(id) ON DELETE SET NULL;
  ELSE
    ALTER TABLE sales ADD COLUMN IF NOT EXISTS customer_id UUID;
  END IF;
END $$;

-- Update sales table to include discount and tax fields (if not already added)
-- Check if discounts table exists first to avoid dependency error
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'discounts') THEN
    ALTER TABLE sales ADD COLUMN IF NOT EXISTS discount_id UUID REFERENCES discounts(id) ON DELETE SET NULL;
  ELSE
    ALTER TABLE sales ADD COLUMN IF NOT EXISTS discount_id UUID;
  END IF;
END $$;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS discount_amount DECIMAL(10, 2) DEFAULT 0;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS tax_rate DECIMAL(5, 2) DEFAULT 0;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS tax_amount DECIMAL(10, 2) DEFAULT 0;

-- Add transaction token for duplicate prevention
ALTER TABLE sales ADD COLUMN IF NOT EXISTS transaction_token TEXT UNIQUE;

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_sales_transaction_token ON sales(transaction_token);
CREATE INDEX IF NOT EXISTS idx_sales_customer_id ON sales(customer_id);
CREATE INDEX IF NOT EXISTS idx_sales_discount_id ON sales(discount_id);

-- ============================================================================
-- ATOMIC CHECKOUT RPC FUNCTION
-- This function performs the entire checkout in a single database transaction
-- ============================================================================

CREATE OR REPLACE FUNCTION process_checkout(
  p_items JSONB,  -- Array of items: [{product_id, quantity, price, cost}]
  p_payment_method TEXT,
  p_user_id UUID,
  p_transaction_token TEXT,
  p_customer_id UUID DEFAULT NULL,
  p_discount_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_sale_id UUID;
  v_total_amount DECIMAL(10, 2) := 0;
  v_total_cost DECIMAL(10, 2) := 0;
  v_discount_amount DECIMAL(10, 2) := 0;
  v_tax_rate DECIMAL(10, 2) := 0;
  v_tax_amount DECIMAL(10, 2) := 0;
  v_final_amount DECIMAL(10, 2) := 0;
  v_profit DECIMAL(10, 2) := 0;
  v_item RECORD;
  v_current_stock INTEGER;
  v_discount_value DECIMAL(10, 2);
  v_discount_type TEXT;
  v_min_purchase DECIMAL(10, 2);
  v_max_discount DECIMAL(10, 2);
  v_discount_valid_from TIMESTAMP WITH TIME ZONE;
  v_discount_valid_until TIMESTAMP WITH TIME ZONE;
  v_tax_enabled BOOLEAN;
  v_customer_balance DECIMAL(10, 2);
BEGIN
  -- Start transaction (implicit in RPC function)
  
  -- Check for duplicate transaction token
  IF EXISTS (
    SELECT 1 FROM sales 
    WHERE transaction_token = p_transaction_token
  ) THEN
    RAISE EXCEPTION 'Duplicate transaction: %', p_transaction_token;
  END IF;
  
  -- Validate items array is not empty
  IF jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Cannot process empty cart';
  END IF;
  
  -- Calculate subtotal and validate stock
  FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items) AS t(product_id UUID, quantity INTEGER, price DECIMAL(10, 2), cost DECIMAL(10, 2))
  LOOP
    -- Validate quantity is positive
    IF v_item.quantity <= 0 THEN
      RAISE EXCEPTION 'Invalid quantity for product %: %', v_item.product_id, v_item.quantity;
    END IF;
    
    -- Validate price is positive
    IF v_item.price <= 0 THEN
      RAISE EXCEPTION 'Invalid price for product %: %', v_item.product_id, v_item.price;
    END IF;
    
    -- Lock product row for update (prevents race conditions)
    SELECT stock INTO v_current_stock
    FROM products
    WHERE id = v_item.product_id
    AND is_active = true
    FOR UPDATE;
    
    -- Check if product exists
    IF v_current_stock IS NULL THEN
      RAISE EXCEPTION 'Product not found or inactive: %', v_item.product_id;
    END IF;
    
    -- Validate sufficient stock
    IF v_current_stock < v_item.quantity THEN
      RAISE EXCEPTION 'Insufficient stock for product %. Available: %, Required: %', 
        v_item.product_id, v_current_stock, v_item.quantity;
    END IF;
    
    -- Add to totals
    v_total_amount := v_total_amount + (v_item.price * v_item.quantity);
    v_total_cost := v_total_cost + (v_item.cost * v_item.quantity);
  END LOOP;
  
  -- Apply discount if provided
  IF p_discount_id IS NOT NULL THEN
    -- Get discount details and lock for update
    SELECT value, type, min_purchase, max_discount, valid_from, valid_until
    INTO v_discount_value, v_discount_type, v_min_purchase, v_max_discount, v_discount_valid_from, v_discount_valid_until
    FROM discounts
    WHERE id = p_discount_id
    AND is_active = true
    FOR UPDATE;
    
    -- Check if discount exists
    IF v_discount_value IS NULL THEN
      RAISE EXCEPTION 'Discount not found or inactive: %', p_discount_id;
    END IF;
    
    -- Check if discount is valid time period
    IF v_discount_valid_from > NOW() THEN
      RAISE EXCEPTION 'Discount not yet valid: %', p_discount_id;
    END IF;
    
    IF v_discount_valid_until IS NOT NULL AND v_discount_valid_until < NOW() THEN
      RAISE EXCEPTION 'Discount has expired: %', p_discount_id;
    END IF;
    
    -- Check minimum purchase requirement
    IF v_total_amount < v_min_purchase THEN
      RAISE EXCEPTION 'Minimum purchase not met for discount %. Required: %, Current: %', 
        p_discount_id, v_min_purchase, v_total_amount;
    END IF;
    
    -- Calculate discount amount
    IF v_discount_type = 'percentage' THEN
      v_discount_amount := v_total_amount * (v_discount_value / 100);
    ELSE
      v_discount_amount := v_discount_value;
    END IF;
    
    -- Apply maximum discount limit
    IF v_max_discount IS NOT NULL AND v_discount_amount > v_max_discount THEN
      v_discount_amount := v_max_discount;
    END IF;
    
    -- Ensure discount doesn't exceed total
    IF v_discount_amount > v_total_amount THEN
      v_discount_amount := v_total_amount;
    END IF;
  END IF;
  
  -- Get tax configuration
  SELECT value INTO v_tax_enabled FROM settings WHERE key = 'tax_enabled';
  IF v_tax_enabled = 'true' THEN
    SELECT value INTO v_tax_rate FROM settings WHERE key = 'tax_rate';
  END IF;
  
  -- Calculate tax on discounted amount
  v_final_amount := v_total_amount - v_discount_amount;
  IF v_tax_enabled = 'true' AND v_tax_rate > 0 THEN
    v_tax_amount := v_final_amount * (v_tax_rate / 100);
    v_final_amount := v_final_amount + v_tax_amount;
  END IF;
  
  -- Calculate profit (final amount - cost, excluding tax)
  v_profit := (v_total_amount - v_discount_amount) - v_total_cost;
  
  -- Validate final amount is positive
  IF v_final_amount <= 0 THEN
    RAISE EXCEPTION 'Final amount must be positive: %', v_final_amount;
  END IF;
  
  -- Update customer balance if customer provided
  IF p_customer_id IS NOT NULL THEN
    -- Lock customer row for update
    SELECT balance INTO v_customer_balance
    FROM customers
    WHERE id = p_customer_id
    AND is_active = true
    FOR UPDATE;
    
    -- Check if customer exists
    IF v_customer_balance IS NULL THEN
      RAISE EXCEPTION 'Customer not found or inactive: %', p_customer_id;
    END IF;
    
    -- Update customer balance (add to balance for credit customers)
    UPDATE customers
    SET balance = balance + v_final_amount,
        updated_at = NOW()
    WHERE id = p_customer_id;
  END IF;
  
  -- Create sale record
  INSERT INTO sales (
    id,
    total_amount,
    total_cost,
    profit,
    payment_method,
    customer_id,
    discount_id,
    discount_amount,
    tax_rate,
    tax_amount,
    transaction_token,
    created_by
  ) VALUES (
    uuid_generate_v4(),
    v_final_amount,
    v_total_cost,
    v_profit,
    p_payment_method,
    p_customer_id,
    p_discount_id,
    v_discount_amount,
    v_tax_rate,
    v_tax_amount,
    p_transaction_token,
    p_user_id
  ) RETURNING id INTO v_sale_id;
  
  -- Create sale items and update stock
  FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items) AS t(product_id UUID, quantity INTEGER, price DECIMAL(10, 2), cost DECIMAL(10, 2))
  LOOP
    -- Create sale item
    INSERT INTO sale_items (
      sale_id,
      product_id,
      quantity,
      price,
      cost,
      subtotal
    ) VALUES (
      v_sale_id,
      v_item.product_id,
      v_item.quantity,
      v_item.price,
      v_item.cost,
      v_item.price * v_item.quantity
    );
    
    -- Update stock (already locked, safe to update)
    UPDATE products
    SET stock = stock - v_item.quantity,
        updated_at = NOW()
    WHERE id = v_item.product_id;
    
    -- Create stock movement record
    INSERT INTO stock_movements (
      product_id,
      type,
      quantity,
      reference_id,
      created_by
    ) VALUES (
      v_item.product_id,
      'out',
      v_item.quantity,
      v_sale_id::TEXT,
      p_user_id
    );
  END LOOP;
  
  -- Return success with sale details
  RETURN jsonb_build_object(
    'success', true,
    'sale_id', v_sale_id,
    'total_amount', v_final_amount,
    'discount_amount', v_discount_amount,
    'tax_amount', v_tax_amount,
    'profit', v_profit
  );
  
EXCEPTION
  WHEN OTHERS THEN
    -- Rollback is automatic in PostgreSQL
    -- Return error details
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM,
      'detail', SQLSTATE
    );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION process_checkout TO authenticated;

-- Add comment
COMMENT ON FUNCTION process_checkout IS 'Atomic checkout function that creates sale, items, updates stock, and handles discounts/taxes in a single transaction';
