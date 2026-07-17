-- CRUD Fixes Migration
-- Fixes BUG-005, BUG-008, BUG-001, BUG-002, BUG-003, BUG-009, BUG-006
-- Date: July 18, 2026

-- ============================================================================
-- BUG-005: Atomic Stock Update RPC Function
-- ============================================================================

CREATE OR REPLACE FUNCTION public.add_stock_atomic(
  p_product_id UUID,
  p_quantity INTEGER,
  p_notes TEXT DEFAULT NULL,
  p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_stock INTEGER;
BEGIN
  -- Validate quantity
  IF p_quantity <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Quantity must be positive');
  END IF;

  -- Atomic stock increment
  UPDATE products
  SET stock = stock + p_quantity,
      updated_at = NOW()
  WHERE id = p_product_id
  RETURNING stock INTO v_new_stock;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Product not found');
  END IF;

  -- Create stock movement record
  INSERT INTO stock_movements (
    product_id,
    type,
    quantity,
    notes,
    created_by
  ) VALUES (
    p_product_id,
    'in',
    p_quantity,
    p_notes,
    p_user_id
  );

  RETURN jsonb_build_object(
    'success', true,
    'new_stock', v_new_stock,
    'quantity_added', p_quantity
  );
END;
$$;

-- ============================================================================
-- BUG-008: Atomic Customer Balance Update
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_customer_balance_atomic(
  p_customer_id UUID,
  p_amount DECIMAL(10, 2)
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_balance DECIMAL(10, 2);
BEGIN
  -- Atomic balance update with row-level locking
  UPDATE customers
  SET balance = balance + p_amount,
      updated_at = NOW()
  WHERE id = p_customer_id AND is_active = true
  RETURNING balance INTO v_new_balance;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Customer not found or inactive');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'new_balance', v_new_balance,
    'amount_changed', p_amount
  );
END;
$$;

-- Update process_checkout to use atomic balance update with explicit locking
CREATE OR REPLACE FUNCTION public.process_checkout(
  p_items JSONB,
  p_payment_method TEXT,
  p_user_id UUID,
  p_transaction_token TEXT DEFAULT NULL,
  p_customer_id UUID DEFAULT NULL,
  p_discount_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_item RECORD;
  v_product RECORD;
  v_final_amount DECIMAL(10, 2);
  v_total_cost DECIMAL(10, 2);
  v_total_profit DECIMAL(10, 2);
  v_sale_id UUID;
  v_sale_item_id UUID;
  v_discount RECORD;
  v_discount_amount DECIMAL(10, 2);
  v_tax_enabled BOOLEAN;
  v_tax_rate DECIMAL(5, 2);
  v_tax_amount DECIMAL(10, 2);
BEGIN
  -- Check for duplicate transaction
  IF p_transaction_token IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM sales
      WHERE transaction_token = p_transaction_token
    ) THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Duplicate transaction'
      );
    END IF;
  END IF;

  -- Validate payment method
  IF NOT EXISTS (
    SELECT 1 FROM payment_methods
    WHERE code = p_payment_method AND is_active = true
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid payment method'
    );
  END IF;

  -- Initialize totals
  v_final_amount := 0;
  v_total_cost := 0;
  v_total_profit := 0;

  -- Get tax settings
  SELECT value INTO v_tax_enabled FROM settings WHERE key = 'tax_enabled';
  SELECT value INTO v_tax_rate FROM settings WHERE key = 'tax_rate';
  
  v_tax_enabled := COALESCE(v_tax_enabled::BOOLEAN, false);
  v_tax_rate := COALESCE(v_tax_rate::DECIMAL(10, 2), 0);

  -- Get discount if provided
  IF p_discount_id IS NOT NULL THEN
    SELECT * INTO v_discount
    FROM discounts
    WHERE id = p_discount_id AND is_active = true;

    IF v_discount IS NULL THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Invalid discount'
      );
    END IF;
  END IF;

  -- Process each item with row-level locking
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    -- Lock product row for update
    SELECT * INTO v_product
    FROM products
    WHERE id = (v_item.value->>'product_id')::UUID
    AND is_active = true
    FOR UPDATE;

    IF v_product IS NULL THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Product not found or inactive'
      );
    END IF;

    -- Check stock
    IF v_product.stock < (v_item.value->>'quantity')::INTEGER THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Insufficient stock for product: ' || v_product.name
      );
    END IF;

    -- Update stock atomically
    UPDATE products
    SET stock = stock - (v_item.value->>'quantity')::INTEGER,
        updated_at = NOW()
    WHERE id = v_product.id;

    -- Calculate totals
    v_final_amount := v_final_amount + 
      ((v_item.value->>'price')::DECIMAL(10, 2) * (v_item.value->>'quantity')::INTEGER);
    v_total_cost := v_total_cost + 
      (v_product.hpp * (v_item.value->>'quantity')::INTEGER);
  END LOOP;

  -- Apply discount
  IF v_discount IS NOT NULL THEN
    IF v_discount.discount_type = 'percentage' THEN
      v_discount_amount := v_final_amount * (v_discount.discount_value / 100);
      IF v_discount.max_discount > 0 AND v_discount_amount > v_discount.max_discount THEN
        v_discount_amount := v_discount.max_discount;
      END IF;
    ELSE
      v_discount_amount := v_discount.discount_value;
    END IF;
    v_final_amount := v_final_amount - v_discount_amount;
  END IF;

  -- Calculate tax
  IF v_tax_enabled THEN
    v_tax_amount := v_final_amount * (v_tax_rate / 100);
    v_final_amount := v_final_amount + v_tax_amount;
  END IF;

  -- Calculate profit
  v_total_profit := v_final_amount - v_total_cost;

  -- Create sale record
  INSERT INTO sales (
    total_amount,
    total_cost,
    profit,
    payment_method,
    created_by,
    transaction_token,
    customer_id,
    discount_id,
    discount_amount,
    tax_amount,
    tax_rate
  ) VALUES (
    v_final_amount,
    v_total_cost,
    v_total_profit,
    p_payment_method,
    p_user_id,
    p_transaction_token,
    p_customer_id,
    p_discount_id,
    COALESCE(v_discount_amount, 0),
    COALESCE(v_tax_amount, 0),
    COALESCE(v_tax_rate, 0)
  ) RETURNING id INTO v_sale_id;

  -- Create sale items
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    INSERT INTO sale_items (
      sale_id,
      product_id,
      quantity,
      price,
      cost,
      subtotal
    ) VALUES (
      v_sale_id,
      (v_item.value->>'product_id')::UUID,
      (v_item.value->>'quantity')::INTEGER,
      (v_item.value->>'price')::DECIMAL(10, 2),
      (SELECT hpp FROM products WHERE id = (v_item.value->>'product_id')::UUID),
      (v_item.value->>'price')::DECIMAL(10, 2) * (v_item.value->>'quantity')::INTEGER
    );
  END LOOP;

  -- Update customer balance atomically with row-level locking
  IF p_customer_id IS NOT NULL THEN
    UPDATE customers
    SET balance = balance + v_final_amount,
        updated_at = NOW()
    WHERE id = p_customer_id AND is_active = true;
  END IF;

  -- Create transaction log
  INSERT INTO transaction_logs (
    sale_id,
    user_id,
    action,
    details
  ) VALUES (
    v_sale_id,
    p_user_id,
    'checkout',
    jsonb_build_object(
      'payment_method', p_payment_method,
      'total_amount', v_final_amount,
      'items_count', jsonb_array_length(p_items)
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'sale_id', v_sale_id,
    'total_amount', v_final_amount,
    'total_cost', v_total_cost,
    'profit', v_total_profit
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM,
      'detail', SQLSTATE
    );
END;
$$;

-- ============================================================================
-- BUG-001: Categories Soft Delete - Add is_active column if missing
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'categories'
    AND column_name = 'is_active'
  ) THEN
    ALTER TABLE categories ADD COLUMN is_active BOOLEAN DEFAULT true;
  END IF;
END $$;

-- ============================================================================
-- BUG-002: Customers Soft Delete - Add is_active column if missing
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'customers'
    AND column_name = 'is_active'
  ) THEN
    ALTER TABLE customers ADD COLUMN is_active BOOLEAN DEFAULT true;
  END IF;
END $$;

-- ============================================================================
-- BUG-003: Suppliers Soft Delete - Add is_active column if missing
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'suppliers'
    AND column_name = 'is_active'
  ) THEN
    ALTER TABLE suppliers ADD COLUMN is_active BOOLEAN DEFAULT true;
  END IF;
END $$;

-- ============================================================================
-- BUG-009: Ensure stock constraint exists
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'products_stock_check'
    AND conrelid = 'products'::regclass
  ) THEN
    ALTER TABLE products ADD CONSTRAINT products_stock_check
      CHECK (stock >= 0);
  END IF;
END $$;

-- ============================================================================
-- BUG-006: Unique barcode constraint allowing NULL
-- ============================================================================

-- First, drop existing constraint if it doesn't allow NULL
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'products_barcode_key'
    AND conrelid = 'products'::regclass
  ) THEN
    ALTER TABLE products DROP CONSTRAINT products_barcode_key;
  END IF;
END $$;

-- Create partial unique index that allows NULL values
CREATE UNIQUE INDEX IF NOT EXISTS idx_products_barcode_unique
ON products (barcode)
WHERE barcode IS NOT NULL;

-- ============================================================================
-- Grant execute on new functions
-- ============================================================================

GRANT EXECUTE ON FUNCTION public.add_stock_atomic TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_customer_balance_atomic TO authenticated;

-- ============================================================================
-- Record migration
-- ============================================================================

INSERT INTO schema_migrations (version, checksum, description) VALUES
('1.3.0', md5(current_timestamp::text), 'CRUD fixes: atomic stock/balance updates, soft deletes, barcode uniqueness')
ON CONFLICT (version) DO UPDATE SET
  applied_at = NOW(),
  checksum = md5(current_timestamp::text),
  description = 'CRUD fixes: atomic stock/balance updates, soft deletes, barcode uniqueness';
