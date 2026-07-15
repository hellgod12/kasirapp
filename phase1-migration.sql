-- Phase 1 Migration: Dynamic Categories, Payment Methods, and Settings
-- This migration makes the system more flexible and configurable

-- 1. Create categories table
CREATE TABLE IF NOT EXISTS categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  icon TEXT DEFAULT 'Package',
  color TEXT DEFAULT 'from-gray-500 to-gray-600',
  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Create payment_methods table
CREATE TABLE IF NOT EXISTS payment_methods (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  code TEXT NOT NULL UNIQUE,
  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Create settings table
CREATE TABLE IF NOT EXISTS settings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  key TEXT NOT NULL UNIQUE,
  value TEXT NOT NULL,
  description TEXT,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Remove CHECK constraint from products.category
-- First, we need to drop the existing constraint
ALTER TABLE products DROP CONSTRAINT IF EXISTS products_category_check;

-- 5. Remove CHECK constraint from raw_materials.unit
ALTER TABLE raw_materials DROP CONSTRAINT IF EXISTS raw_materials_unit_check;

-- 6. Insert default categories (migrate existing hardcoded values)
INSERT INTO categories (name, icon, color, sort_order) VALUES
('bakery', 'Cake', 'from-orange-500 to-red-500', 1),
('cemilan', 'Cookie', 'from-yellow-500 to-orange-500', 2),
('minuman', 'Coffee', 'from-blue-500 to-indigo-500', 3)
ON CONFLICT (name) DO NOTHING;

-- 7. Insert default payment methods
INSERT INTO payment_methods (name, code, sort_order) VALUES
('Tunai (Cash)', 'cash', 1),
('Transfer', 'transfer', 2)
ON CONFLICT (code) DO NOTHING;

-- 8. Insert default settings
INSERT INTO settings (key, value, description) VALUES
('low_stock_threshold', '10', 'Minimum stock level to trigger low stock alert'),
('store_name', 'Kenaya Yummy', 'Store/Brand name for display and reports')
ON CONFLICT (key) DO NOTHING;

-- 9. Enable Row Level Security
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;

-- 10. Create RLS policies for categories
CREATE POLICY "Users can view categories"
  ON categories FOR SELECT
  USING (true);

CREATE POLICY "Admins can insert categories"
  ON categories FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Admins can update categories"
  ON categories FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Admins can delete categories"
  ON categories FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- 11. Create RLS policies for payment_methods
CREATE POLICY "Users can view payment methods"
  ON payment_methods FOR SELECT
  USING (true);

CREATE POLICY "Admins can insert payment methods"
  ON payment_methods FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Admins can update payment methods"
  ON payment_methods FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Admins can delete payment methods"
  ON payment_methods FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- 12. Create RLS policies for settings
CREATE POLICY "Users can view settings"
  ON settings FOR SELECT
  USING (true);

CREATE POLICY "Admins can insert settings"
  ON settings FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Admins can update settings"
  ON settings FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Admins can delete settings"
  ON settings FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- 13. Create indexes
CREATE INDEX IF NOT EXISTS idx_categories_name ON categories(name);
CREATE INDEX IF NOT EXISTS idx_categories_active ON categories(is_active);
CREATE INDEX IF NOT EXISTS idx_payment_methods_code ON payment_methods(code);
CREATE INDEX IF NOT EXISTS idx_payment_methods_active ON payment_methods(is_active);
CREATE INDEX IF NOT EXISTS idx_settings_key ON settings(key);

-- 14. Verification queries
SELECT 'Categories:' as table_name;
SELECT id, name, icon, color, is_active FROM categories ORDER BY sort_order;

SELECT 'Payment Methods:' as table_name;
SELECT id, name, code, is_active FROM payment_methods ORDER BY sort_order;

SELECT 'Settings:' as table_name;
SELECT key, value, description FROM settings;

SELECT 'Products table constraint check:' as table_name;
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'products' AND column_name = 'category';

SELECT 'Raw Materials table constraint check:' as table_name;
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'raw_materials' AND column_name = 'unit';
