-- ============================================================================
-- KasirApp Database Schema v1.0 - Production Migration
-- ============================================================================
-- Version: 1.0.0
-- Date: July 18, 2026
-- Description: Complete consolidated database schema for production deployment
-- 
-- This migration includes:
-- - All 17 tables with complete schema
-- - Row Level Security (RLS) policies with SECURITY DEFINER functions
-- - All indexes including composite indexes
-- - All triggers and functions
-- - Foreign key constraints
-- - Data validation constraints
-- - Sample data (optional)
--
-- IMPORTANT: This is a FRESH INSTALL migration. For existing databases,
-- use MIGRATION_ROADTO_V1.0.sql for zero data loss migration.
-- ============================================================================

-- ============================================================================
-- SECTION 1: Enable Extensions
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- SECTION 2: Create Schema Migrations Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS schema_migrations (
  version TEXT PRIMARY KEY,
  applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  checksum TEXT,
  description TEXT
);

-- Record this migration
INSERT INTO schema_migrations (version, checksum, description) VALUES
('1.0.0', md5(current_timestamp::text), 'Initial production schema v1.0')
ON CONFLICT (version) DO NOTHING;

-- ============================================================================
-- SECTION 3: Create SECURITY DEFINER Functions (Fix RLS Recursion)
-- ============================================================================

-- Function to check if user is admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$;

-- Function to check if user is cashier (kasir)
CREATE OR REPLACE FUNCTION public.is_kasir()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'kasir'
  );
END;
$$;

-- Function to check if user is authenticated
CREATE OR REPLACE FUNCTION public.is_authenticated()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN auth.uid() IS NOT NULL;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_kasir() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_authenticated() TO authenticated;

-- ============================================================================
-- SECTION 4: Create Utility Functions
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SECTION 5: Create Authentication Tables
-- ============================================================================

-- Profiles table - links to Supabase Auth
CREATE TABLE IF NOT EXISTS profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  email TEXT,
  name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('admin', 'kasir')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Trigger for profiles updated_at
DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Function to automatically create profile when user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', 'User'),
    COALESCE(NEW.raw_user_meta_data->>'role', 'kasir')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create profile on user signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- SECTION 6: Create Business Tables
-- ============================================================================

-- Categories table - dynamic product categories
CREATE TABLE IF NOT EXISTS categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  icon TEXT DEFAULT 'Package',
  color TEXT DEFAULT 'from-gray-500 to-gray-600',
  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Payment methods table - dynamic payment methods
CREATE TABLE IF NOT EXISTS payment_methods (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  code TEXT NOT NULL UNIQUE,
  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Settings table - application configuration
CREATE TABLE IF NOT EXISTS settings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  key TEXT NOT NULL UNIQUE,
  value TEXT NOT NULL,
  description TEXT,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Products table - product catalog
CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  category TEXT NOT NULL,  -- No CHECK constraint - dynamic categories
  price DECIMAL(10, 2) NOT NULL CHECK (price > 0),
  cost DECIMAL(10, 2) NOT NULL CHECK (cost >= 0),
  stock INTEGER DEFAULT 0 CHECK (stock >= 0),
  hpp DECIMAL(10, 2) DEFAULT 0 CHECK (hpp >= 0),
  barcode TEXT UNIQUE,
  image_url TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Trigger for products updated_at
DROP TRIGGER IF EXISTS update_products_updated_at ON products;
CREATE TRIGGER update_products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Sales table - sales transactions
CREATE TABLE IF NOT EXISTS sales (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  total_amount DECIMAL(10, 2) NOT NULL CHECK (total_amount > 0),
  total_cost DECIMAL(10, 2) NOT NULL CHECK (total_cost >= 0),
  profit DECIMAL(10, 2) NOT NULL,
  payment_method TEXT NOT NULL,  -- No CHECK constraint - dynamic payment methods
  customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
  discount_id UUID REFERENCES discounts(id) ON DELETE SET NULL,
  discount_amount DECIMAL(10, 2) DEFAULT 0 CHECK (discount_amount >= 0),
  tax_rate DECIMAL(5, 2) DEFAULT 0 CHECK (tax_rate >= 0),
  tax_amount DECIMAL(10, 2) DEFAULT 0 CHECK (tax_amount >= 0),
  transaction_token TEXT UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID REFERENCES profiles(id)
);

-- Sale items table - sale line items
CREATE TABLE IF NOT EXISTS sale_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sale_id UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id),
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  price DECIMAL(10, 2) NOT NULL CHECK (price > 0),
  cost DECIMAL(10, 2) NOT NULL CHECK (cost >= 0),
  subtotal DECIMAL(10, 2) NOT NULL CHECK (subtotal > 0),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Stock movements table - stock changes
CREATE TABLE IF NOT EXISTS stock_movements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID NOT NULL REFERENCES products(id),
  type TEXT NOT NULL CHECK (type IN ('in', 'out', 'production', 'waste')),
  quantity INTEGER NOT NULL CHECK (quantity != 0),
  reference_id TEXT,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID REFERENCES profiles(id)
);

-- Suppliers table - supplier information
CREATE TABLE IF NOT EXISTS suppliers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  contact TEXT,
  address TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Daily production table - production tracking
CREATE TABLE IF NOT EXISTS daily_production (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID NOT NULL REFERENCES products(id),
  date DATE NOT NULL,
  quantity_produced INTEGER NOT NULL DEFAULT 0 CHECK (quantity_produced >= 0),
  quantity_sold INTEGER NOT NULL DEFAULT 0 CHECK (quantity_sold >= 0),
  quantity_waste INTEGER NOT NULL DEFAULT 0 CHECK (quantity_waste >= 0),
  quantity_remaining INTEGER NOT NULL DEFAULT 0 CHECK (quantity_remaining >= 0),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID REFERENCES profiles(id),
  UNIQUE(product_id, date)
);

-- Waste items table - waste tracking
CREATE TABLE IF NOT EXISTS waste_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID NOT NULL REFERENCES products(id),
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  reason TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID REFERENCES profiles(id)
);

-- ============================================================================
-- SECTION 7: Create Customer Management Tables
-- ============================================================================

-- Customers table - customer information
CREATE TABLE IF NOT EXISTS customers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  address TEXT,
  balance DECIMAL(10, 2) DEFAULT 0,
  points INTEGER DEFAULT 0 CHECK (points >= 0),
  notes TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Trigger for customers updated_at
DROP TRIGGER IF EXISTS update_customers_updated_at ON customers;
CREATE TRIGGER update_customers_updated_at
  BEFORE UPDATE ON customers
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- SECTION 8: Create Discount Tables
-- ============================================================================

-- Discounts table - discount management
CREATE TABLE IF NOT EXISTS discounts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('percentage', 'fixed')),
  value DECIMAL(10, 2) NOT NULL CHECK (value > 0),
  min_purchase DECIMAL(10, 2) DEFAULT 0 CHECK (min_purchase >= 0),
  max_discount DECIMAL(10, 2) CHECK (max_discount > 0),
  is_active BOOLEAN DEFAULT true,
  valid_from TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  valid_until TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Trigger for discounts updated_at
DROP TRIGGER IF EXISTS update_discounts_updated_at ON discounts;
CREATE TRIGGER update_discounts_updated_at
  BEFORE UPDATE ON discounts
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- SECTION 9: Create Production Tables
-- ============================================================================

-- Raw materials table - raw material inventory
CREATE TABLE IF NOT EXISTS raw_materials (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  unit TEXT NOT NULL,  -- No CHECK constraint - dynamic units
  cost_per_unit DECIMAL(10, 2) NOT NULL CHECK (cost_per_unit > 0),
  stock DECIMAL(10, 2) DEFAULT 0 CHECK (stock >= 0),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Product recipes table - product recipes
CREATE TABLE IF NOT EXISTS product_recipes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  raw_material_id UUID NOT NULL REFERENCES raw_materials(id) ON DELETE CASCADE,
  quantity_used DECIMAL(10, 2) NOT NULL CHECK (quantity_used > 0),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(product_id, raw_material_id)
);

-- ============================================================================
-- SECTION 10: Create Expense Tables
-- ============================================================================

-- Expenses table - business expenses
CREATE TABLE IF NOT EXISTS expenses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  expense_date DATE NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('Electricity', 'Water', 'Salary', 'Rent', 'Raw Materials', 'Transportation', 'Marketing', 'Other')),
  description TEXT NOT NULL,
  amount DECIMAL(10, 2) NOT NULL CHECK (amount > 0),
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- SECTION 11: Create Audit Tables
-- ============================================================================

-- Transaction logs table - transaction modification logs
CREATE TABLE IF NOT EXISTS transaction_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  action TEXT NOT NULL CHECK (action IN ('void', 'delete', 'edit')),
  reason TEXT NOT NULL,
  old_data JSONB,
  new_data JSONB,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- SECTION 12: Create HPP Functions
-- ============================================================================

-- Function to calculate HPP for a specific product
CREATE OR REPLACE FUNCTION public.calculate_product_hpp(product_uuid UUID)
RETURNS DECIMAL AS $$
DECLARE
  total_hpp DECIMAL(10, 2) := 0;
BEGIN
  SELECT COALESCE(SUM(pr.quantity_used * rm.cost_per_unit), 0)
  INTO total_hpp
  FROM product_recipes pr
  JOIN raw_materials rm ON pr.raw_material_id = rm.id
  WHERE pr.product_id = product_uuid;
  
  RETURN total_hpp;
END;
$$ LANGUAGE plpgsql;

-- Function to update HPP for all products
CREATE OR REPLACE FUNCTION public.update_all_product_hpp()
RETURNS VOID AS $$
BEGIN
  UPDATE products
  SET hpp = calculate_product_hpp(id);
END;
$$ LANGUAGE plpgsql;

-- Trigger function for automatic HPP updates
CREATE OR REPLACE FUNCTION public.update_product_hpp_trigger()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    UPDATE products SET hpp = calculate_product_hpp(NEW.product_id) WHERE id = NEW.product_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE products SET hpp = calculate_product_hpp(OLD.product_id) WHERE id = OLD.product_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for automatic HPP updates
DROP TRIGGER IF EXISTS trigger_update_hpp_after_insert ON product_recipes;
DROP TRIGGER IF EXISTS trigger_update_hpp_after_update ON product_recipes;
DROP TRIGGER IF EXISTS trigger_update_hpp_after_delete ON product_recipes;

CREATE TRIGGER trigger_update_hpp_after_insert
  AFTER INSERT ON product_recipes
  FOR EACH ROW EXECUTE FUNCTION public.update_product_hpp_trigger();

CREATE TRIGGER trigger_update_hpp_after_update
  AFTER UPDATE ON product_recipes
  FOR EACH ROW EXECUTE FUNCTION public.update_product_hpp_trigger();

CREATE TRIGGER trigger_update_hpp_after_delete
  AFTER DELETE ON product_recipes
  FOR EACH ROW EXECUTE FUNCTION public.update_product_hpp_trigger();

-- ============================================================================
-- SECTION 13: Create Atomic Checkout Function
-- ============================================================================

CREATE OR REPLACE FUNCTION public.process_checkout(
  p_items JSONB,
  p_payment_method TEXT,
  p_user_id UUID,
  p_transaction_token TEXT,
  p_customer_id UUID DEFAULT NULL,
  p_discount_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sale_id UUID;
  v_item JSONB;
  v_product_id UUID;
  v_quantity INTEGER;
  v_price DECIMAL(10, 2);
  v_cost DECIMAL(10, 2);
  v_subtotal DECIMAL(10, 2);
  v_total_amount DECIMAL(10, 2) := 0;
  v_total_cost DECIMAL(10, 2) := 0;
  v_discount_amount DECIMAL(10, 2) := 0;
  v_tax_amount DECIMAL(10, 2) := 0;
  v_discount_value DECIMAL(10, 2);
  v_discount_type TEXT;
  v_tax_rate DECIMAL(5, 2);
  v_tax_enabled BOOLEAN;
  v_final_amount DECIMAL(10, 2);
  v_profit DECIMAL(10, 2);
  v_current_stock INTEGER;
BEGIN
  -- Duplicate token check
  IF EXISTS (SELECT 1 FROM sales WHERE transaction_token = p_transaction_token) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Duplicate transaction', 'detail', 'SQLSTATE: 23505');
  END IF;

  -- Validate items array
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'No items in cart');
  END IF;

  -- Calculate totals and validate stock
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := (v_item->>'id')::UUID;
    v_quantity := (v_item->>'quantity')::INTEGER;
    v_price := (v_item->>'price')::DECIMAL(10, 2);
    v_cost := (v_item->>'cost')::DECIMAL(10, 2);
    
    -- Validate quantity
    IF v_quantity <= 0 THEN
      RETURN jsonb_build_object('success', false, 'error', 'Invalid quantity for product');
    END IF;
    
    -- Validate price
    IF v_price <= 0 THEN
      RETURN jsonb_build_object('success', false, 'error', 'Invalid price for product');
    END IF;
    
    -- Check stock with row-level lock
    SELECT stock INTO v_current_stock
    FROM products
    WHERE id = v_product_id AND is_active = true
    FOR UPDATE;
    
    IF v_current_stock IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'Product not found or inactive');
    END IF;
    
    IF v_current_stock < v_quantity THEN
      RETURN jsonb_build_object('success', false, 'error', 'Insufficient stock');
    END IF;
    
    v_subtotal := v_price * v_quantity;
    v_total_amount := v_total_amount + v_subtotal;
    v_total_cost := v_total_cost + (v_cost * v_quantity);
  END LOOP;

  -- Apply discount if provided
  IF p_discount_id IS NOT NULL THEN
    SELECT type, value INTO v_discount_type, v_discount_value
    FROM discounts
    WHERE id = p_discount_id AND is_active = true
    AND (valid_until IS NULL OR valid_until > NOW());
    
    IF v_discount_type IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'Invalid or expired discount');
    END IF;
    
    -- Check minimum purchase
    IF EXISTS (SELECT 1 FROM discounts WHERE id = p_discount_id AND min_purchase > v_total_amount) THEN
      RETURN jsonb_build_object('success', false, 'error', 'Minimum purchase not met for discount');
    END IF;
    
    IF v_discount_type = 'percentage' THEN
      v_discount_amount := v_total_amount * (v_discount_value / 100);
      -- Apply max discount limit if set
      IF EXISTS (SELECT 1 FROM discounts WHERE id = p_discount_id AND max_discount IS NOT NULL AND v_discount_amount > max_discount) THEN
        SELECT max_discount INTO v_discount_amount FROM discounts WHERE id = p_discount_id;
      END IF;
    ELSE
      v_discount_amount := v_discount_value;
    END IF;
  END IF;

  -- Apply tax if enabled
  SELECT value INTO v_tax_rate FROM settings WHERE key = 'tax_rate';
  SELECT (value::boolean) INTO v_tax_enabled FROM settings WHERE key = 'tax_enabled';
  
  IF v_tax_enabled THEN
    v_tax_amount := (v_total_amount - v_discount_amount) * (v_tax_rate::DECIMAL(5, 2) / 100);
  END IF;

  v_final_amount := v_total_amount - v_discount_amount + v_tax_amount;
  v_profit := v_total_amount - v_total_cost - v_discount_amount;

  -- Update customer balance if customer provided
  IF p_customer_id IS NOT NULL THEN
    UPDATE customers
    SET balance = balance + v_final_amount,
        updated_at = NOW()
    WHERE id = p_customer_id AND is_active = true;
  END IF;

  -- Create sale record
  INSERT INTO sales (
    total_amount,
    total_cost,
    profit,
    payment_method,
    created_by,
    customer_id,
    discount_id,
    discount_amount,
    tax_rate,
    tax_amount,
    transaction_token
  ) VALUES (
    v_final_amount,
    v_total_cost,
    v_profit,
    p_payment_method,
    p_user_id,
    p_customer_id,
    p_discount_id,
    v_discount_amount,
    v_tax_rate,
    v_tax_amount,
    p_transaction_token
  ) RETURNING id INTO v_sale_id;

  -- Create sale items and update stock
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := (v_item->>'id')::UUID;
    v_quantity := (v_item->>'quantity')::INTEGER;
    v_price := (v_item->>'price')::DECIMAL(10, 2);
    v_cost := (v_item->>'cost')::DECIMAL(10, 2);
    
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
      v_product_id,
      v_quantity,
      v_price,
      v_cost,
      v_price * v_quantity
    );
    
    -- Update stock
    UPDATE products
    SET stock = stock - v_quantity,
        updated_at = NOW()
    WHERE id = v_product_id;
    
    -- Create stock movement record
    INSERT INTO stock_movements (
      product_id,
      type,
      quantity,
      reference_id,
      created_by
    ) VALUES (
      v_product_id,
      'out',
      v_quantity,
      v_sale_id::TEXT,
      p_user_id
    );
  END LOOP;

  -- Return success
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
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM,
      'detail', SQLSTATE
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.process_checkout TO authenticated;

-- ============================================================================
-- SECTION 14: Create Indexes
-- ============================================================================

-- Categories indexes
CREATE INDEX IF NOT EXISTS idx_categories_name ON categories(name);
CREATE INDEX IF NOT EXISTS idx_categories_active ON categories(is_active);

-- Payment methods indexes
CREATE INDEX IF NOT EXISTS idx_payment_methods_code ON payment_methods(code);
CREATE INDEX IF NOT EXISTS idx_payment_methods_active ON payment_methods(is_active);

-- Settings indexes
CREATE INDEX IF NOT EXISTS idx_settings_key ON settings(key);

-- Products indexes
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode);
CREATE INDEX IF NOT EXISTS idx_products_active ON products(is_active);
CREATE INDEX IF NOT EXISTS idx_products_active_date ON products(is_active, created_at);

-- Sales indexes
CREATE INDEX IF NOT EXISTS idx_sales_created_at ON sales(created_at);
CREATE INDEX IF NOT EXISTS idx_sales_customer_id ON sales(customer_id);
CREATE INDEX IF NOT EXISTS idx_sales_discount_id ON sales(discount_id);
CREATE INDEX IF NOT EXISTS idx_sales_transaction_token ON sales(transaction_token);
CREATE INDEX IF NOT EXISTS idx_sales_tax_rate ON sales(tax_rate);
CREATE INDEX IF NOT EXISTS idx_sales_created_by_date ON sales(created_at, created_by);
CREATE INDEX IF NOT EXISTS idx_sales_customer_date ON sales(customer_id, created_at);

-- Sale items indexes
CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON sale_items(sale_id);
CREATE INDEX IF NOT EXISTS idx_sale_items_product_id ON sale_items(product_id);
CREATE INDEX IF NOT EXISTS idx_sale_items_product_date ON sale_items(product_id, created_at);

-- Stock movements indexes
CREATE INDEX IF NOT EXISTS idx_stock_movements_product_id ON stock_movements(product_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_type ON stock_movements(type);
CREATE INDEX IF NOT EXISTS idx_stock_movements_type_date ON stock_movements(type, created_at);

-- Customers indexes
CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone);
CREATE INDEX IF NOT EXISTS idx_customers_email ON customers(email);

-- Discounts indexes
CREATE INDEX IF NOT EXISTS idx_discounts_is_active ON discounts(is_active);
CREATE INDEX IF NOT EXISTS idx_discounts_valid_period ON discounts(valid_from, valid_until);

-- Raw materials indexes
CREATE INDEX IF NOT EXISTS idx_raw_materials_name ON raw_materials(name);

-- Product recipes indexes
CREATE INDEX IF NOT EXISTS idx_product_recipes_product_id ON product_recipes(product_id);
CREATE INDEX IF NOT EXISTS idx_product_recipes_raw_material_id ON product_recipes(raw_material_id);

-- Expenses indexes
CREATE INDEX IF NOT EXISTS idx_expenses_expense_date ON expenses(expense_date);
CREATE INDEX IF NOT EXISTS idx_expenses_category ON expenses(category);
CREATE INDEX IF NOT EXISTS idx_expenses_created_by ON expenses(created_by);
CREATE INDEX IF NOT EXISTS idx_expenses_date_category ON expenses(expense_date, category);

-- Transaction logs indexes
CREATE INDEX IF NOT EXISTS idx_transaction_logs_transaction_id ON transaction_logs(transaction_id);
CREATE INDEX IF NOT EXISTS idx_transaction_logs_user_id ON transaction_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_transaction_logs_created_at ON transaction_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transaction_logs_action ON transaction_logs(action);

-- ============================================================================
-- SECTION 15: Enable Row Level Security
-- ============================================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE discounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_production ENABLE ROW LEVEL SECURITY;
ALTER TABLE waste_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction_logs ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- SECTION 16: Create RLS Policies (Using SECURITY DEFINER Functions)
-- ============================================================================

-- Profiles policies
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Admins can view all profiles" ON profiles;
CREATE POLICY "Admins can view all profiles"
  ON profiles FOR SELECT
  USING (public.is_admin());

-- Customers policies
DROP POLICY IF EXISTS "Admins can manage customers" ON customers;
CREATE POLICY "Admins can manage customers" ON customers
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Cashiers can view customers" ON customers;
CREATE POLICY "Cashiers can view customers" ON customers
  FOR SELECT
  USING (public.is_authenticated());

DROP POLICY IF EXISTS "Cashiers can update customer balance" ON customers;
CREATE POLICY "Cashiers can update customer balance" ON customers
  FOR UPDATE
  USING (public.is_authenticated())
  WITH CHECK (public.is_authenticated());

-- Discounts policies
DROP POLICY IF EXISTS "Admins can manage discounts" ON discounts;
CREATE POLICY "Admins can manage discounts" ON discounts
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Cashiers can view discounts" ON discounts;
CREATE POLICY "Cashiers can view discounts" ON discounts
  FOR SELECT
  USING (public.is_authenticated());

-- Categories policies
DROP POLICY IF EXISTS "Users can view categories" ON categories;
CREATE POLICY "Users can view categories"
  ON categories FOR SELECT
  USING (public.is_authenticated());

DROP POLICY IF EXISTS "Admins can manage categories" ON categories;
CREATE POLICY "Admins can manage categories" ON categories
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Payment methods policies
DROP POLICY IF EXISTS "Users can view payment methods" ON payment_methods;
CREATE POLICY "Users can view payment methods"
  ON payment_methods FOR SELECT
  USING (public.is_authenticated());

DROP POLICY IF EXISTS "Admins can manage payment methods" ON payment_methods;
CREATE POLICY "Admins can manage payment methods" ON payment_methods
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Settings policies
DROP POLICY IF EXISTS "Users can view settings" ON settings;
CREATE POLICY "Users can view settings"
  ON settings FOR SELECT
  USING (public.is_authenticated());

DROP POLICY IF EXISTS "Admins can manage settings" ON settings;
CREATE POLICY "Admins can manage settings" ON settings
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Products policies
DROP POLICY IF EXISTS "Admins can manage products" ON products;
CREATE POLICY "Admins can manage products" ON products
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Cashiers can view products" ON products;
CREATE POLICY "Cashiers can view products" ON products
  FOR SELECT
  USING (public.is_authenticated());

-- Sales policies
DROP POLICY IF EXISTS "Admins can view all sales" ON sales;
CREATE POLICY "Admins can view all sales" ON sales
  FOR SELECT
  USING (public.is_admin());

DROP POLICY IF EXISTS "Cashiers can view own sales" ON sales;
CREATE POLICY "Cashiers can view own sales" ON sales
  FOR SELECT
  USING (public.is_kasir() AND created_by = auth.uid());

DROP POLICY IF EXISTS "Authenticated users can insert sales" ON sales;
CREATE POLICY "Authenticated users can insert sales" ON sales
  FOR INSERT
  WITH CHECK (public.is_authenticated() AND created_by = auth.uid());

DROP POLICY IF EXISTS "Admins can update sales" ON sales;
CREATE POLICY "Admins can update sales" ON sales
  FOR UPDATE
  USING (public.is_admin());

-- Sale items policies
DROP POLICY IF EXISTS "Admins can view all sale items" ON sale_items;
CREATE POLICY "Admins can view all sale items" ON sale_items
  FOR SELECT
  USING (public.is_admin());

DROP POLICY IF EXISTS "Cashiers can view own sale items" ON sale_items;
CREATE POLICY "Cashiers can view own sale items" ON sale_items
  FOR SELECT
  USING (
    public.is_kasir()
    AND EXISTS (
      SELECT 1 FROM sales
      WHERE sales.id = sale_items.sale_id
      AND sales.created_by = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Authenticated users can insert sale items" ON sale_items;
CREATE POLICY "Authenticated users can insert sale items" ON sale_items
  FOR INSERT
  WITH CHECK (
    public.is_authenticated()
    AND EXISTS (
      SELECT 1 FROM sales
      WHERE sales.id = sale_items.sale_id
      AND sales.created_by = auth.uid()
    )
  );

-- Stock movements policies
DROP POLICY IF EXISTS "Admins can view all stock movements" ON stock_movements;
CREATE POLICY "Admins can view all stock movements" ON stock_movements
  FOR SELECT
  USING (public.is_admin());

DROP POLICY IF EXISTS "Cashiers can view own stock movements" ON stock_movements;
CREATE POLICY "Cashiers can view own stock movements" ON stock_movements
  FOR SELECT
  USING (public.is_kasir() AND created_by = auth.uid());

DROP POLICY IF EXISTS "Admins can insert stock movements" ON stock_movements;
CREATE POLICY "Admins can insert stock movements" ON stock_movements
  FOR INSERT
  WITH CHECK (public.is_admin() AND created_by = auth.uid());

DROP POLICY IF EXISTS "Cashiers can insert stock movements for POS" ON stock_movements;
CREATE POLICY "Cashiers can insert stock movements for POS" ON stock_movements
  FOR INSERT
  WITH CHECK (public.is_kasir() AND created_by = auth.uid() AND type = 'out');

-- Suppliers policies
DROP POLICY IF EXISTS "Admins can manage suppliers" ON suppliers;
CREATE POLICY "Admins can manage suppliers" ON suppliers
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Daily production policies
DROP POLICY IF EXISTS "Admins can manage daily production" ON daily_production;
CREATE POLICY "Admins can manage daily production" ON daily_production
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin() AND created_by = auth.uid());

-- Waste items policies
DROP POLICY IF EXISTS "Admins can manage waste items" ON waste_items;
CREATE POLICY "Admins can manage waste items" ON waste_items
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin() AND created_by = auth.uid());

-- Raw materials policies
DROP POLICY IF EXISTS "Users can view raw materials" ON raw_materials;
CREATE POLICY "Users can view raw materials" ON raw_materials
  FOR SELECT
  USING (public.is_authenticated());

DROP POLICY IF EXISTS "Admins can manage raw materials" ON raw_materials;
CREATE POLICY "Admins can manage raw materials" ON raw_materials
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Product recipes policies
DROP POLICY IF EXISTS "Users can view product recipes" ON product_recipes;
CREATE POLICY "Users can view product recipes" ON product_recipes
  FOR SELECT
  USING (public.is_authenticated());

DROP POLICY IF EXISTS "Admins can manage product recipes" ON product_recipes;
CREATE POLICY "Admins can manage product recipes" ON product_recipes
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Expenses policies
DROP POLICY IF EXISTS "Users can view all expenses" ON expenses;
CREATE POLICY "Users can view all expenses" ON expenses
  FOR SELECT
  USING (public.is_authenticated());

DROP POLICY IF EXISTS "Admins can manage expenses" ON expenses;
CREATE POLICY "Admins can manage expenses" ON expenses
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Transaction logs policies
DROP POLICY IF EXISTS "Allow admins to read transaction logs" ON transaction_logs;
CREATE POLICY "Allow admins to read transaction logs" ON transaction_logs
  FOR SELECT
  TO authenticated
  USING (public.is_admin());

DROP POLICY IF EXISTS "Allow admins to insert transaction logs" ON transaction_logs;
CREATE POLICY "Allow admins to insert transaction logs" ON transaction_logs
  FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin());

-- ============================================================================
-- SECTION 17: Insert Default Data (Optional)
-- ============================================================================

-- Insert default categories
INSERT INTO categories (name, icon, color, sort_order) VALUES
('bakery', 'Cake', 'from-orange-500 to-red-500', 1),
('cemilan', 'Cookie', 'from-yellow-500 to-orange-500', 2),
('minuman', 'Coffee', 'from-blue-500 to-indigo-500', 3)
ON CONFLICT (name) DO NOTHING;

-- Insert default payment methods
INSERT INTO payment_methods (name, code, sort_order) VALUES
('Tunai (Cash)', 'cash', 1),
('Transfer', 'transfer', 2)
ON CONFLICT (code) DO NOTHING;

-- Insert default settings
INSERT INTO settings (key, value, description) VALUES
('low_stock_threshold', '10', 'Minimum stock level to trigger low stock alert'),
('store_name', 'KasirApp', 'Store/Brand name for display and reports'),
('store_address', '', 'Store physical address'),
('store_phone', '', 'Store contact phone number'),
('store_email', '', 'Store contact email'),
('store_logo_url', '', 'Store logo image URL'),
('receipt_header', 'TERIMA KASIH', 'Receipt header text'),
('receipt_footer', 'Barang yang sudah dibeli tidak dapat ditukar/dikembalikan', 'Receipt footer text'),
('tax_enabled', 'false', 'Enable tax calculation'),
('tax_rate', '11', 'Default tax rate'),
('tax_name', 'PPN', 'Tax name')
ON CONFLICT (key) DO NOTHING;

-- Insert sample customers
INSERT INTO customers (name, phone, email, address, balance, points) VALUES
('Budi Santoso', '081234567890', 'budi@email.com', 'Jl. Merdeka No. 1, Jakarta', 0, 100),
('Siti Rahayu', '081234567891', 'siti@email.com', 'Jl. Sudirman No. 2, Jakarta', 50000, 250),
('Ahmad Wijaya', '081234567892', 'ahmad@email.com', 'Jl. Gatot Subroto No. 3, Jakarta', 0, 50)
ON CONFLICT DO NOTHING;

-- Insert sample discounts
INSERT INTO discounts (name, type, value, min_purchase, max_discount, is_active) VALUES
('Diskon Member 10%', 'percentage', 10, 50000, 10000, true),
('Diskon Member 20%', 'percentage', 20, 100000, 20000, true),
('Diskon Tetap 5000', 'fixed', 5000, 30000, 5000, true)
ON CONFLICT DO NOTHING;

-- Insert sample products
INSERT INTO products (name, category, price, cost, stock, barcode) VALUES
('Roti Coklat', 'bakery', 15000, 8000, 50, '8991001001'),
('Roti Keju', 'bakery', 12000, 6000, 40, '8991001002'),
('Croissant', 'bakery', 18000, 10000, 30, '8991001003'),
('Donat Coklat', 'bakery', 10000, 5000, 60, '8991001004'),
('Roti Tawar', 'bakery', 20000, 12000, 25, '8991001005'),
('Keripik Singkong', 'cemilan', 15000, 7000, 45, '8991002001'),
('Keripik Pisang', 'cemilan', 12000, 6000, 35, '8991002002'),
('Pisang Goreng', 'cemilan', 10000, 5000, 50, '8991002003'),
('Kentang Goreng', 'cemilan', 15000, 8000, 40, '8991002004'),
('Es Teh Manis', 'minuman', 5000, 1000, 100, '8991003001'),
('Es Jeruk', 'minuman', 8000, 2000, 80, '8991003002'),
('Kopi Susu', 'minuman', 15000, 5000, 60, '8991003003'),
('Jus Alpukat', 'minuman', 18000, 8000, 40, '8991003004'),
('Es Campur', 'minuman', 20000, 10000, 30, '8991003005')
ON CONFLICT (barcode) DO NOTHING;

-- ============================================================================
-- SECTION 18: Verification Queries
-- ============================================================================

-- Verify all tables created
SELECT 'Tables created successfully' as status, COUNT(*) as table_count
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN (
  'profiles', 'customers', 'discounts', 'categories', 'payment_methods', 'settings',
  'products', 'sales', 'sale_items', 'stock_movements', 'suppliers',
  'daily_production', 'waste_items', 'raw_materials', 'product_recipes',
  'expenses', 'transaction_logs', 'schema_migrations'
);

-- Verify RLS enabled
SELECT 'RLS enabled successfully' as status, COUNT(*) as table_count
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN (
  'profiles', 'customers', 'discounts', 'categories', 'payment_methods', 'settings',
  'products', 'sales', 'sale_items', 'stock_movements', 'suppliers',
  'daily_production', 'waste_items', 'raw_materials', 'product_recipes',
  'expenses', 'transaction_logs'
)
AND row_security = true;

-- Verify SECURITY DEFINER functions created
SELECT 'SECURITY DEFINER functions created successfully' as status, COUNT(*) as function_count
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN ('is_admin', 'is_kasir', 'is_authenticated', 'process_checkout')
AND security_type = 'DEFINER';

-- Verify indexes created
SELECT 'Indexes created successfully' as status, COUNT(*) as index_count
FROM pg_indexes
WHERE schemaname = 'public'
AND indexname LIKE 'idx_%';

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
