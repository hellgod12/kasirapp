-- ============================================================================
-- KasirApp Database Upgrade to v1.2 - Incremental Migration
-- ============================================================================
-- Version: Upgrade to 1.2.0
-- Date: July 18, 2026
-- Description: Safe incremental upgrade for existing production databases
-- 
-- This script is FULLY IDEMPOTENT and safe to run multiple times.
-- It will:
-- - Never drop existing data
-- - Never recreate existing objects
-- - Only add missing objects
-- - Preserve all users, auth, and sales history
-- ============================================================================

-- ============================================================================
-- SECTION 1: Extensions
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- SECTION 2: Missing Tables
-- ============================================================================

-- Schema migrations table (if not exists)
CREATE TABLE IF NOT EXISTS schema_migrations (
  version TEXT PRIMARY KEY,
  applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  checksum TEXT,
  description TEXT
);

-- Profiles table (if not exists)
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY,
  email TEXT,
  name TEXT NOT NULL,
  role TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Categories table (if not exists)
CREATE TABLE IF NOT EXISTS categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  icon TEXT DEFAULT 'Package',
  color TEXT DEFAULT 'from-gray-500 to-gray-600',
  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Payment methods table (if not exists)
CREATE TABLE IF NOT EXISTS payment_methods (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  code TEXT NOT NULL UNIQUE,
  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Settings table (if not exists)
CREATE TABLE IF NOT EXISTS settings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  key TEXT NOT NULL UNIQUE,
  value TEXT NOT NULL,
  description TEXT,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Customers table (if not exists)
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

-- Discounts table (if not exists)
CREATE TABLE IF NOT EXISTS discounts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  value DECIMAL(10, 2) NOT NULL,
  min_purchase DECIMAL(10, 2) DEFAULT 0,
  max_discount DECIMAL(10, 2),
  is_active BOOLEAN DEFAULT true,
  valid_from TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  valid_until TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Raw materials table (if not exists)
CREATE TABLE IF NOT EXISTS raw_materials (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  unit TEXT NOT NULL,
  cost_per_unit DECIMAL(10, 2) NOT NULL,
  stock DECIMAL(10, 2) DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Product recipes table (if not exists)
CREATE TABLE IF NOT EXISTS product_recipes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID NOT NULL,
  raw_material_id UUID NOT NULL,
  quantity_used DECIMAL(10, 2) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(product_id, raw_material_id)
);

-- Expenses table (if not exists)
CREATE TABLE IF NOT EXISTS expenses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  expense_date DATE NOT NULL,
  category TEXT NOT NULL,
  description TEXT NOT NULL,
  amount DECIMAL(10, 2) NOT NULL,
  created_by UUID,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Transaction logs table (if not exists)
CREATE TABLE IF NOT EXISTS transaction_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id UUID NOT NULL,
  action TEXT NOT NULL,
  reason TEXT NOT NULL,
  old_data JSONB,
  new_data JSONB,
  user_id UUID NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- SECTION 3: Missing Columns
-- ============================================================================

-- Add hpp column to products if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'products' 
    AND column_name = 'hpp'
  ) THEN
    ALTER TABLE products ADD COLUMN hpp DECIMAL(10, 2) DEFAULT 0;
  END IF;
END $$;

-- Add barcode column to products if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'products' 
    AND column_name = 'barcode'
  ) THEN
    ALTER TABLE products ADD COLUMN barcode TEXT UNIQUE;
  END IF;
END $$;

-- Add is_active column to products if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'products' 
    AND column_name = 'is_active'
  ) THEN
    ALTER TABLE products ADD COLUMN is_active BOOLEAN DEFAULT true;
  END IF;
END $$;

-- Add updated_at column to products if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'products' 
    AND column_name = 'updated_at'
  ) THEN
    ALTER TABLE products ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
  END IF;
END $$;

-- Add customer_id column to sales if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'sales' 
    AND column_name = 'customer_id'
  ) THEN
    ALTER TABLE sales ADD COLUMN customer_id UUID;
  END IF;
END $$;

-- Add discount_id column to sales if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'sales' 
    AND column_name = 'discount_id'
  ) THEN
    ALTER TABLE sales ADD COLUMN discount_id UUID;
  END IF;
END $$;

-- Add discount_amount column to sales if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'sales' 
    AND column_name = 'discount_amount'
  ) THEN
    ALTER TABLE sales ADD COLUMN discount_amount DECIMAL(10, 2) DEFAULT 0;
  END IF;
END $$;

-- Add tax_rate column to sales if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'sales' 
    AND column_name = 'tax_rate'
  ) THEN
    ALTER TABLE sales ADD COLUMN tax_rate DECIMAL(5, 2) DEFAULT 0;
  END IF;
END $$;

-- Add tax_amount column to sales if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'sales' 
    AND column_name = 'tax_amount'
  ) THEN
    ALTER TABLE sales ADD COLUMN tax_amount DECIMAL(10, 2) DEFAULT 0;
  END IF;
END $$;

-- Add transaction_token column to sales if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'sales' 
    AND column_name = 'transaction_token'
  ) THEN
    ALTER TABLE sales ADD COLUMN transaction_token TEXT UNIQUE;
  END IF;
END $$;

-- Add created_by column to sales if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'sales' 
    AND column_name = 'created_by'
  ) THEN
    ALTER TABLE sales ADD COLUMN created_by UUID;
  END IF;
END $$;

-- Add created_by column to stock_movements if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'stock_movements' 
    AND column_name = 'created_by'
  ) THEN
    ALTER TABLE stock_movements ADD COLUMN created_by UUID;
  END IF;
END $$;

-- Add created_by column to daily_production if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'daily_production' 
    AND column_name = 'created_by'
  ) THEN
    ALTER TABLE daily_production ADD COLUMN created_by UUID;
  END IF;
END $$;

-- Add created_by column to waste_items if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'waste_items' 
    AND column_name = 'created_by'
  ) THEN
    ALTER TABLE waste_items ADD COLUMN created_by UUID;
  END IF;
END $$;

-- Add created_by column to expenses if missing
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'expenses' 
    AND column_name = 'created_by'
  ) THEN
    ALTER TABLE expenses ADD COLUMN created_by UUID;
  END IF;
END $$;

-- ============================================================================
-- SECTION 4: Missing Constraints
-- ============================================================================

-- Profiles role constraint
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'profiles_role_check' 
    AND conrelid = 'profiles'::regclass
  ) THEN
    ALTER TABLE profiles ADD CONSTRAINT profiles_role_check 
      CHECK (role IN ('admin', 'kasir'));
  END IF;
END $$;

-- Products constraints
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'products_price_check' 
    AND conrelid = 'products'::regclass
  ) THEN
    ALTER TABLE products ADD CONSTRAINT products_price_check 
      CHECK (price > 0);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'products_cost_check' 
    AND conrelid = 'products'::regclass
  ) THEN
    ALTER TABLE products ADD CONSTRAINT products_cost_check 
      CHECK (cost >= 0);
  END IF;
END $$;

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

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'products_hpp_check' 
    AND conrelid = 'products'::regclass
  ) THEN
    ALTER TABLE products ADD CONSTRAINT products_hpp_check 
      CHECK (hpp >= 0);
  END IF;
END $$;

-- Sales constraints
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'sales_total_amount_check' 
    AND conrelid = 'sales'::regclass
  ) THEN
    ALTER TABLE sales ADD CONSTRAINT sales_total_amount_check 
      CHECK (total_amount > 0);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'sales_total_cost_check' 
    AND conrelid = 'sales'::regclass
  ) THEN
    ALTER TABLE sales ADD CONSTRAINT sales_total_cost_check 
      CHECK (total_cost >= 0);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'sales_discount_amount_check' 
    AND conrelid = 'sales'::regclass
  ) THEN
    ALTER TABLE sales ADD CONSTRAINT sales_discount_amount_check 
      CHECK (discount_amount >= 0);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'sales_tax_rate_check' 
    AND conrelid = 'sales'::regclass
  ) THEN
    ALTER TABLE sales ADD CONSTRAINT sales_tax_rate_check 
      CHECK (tax_rate >= 0);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'sales_tax_amount_check' 
    AND conrelid = 'sales'::regclass
  ) THEN
    ALTER TABLE sales ADD CONSTRAINT sales_tax_amount_check 
      CHECK (tax_amount >= 0);
  END IF;
END $$;

-- Sale items constraints
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'sale_items_quantity_check' 
    AND conrelid = 'sale_items'::regclass
  ) THEN
    ALTER TABLE sale_items ADD CONSTRAINT sale_items_quantity_check 
      CHECK (quantity > 0);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'sale_items_price_check' 
    AND conrelid = 'sale_items'::regclass
  ) THEN
    ALTER TABLE sale_items ADD CONSTRAINT sale_items_price_check 
      CHECK (price > 0);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'sale_items_cost_check' 
    AND conrelid = 'sale_items'::regclass
  ) THEN
    ALTER TABLE sale_items ADD CONSTRAINT sale_items_cost_check 
      CHECK (cost >= 0);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'sale_items_subtotal_check' 
    AND conrelid = 'sale_items'::regclass
  ) THEN
    ALTER TABLE sale_items ADD CONSTRAINT sale_items_subtotal_check 
      CHECK (subtotal > 0);
  END IF;
END $$;

-- Stock movements constraints
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'stock_movements_type_check' 
    AND conrelid = 'stock_movements'::regclass
  ) THEN
    ALTER TABLE stock_movements ADD CONSTRAINT stock_movements_type_check 
      CHECK (type IN ('in', 'out', 'production', 'waste'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'stock_movements_quantity_check' 
    AND conrelid = 'stock_movements'::regclass
  ) THEN
    ALTER TABLE stock_movements ADD CONSTRAINT stock_movements_quantity_check 
      CHECK (quantity != 0);
  END IF;
END $$;

-- Daily production constraints
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'daily_production_quantity_produced_check' 
    AND conrelid = 'daily_production'::regclass
  ) THEN
    ALTER TABLE daily_production ADD CONSTRAINT daily_production_quantity_produced_check 
      CHECK (quantity_produced >= 0);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'daily_production_quantity_sold_check' 
    AND conrelid = 'daily_production'::regclass
  ) THEN
    ALTER TABLE daily_production ADD CONSTRAINT daily_production_quantity_sold_check 
      CHECK (quantity_sold >= 0);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'daily_production_quantity_waste_check' 
    AND conrelid = 'daily_production'::regclass
  ) THEN
    ALTER TABLE daily_production ADD CONSTRAINT daily_production_quantity_waste_check 
      CHECK (quantity_waste >= 0);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'daily_production_quantity_remaining_check' 
    AND conrelid = 'daily_production'::regclass
  ) THEN
    ALTER TABLE daily_production ADD CONSTRAINT daily_production_quantity_remaining_check 
      CHECK (quantity_remaining >= 0);
  END IF;
END $$;

-- Waste items constraints
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'waste_items_quantity_check' 
    AND conrelid = 'waste_items'::regclass
  ) THEN
    ALTER TABLE waste_items ADD CONSTRAINT waste_items_quantity_check 
      CHECK (quantity > 0);
  END IF;
END $$;

-- Customers constraints
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'customers_points_check' 
    AND conrelid = 'customers'::regclass
  ) THEN
    ALTER TABLE customers ADD CONSTRAINT customers_points_check 
      CHECK (points >= 0);
  END IF;
END $$;

-- Discounts constraints
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'discounts_type_check' 
    AND conrelid = 'discounts'::regclass
  ) THEN
    ALTER TABLE discounts ADD CONSTRAINT discounts_type_check 
      CHECK (type IN ('percentage', 'fixed'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'discounts_value_check' 
    AND conrelid = 'discounts'::regclass
  ) THEN
    ALTER TABLE discounts ADD CONSTRAINT discounts_value_check 
      CHECK (value > 0);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'discounts_min_purchase_check' 
    AND conrelid = 'discounts'::regclass
  ) THEN
    ALTER TABLE discounts ADD CONSTRAINT discounts_min_purchase_check 
      CHECK (min_purchase >= 0);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'discounts_max_discount_check' 
    AND conrelid = 'discounts'::regclass
  ) THEN
    -- First, update existing NULL values to 0 to avoid constraint violation
    UPDATE discounts SET max_discount = 0 WHERE max_discount IS NULL;
    
    -- Then add the constraint allowing both NULL and positive values
    ALTER TABLE discounts ADD CONSTRAINT discounts_max_discount_check 
      CHECK (max_discount IS NULL OR max_discount > 0);
  END IF;
END $$;

-- Raw materials constraints
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'raw_materials_cost_per_unit_check' 
    AND conrelid = 'raw_materials'::regclass
  ) THEN
    ALTER TABLE raw_materials ADD CONSTRAINT raw_materials_cost_per_unit_check 
      CHECK (cost_per_unit > 0);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'raw_materials_stock_check' 
    AND conrelid = 'raw_materials'::regclass
  ) THEN
    ALTER TABLE raw_materials ADD CONSTRAINT raw_materials_stock_check 
      CHECK (stock >= 0);
  END IF;
END $$;

-- Product recipes constraints
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'product_recipes_quantity_used_check' 
    AND conrelid = 'product_recipes'::regclass
  ) THEN
    ALTER TABLE product_recipes ADD CONSTRAINT product_recipes_quantity_used_check 
      CHECK (quantity_used > 0);
  END IF;
END $$;

-- Expenses constraints
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'expenses_category_check' 
    AND conrelid = 'expenses'::regclass
  ) THEN
    ALTER TABLE expenses ADD CONSTRAINT expenses_category_check 
      CHECK (category IN ('Electricity', 'Water', 'Salary', 'Rent', 'Raw Materials', 'Transportation', 'Marketing', 'Other'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'expenses_amount_check' 
    AND conrelid = 'expenses'::regclass
  ) THEN
    ALTER TABLE expenses ADD CONSTRAINT expenses_amount_check 
      CHECK (amount > 0);
  END IF;
END $$;

-- Transaction logs constraints
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'transaction_logs_action_check' 
    AND conrelid = 'transaction_logs'::regclass
  ) THEN
    ALTER TABLE transaction_logs ADD CONSTRAINT transaction_logs_action_check 
      CHECK (action IN ('void', 'delete', 'edit'));
  END IF;
END $$;

-- ============================================================================
-- SECTION 5: Missing Foreign Keys
-- ============================================================================

-- Profiles foreign key to auth.users
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'profiles_id_fkey' 
    AND conrelid = 'profiles'::regclass
  ) THEN
    ALTER TABLE profiles ADD CONSTRAINT profiles_id_fkey 
      FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Sales foreign keys
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'sales_customer_id_fkey' 
    AND conrelid = 'sales'::regclass
  ) THEN
    ALTER TABLE sales ADD CONSTRAINT sales_customer_id_fkey 
      FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'sales_discount_id_fkey' 
    AND conrelid = 'sales'::regclass
  ) THEN
    ALTER TABLE sales ADD CONSTRAINT sales_discount_id_fkey 
      FOREIGN KEY (discount_id) REFERENCES discounts(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'sales_created_by_fkey' 
    AND conrelid = 'sales'::regclass
  ) THEN
    ALTER TABLE sales ADD CONSTRAINT sales_created_by_fkey 
      FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Sale items foreign keys
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'sale_items_sale_id_fkey' 
    AND conrelid = 'sale_items'::regclass
  ) THEN
    ALTER TABLE sale_items ADD CONSTRAINT sale_items_sale_id_fkey 
      FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'sale_items_product_id_fkey' 
    AND conrelid = 'sale_items'::regclass
  ) THEN
    ALTER TABLE sale_items ADD CONSTRAINT sale_items_product_id_fkey 
      FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Stock movements foreign keys
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'stock_movements_product_id_fkey' 
    AND conrelid = 'stock_movements'::regclass
  ) THEN
    ALTER TABLE stock_movements ADD CONSTRAINT stock_movements_product_id_fkey 
      FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'stock_movements_created_by_fkey' 
    AND conrelid = 'stock_movements'::regclass
  ) THEN
    ALTER TABLE stock_movements ADD CONSTRAINT stock_movements_created_by_fkey 
      FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Daily production foreign keys
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'daily_production_product_id_fkey' 
    AND conrelid = 'daily_production'::regclass
  ) THEN
    ALTER TABLE daily_production ADD CONSTRAINT daily_production_product_id_fkey 
      FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'daily_production_created_by_fkey' 
    AND conrelid = 'daily_production'::regclass
  ) THEN
    ALTER TABLE daily_production ADD CONSTRAINT daily_production_created_by_fkey 
      FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Waste items foreign keys
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'waste_items_product_id_fkey' 
    AND conrelid = 'waste_items'::regclass
  ) THEN
    ALTER TABLE waste_items ADD CONSTRAINT waste_items_product_id_fkey 
      FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'waste_items_created_by_fkey' 
    AND conrelid = 'waste_items'::regclass
  ) THEN
    ALTER TABLE waste_items ADD CONSTRAINT waste_items_created_by_fkey 
      FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Product recipes foreign keys
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'product_recipes_product_id_fkey' 
    AND conrelid = 'product_recipes'::regclass
  ) THEN
    ALTER TABLE product_recipes ADD CONSTRAINT product_recipes_product_id_fkey 
      FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'product_recipes_raw_material_id_fkey' 
    AND conrelid = 'product_recipes'::regclass
  ) THEN
    ALTER TABLE product_recipes ADD CONSTRAINT product_recipes_raw_material_id_fkey 
      FOREIGN KEY (raw_material_id) REFERENCES raw_materials(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Expenses foreign keys
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'expenses_created_by_fkey' 
    AND conrelid = 'expenses'::regclass
  ) THEN
    ALTER TABLE expenses ADD CONSTRAINT expenses_created_by_fkey 
      FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Transaction logs foreign keys
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'transaction_logs_transaction_id_fkey' 
    AND conrelid = 'transaction_logs'::regclass
  ) THEN
    ALTER TABLE transaction_logs ADD CONSTRAINT transaction_logs_transaction_id_fkey 
      FOREIGN KEY (transaction_id) REFERENCES sales(id) ON DELETE CASCADE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'transaction_logs_user_id_fkey' 
    AND conrelid = 'transaction_logs'::regclass
  ) THEN
    ALTER TABLE transaction_logs ADD CONSTRAINT transaction_logs_user_id_fkey 
      FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
  END IF;
END $$;

-- ============================================================================
-- SECTION 6: Missing Indexes
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
-- SECTION 7: Missing Functions
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

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

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
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to calculate HPP for a specific product
CREATE OR REPLACE FUNCTION public.calculate_product_hpp(product_uuid UUID)
RETURNS DECIMAL(10, 2) AS $$
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

-- Atomic checkout function
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

-- ============================================================================
-- SECTION 8: Missing Triggers
-- ============================================================================

-- Profiles updated_at trigger
DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Auth users trigger for profile creation
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Products updated_at trigger
DROP TRIGGER IF EXISTS update_products_updated_at ON products;
CREATE TRIGGER update_products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Customers updated_at trigger
DROP TRIGGER IF EXISTS update_customers_updated_at ON customers;
CREATE TRIGGER update_customers_updated_at
  BEFORE UPDATE ON customers
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Discounts updated_at trigger
DROP TRIGGER IF EXISTS update_discounts_updated_at ON discounts;
CREATE TRIGGER update_discounts_updated_at
  BEFORE UPDATE ON discounts
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- HPP triggers
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
-- SECTION 9: Enable RLS on Tables
-- ============================================================================

-- Enable RLS on all tables (idempotent - already enabled tables will remain enabled)
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
-- SECTION 10: Missing Policies
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
-- SECTION 11: Default Data (Idempotent)
-- ============================================================================

-- Record this migration
INSERT INTO schema_migrations (version, checksum, description) VALUES
('1.2.0', md5(current_timestamp::text), 'Upgrade to production schema v1.2 (enterprise standard)')
ON CONFLICT (version) DO UPDATE SET
  applied_at = NOW(),
  checksum = md5(current_timestamp::text),
  description = 'Upgrade to production schema v1.2 (enterprise standard)';

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
ON CONFLICT (key) DO UPDATE SET
  value = EXCLUDED.value,
  description = EXCLUDED.description;

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

-- Insert sample products (only if they don't exist by barcode)
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
-- SECTION 12: Grants
-- ============================================================================

-- Grant execute on SECURITY DEFINER functions
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_kasir() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_authenticated() TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_checkout TO authenticated;

-- Grant usage on all tables to authenticated
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT INSERT ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT UPDATE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT DELETE ON ALL TABLES IN SCHEMA public TO authenticated;

-- Grant usage on all sequences to authenticated
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- ============================================================================
-- END OF UPGRADE MIGRATION
-- ============================================================================
