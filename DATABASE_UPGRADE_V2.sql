-- KasirApp Database Upgrade to Version 1.0
-- This script safely upgrades an old production database to Version 1.0
-- It creates missing tables, adds missing columns, indexes, foreign keys, RLS policies, and triggers
-- It preserves all existing data
-- 
-- IMPORTANT: Run this in Supabase SQL Editor
-- This script is idempotent - safe to run multiple times
--
-- VERSION 2: Fixed PostgreSQL syntax error (v_tax_enabled variable declaration)

-- ============================================================================
-- SECTION 1: Enable Extensions
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- SECTION 2: Create Missing Tables
-- ============================================================================

-- Create profiles table (if not exists)
CREATE TABLE IF NOT EXISTS profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  email TEXT,
  name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('admin', 'kasir')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create customers table (if not exists)
CREATE TABLE IF NOT EXISTS customers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  address TEXT,
  balance DECIMAL(10, 2) DEFAULT 0,
  points INTEGER DEFAULT 0,
  notes TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create discounts table (if not exists)
CREATE TABLE IF NOT EXISTS discounts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('percentage', 'fixed')),
  value DECIMAL(10, 2) NOT NULL,
  min_purchase DECIMAL(10, 2) DEFAULT 0,
  max_discount DECIMAL(10, 2),
  is_active BOOLEAN DEFAULT true,
  valid_from TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  valid_until TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create categories table (if not exists)
CREATE TABLE IF NOT EXISTS categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  icon TEXT DEFAULT 'Package',
  color TEXT DEFAULT 'from-gray-500 to-gray-600',
  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create payment_methods table (if not exists)
CREATE TABLE IF NOT EXISTS payment_methods (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  code TEXT NOT NULL UNIQUE,
  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create settings table (if not exists)
CREATE TABLE IF NOT EXISTS settings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  key TEXT NOT NULL UNIQUE,
  value TEXT NOT NULL,
  description TEXT,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create raw_materials table (if not exists)
CREATE TABLE IF NOT EXISTS raw_materials (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  unit TEXT NOT NULL CHECK (unit IN ('kg', 'gram', 'liter', 'ml', 'pcs')),
  cost_per_unit DECIMAL(10, 2) NOT NULL,
  stock DECIMAL(10, 2) DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create product_recipes table (if not exists)
CREATE TABLE IF NOT EXISTS product_recipes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  raw_material_id UUID NOT NULL REFERENCES raw_materials(id) ON DELETE CASCADE,
  quantity_used DECIMAL(10, 2) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(product_id, raw_material_id)
);

-- Create expenses table (if not exists)
CREATE TABLE IF NOT EXISTS expenses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  expense_date DATE NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('Electricity', 'Water', 'Salary', 'Rent', 'Raw Materials', 'Transportation', 'Marketing', 'Other')),
  description TEXT NOT NULL,
  amount DECIMAL(10, 2) NOT NULL,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create transaction_logs table (if not exists)
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
-- SECTION 3: Add Missing Columns to Existing Tables
-- ============================================================================

-- Add columns to products table
ALTER TABLE products 
ADD COLUMN IF NOT EXISTS hpp DECIMAL(10, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS barcode TEXT UNIQUE;

-- Add columns to sales table
ALTER TABLE sales 
ADD COLUMN IF NOT EXISTS customer_id UUID,
ADD COLUMN IF NOT EXISTS discount_amount DECIMAL(10, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS discount_id UUID,
ADD COLUMN IF NOT EXISTS tax_rate DECIMAL(5, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS tax_amount DECIMAL(10, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS transaction_token TEXT UNIQUE;

-- ============================================================================
-- SECTION 4: Add Foreign Key Constraints (if not already present)
-- ============================================================================

-- Add foreign key for sales.customer_id (if not exists)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'sales_customer_id_fkey'
    AND table_name = 'sales'
  ) THEN
    ALTER TABLE sales 
    ADD CONSTRAINT sales_customer_id_fkey 
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Add foreign key for sales.discount_id (if not exists)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'sales_discount_id_fkey'
    AND table_name = 'sales'
  ) THEN
    ALTER TABLE sales 
    ADD CONSTRAINT sales_discount_id_fkey 
    FOREIGN KEY (discount_id) REFERENCES discounts(id) ON DELETE SET NULL;
  END IF;
END $$;

-- ============================================================================
-- SECTION 5: Remove Check Constraints (for dynamic categories)
-- ============================================================================

ALTER TABLE products DROP CONSTRAINT IF EXISTS products_category_check;
ALTER TABLE raw_materials DROP CONSTRAINT IF EXISTS raw_materials_unit_check;

-- ============================================================================
-- SECTION 6: Create Indexes
-- ============================================================================

-- Customers indexes
CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone);
CREATE INDEX IF NOT EXISTS idx_customers_email ON customers(email);
CREATE INDEX IF NOT EXISTS idx_sales_customer_id ON sales(customer_id);

-- Discounts indexes
CREATE INDEX IF NOT EXISTS idx_discounts_is_active ON discounts(is_active);
CREATE INDEX IF NOT EXISTS idx_discounts_valid_period ON discounts(valid_from, valid_until);
CREATE INDEX IF NOT EXISTS idx_sales_discount_id ON sales(discount_id);

-- Categories indexes
CREATE INDEX IF NOT EXISTS idx_categories_name ON categories(name);
CREATE INDEX IF NOT EXISTS idx_categories_active ON categories(is_active);

-- Payment methods indexes
CREATE INDEX IF NOT EXISTS idx_payment_methods_code ON payment_methods(code);
CREATE INDEX IF NOT EXISTS idx_payment_methods_active ON payment_methods(is_active);

-- Settings indexes
CREATE INDEX IF NOT EXISTS idx_settings_key ON settings(key);

-- Products indexes
CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);

-- Sales indexes
CREATE INDEX IF NOT EXISTS idx_sales_tax_rate ON sales(tax_rate);
CREATE INDEX IF NOT EXISTS idx_sales_transaction_token ON sales(transaction_token);

-- Raw materials indexes
CREATE INDEX IF NOT EXISTS idx_raw_materials_name ON raw_materials(name);

-- Product recipes indexes
CREATE INDEX IF NOT EXISTS idx_product_recipes_product_id ON product_recipes(product_id);
CREATE INDEX IF NOT EXISTS idx_product_recipes_raw_material_id ON product_recipes(raw_material_id);

-- Expenses indexes
CREATE INDEX IF NOT EXISTS idx_expenses_expense_date ON expenses(expense_date);
CREATE INDEX IF NOT EXISTS idx_expenses_category ON expenses(category);
CREATE INDEX IF NOT EXISTS idx_expenses_created_by ON expenses(created_by);

-- Transaction logs indexes
CREATE INDEX IF NOT EXISTS idx_transaction_logs_transaction_id ON transaction_logs(transaction_id);
CREATE INDEX IF NOT EXISTS idx_transaction_logs_user_id ON transaction_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_transaction_logs_created_at ON transaction_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transaction_logs_action ON transaction_logs(action);

-- ============================================================================
-- SECTION 7: Create Triggers and Functions
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for profiles table
DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Function to update customers updated_at
CREATE OR REPLACE FUNCTION update_customers_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for customers table
DROP TRIGGER IF EXISTS update_customers_updated_at ON customers;
CREATE TRIGGER update_customers_updated_at
  BEFORE UPDATE ON customers
  FOR EACH ROW
  EXECUTE FUNCTION update_customers_updated_at();

-- Function to update discounts updated_at
CREATE OR REPLACE FUNCTION update_discounts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for discounts table
DROP TRIGGER IF EXISTS update_discounts_updated_at ON discounts;
CREATE TRIGGER update_discounts_updated_at
  BEFORE UPDATE ON discounts
  FOR EACH ROW
  EXECUTE FUNCTION update_discounts_updated_at();

-- Function to calculate HPP for a product
CREATE OR REPLACE FUNCTION calculate_product_hpp(product_uuid UUID)
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
CREATE OR REPLACE FUNCTION update_all_product_hpp()
RETURNS VOID AS $$
BEGIN
  UPDATE products
  SET hpp = calculate_product_hpp(id);
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update HPP when recipes change
CREATE OR REPLACE FUNCTION update_product_hpp_trigger()
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
  FOR EACH ROW EXECUTE FUNCTION update_product_hpp_trigger();

CREATE TRIGGER trigger_update_hpp_after_update
  AFTER UPDATE ON product_recipes
  FOR EACH ROW EXECUTE FUNCTION update_product_hpp_trigger();

CREATE TRIGGER trigger_update_hpp_after_delete
  AFTER DELETE ON product_recipes
  FOR EACH ROW EXECUTE FUNCTION update_product_hpp_trigger();

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
-- SECTION 8: Enable Row Level Security
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE discounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction_logs ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- SECTION 9: Create RLS Policies
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
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Customers policies
DROP POLICY IF EXISTS "Admins can manage customers" ON customers;
CREATE POLICY "Admins can manage customers" ON customers
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Cashiers can view customers" ON customers;
CREATE POLICY "Cashiers can view customers" ON customers
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'kasir')
    )
  );

DROP POLICY IF EXISTS "Cashiers can update customer balance" ON customers;
CREATE POLICY "Cashiers can update customer balance" ON customers
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'kasir')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'kasir')
    )
  );

DROP POLICY IF EXISTS "Admins can insert customers" ON customers;
CREATE POLICY "Admins can insert customers" ON customers
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Admins can delete customers" ON customers;
CREATE POLICY "Admins can delete customers" ON customers
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Discounts policies
DROP POLICY IF EXISTS "Admins can manage discounts" ON discounts;
CREATE POLICY "Admins can manage discounts" ON discounts
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Cashiers can view discounts" ON discounts;
CREATE POLICY "Cashiers can view discounts" ON discounts
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'kasir')
    )
  );

-- Categories policies
DROP POLICY IF EXISTS "Users can view categories" ON categories;
CREATE POLICY "Users can view categories"
  ON categories FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Admins can insert categories" ON categories;
CREATE POLICY "Admins can insert categories"
  ON categories FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Admins can update categories" ON categories;
CREATE POLICY "Admins can update categories"
  ON categories FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Admins can delete categories" ON categories;
CREATE POLICY "Admins can delete categories"
  ON categories FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Payment methods policies
DROP POLICY IF EXISTS "Users can view payment methods" ON payment_methods;
CREATE POLICY "Users can view payment methods"
  ON payment_methods FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Admins can insert payment methods" ON payment_methods;
CREATE POLICY "Admins can insert payment methods"
  ON payment_methods FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Admins can update payment methods" ON payment_methods;
CREATE POLICY "Admins can update payment methods"
  ON payment_methods FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Admins can delete payment methods" ON payment_methods;
CREATE POLICY "Admins can delete payment methods"
  ON payment_methods FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Settings policies
DROP POLICY IF EXISTS "Users can view settings" ON settings;
CREATE POLICY "Users can view settings"
  ON settings FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Admins can insert settings" ON settings;
CREATE POLICY "Admins can insert settings"
  ON settings FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Admins can update settings" ON settings;
CREATE POLICY "Admins can update settings"
  ON settings FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Admins can delete settings" ON settings;
CREATE POLICY "Admins can delete settings"
  ON settings FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Raw materials policies
DROP POLICY IF EXISTS "Users can view raw materials" ON raw_materials;
CREATE POLICY "Users can view raw materials"
  ON raw_materials FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Admins can insert raw materials" ON raw_materials;
CREATE POLICY "Admins can insert raw materials"
  ON raw_materials FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Admins can update raw materials" ON raw_materials;
CREATE POLICY "Admins can update raw materials"
  ON raw_materials FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Admins can delete raw materials" ON raw_materials;
CREATE POLICY "Admins can delete raw materials"
  ON raw_materials FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Product recipes policies
DROP POLICY IF EXISTS "Users can view product recipes" ON product_recipes;
CREATE POLICY "Users can view product recipes"
  ON product_recipes FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Admins can insert product recipes" ON product_recipes;
CREATE POLICY "Admins can insert product recipes"
  ON product_recipes FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Admins can update product recipes" ON product_recipes;
CREATE POLICY "Admins can update product recipes"
  ON product_recipes FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Admins can delete product recipes" ON product_recipes;
CREATE POLICY "Admins can delete product recipes"
  ON product_recipes FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Expenses policies
DROP POLICY IF EXISTS "Users can view all expenses" ON expenses;
CREATE POLICY "Users can view all expenses"
  ON expenses FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Admins can insert expenses" ON expenses;
CREATE POLICY "Admins can insert expenses"
  ON expenses FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Admins can update expenses" ON expenses;
CREATE POLICY "Admins can update expenses"
  ON expenses FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Admins can delete expenses" ON expenses;
CREATE POLICY "Admins can delete expenses"
  ON expenses FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Transaction logs policies
DROP POLICY IF EXISTS "Allow admins to read transaction logs" ON transaction_logs;
CREATE POLICY "Allow admins to read transaction logs"
  ON transaction_logs
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Allow admins to insert transaction logs" ON transaction_logs;
CREATE POLICY "Allow admins to insert transaction logs"
  ON transaction_logs
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- ============================================================================
-- SECTION 10: Insert Default Data
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

-- Update sample products with barcodes (if they exist)
UPDATE products SET barcode = '8991001001' WHERE name = 'Roti Coklat' AND barcode IS NULL;
UPDATE products SET barcode = '8991001002' WHERE name = 'Roti Keju' AND barcode IS NULL;
UPDATE products SET barcode = '8991001003' WHERE name = 'Croissant' AND barcode IS NULL;
UPDATE products SET barcode = '8991001004' WHERE name = 'Donat Coklat' AND barcode IS NULL;
UPDATE products SET barcode = '8991001005' WHERE name = 'Roti Tawar' AND barcode IS NULL;
UPDATE products SET barcode = '8991002001' WHERE name = 'Keripik Singkong' AND barcode IS NULL;
UPDATE products SET barcode = '8991002002' WHERE name = 'Keripik Pisang' AND barcode IS NULL;
UPDATE products SET barcode = '8991002003' WHERE name = 'Pisang Goreng' AND barcode IS NULL;
UPDATE products SET barcode = '8991002004' WHERE name = 'Kentang Goreng' AND barcode IS NULL;
UPDATE products SET barcode = '8991003001' WHERE name = 'Es Teh Manis' AND barcode IS NULL;
UPDATE products SET barcode = '8991003002' WHERE name = 'Es Jeruk' AND barcode IS NULL;
UPDATE products SET barcode = '8991003003' WHERE name = 'Kopi Susu' AND barcode IS NULL;
UPDATE products SET barcode = '8991003004' WHERE name = 'Jus Alpukat' AND barcode IS NULL;
UPDATE products SET barcode = '8991003005' WHERE name = 'Es Campur' AND barcode IS NULL;

-- ============================================================================
-- SECTION 11: Create Atomic Checkout RPC Function
-- ============================================================================

CREATE OR REPLACE FUNCTION process_checkout(
  p_items JSONB,
  p_payment_method TEXT,
  p_user_id UUID,
  p_transaction_token TEXT,
  p_customer_id UUID DEFAULT NULL,
  p_discount_id UUID DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
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
    WHERE id = v_product_id
    FOR UPDATE;
    
    IF v_current_stock IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'Product not found');
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

  -- Create sale record
  INSERT INTO sales (
    total_amount,
    total_cost,
    profit,
    payment_method,
    created_by,
    customer_id,
    discount_amount,
    discount_id,
    tax_rate,
    tax_amount,
    transaction_token
  ) VALUES (
    v_total_amount,
    v_total_cost,
    v_profit,
    p_payment_method,
    p_user_id,
    p_customer_id,
    v_discount_amount,
    p_discount_id,
    v_tax_rate::DECIMAL(5, 2),
    v_tax_amount,
    p_transaction_token
  ) RETURNING id INTO v_sale_id;

  -- Create sale items and update stock
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := (v_item->>'id')::UUID;
    v_quantity := (v_item->>'quantity')::INTEGER;
    v_price := (v_item->>'price')::DECIMAL(10, 2);
    v_cost := (v_item->>'cost')::DECIMAL(10, 2);
    v_subtotal := v_price * v_quantity;
    
    -- Insert sale item
    INSERT INTO sale_items (sale_id, product_id, quantity, price, cost, subtotal)
    VALUES (v_sale_id, v_product_id, v_quantity, v_price, v_cost, v_subtotal);
    
    -- Update product stock
    UPDATE products
    SET stock = stock - v_quantity
    WHERE id = v_product_id;
    
    -- Create stock movement record
    INSERT INTO stock_movements (product_id, type, quantity, reference_id, notes, created_by)
    VALUES (v_product_id, 'out', v_quantity, v_sale_id::TEXT, 'Sale', p_user_id);
  END LOOP;

  -- Update customer balance if customer provided
  IF p_customer_id IS NOT NULL THEN
    UPDATE customers
    SET balance = balance + v_final_amount
    WHERE id = p_customer_id;
  END IF;

  -- Return success
  RETURN jsonb_build_object(
    'success', true,
    'sale_id', v_sale_id,
    'total_amount', v_total_amount,
    'discount_amount', v_discount_amount,
    'tax_amount', v_tax_amount,
    'final_amount', v_final_amount
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM, 'detail', SQLSTATE);
END;
$$;

-- Grant execute permission on process_checkout
GRANT EXECUTE ON FUNCTION process_checkout TO authenticated;

-- ============================================================================
-- SECTION 12: Add Comments
-- ============================================================================

COMMENT ON COLUMN products.barcode IS 'Product barcode for scanning (optional)';
COMMENT ON TABLE transaction_logs IS 'Logs all transaction modifications including voids, deletes, and edits';

-- ============================================================================
-- UPGRADE COMPLETE
-- ============================================================================

-- Verification queries (uncomment to verify)
-- SELECT 'Tables created successfully' as status;
-- SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name;
