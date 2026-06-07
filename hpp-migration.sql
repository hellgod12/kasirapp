-- Migration: Add HPP (Harga Pokok Produksi) tables for accurate cost calculation
-- This allows tracking raw materials and product recipes for accurate profit calculation

-- Create raw_materials table
CREATE TABLE IF NOT EXISTS raw_materials (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  unit TEXT NOT NULL CHECK (unit IN ('kg', 'gram', 'liter', 'ml', 'pcs')),
  cost_per_unit DECIMAL(10, 2) NOT NULL,
  stock DECIMAL(10, 2) DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create product_recipes table
CREATE TABLE IF NOT EXISTS product_recipes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  raw_material_id UUID NOT NULL REFERENCES raw_materials(id) ON DELETE CASCADE,
  quantity_used DECIMAL(10, 2) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(product_id, raw_material_id)
);

-- Add hpp column to products table
ALTER TABLE products 
ADD COLUMN IF NOT EXISTS hpp DECIMAL(10, 2) DEFAULT 0;

-- Enable Row Level Security
ALTER TABLE raw_materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_recipes ENABLE ROW LEVEL SECURITY;

-- Create policies for raw_materials
-- Users can view all raw materials
CREATE POLICY "Users can view raw materials"
  ON raw_materials FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
    )
  );

-- Admins can insert raw materials
CREATE POLICY "Admins can insert raw materials"
  ON raw_materials FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Admins can update raw materials
CREATE POLICY "Admins can update raw materials"
  ON raw_materials FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Admins can delete raw materials
CREATE POLICY "Admins can delete raw materials"
  ON raw_materials FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Create policies for product_recipes
-- Users can view all product recipes
CREATE POLICY "Users can view product recipes"
  ON product_recipes FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
    )
  );

-- Admins can insert product recipes
CREATE POLICY "Admins can insert product recipes"
  ON product_recipes FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Admins can update product recipes
CREATE POLICY "Admins can update product recipes"
  ON product_recipes FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Admins can delete product recipes
CREATE POLICY "Admins can delete product recipes"
  ON product_recipes FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_raw_materials_name ON raw_materials(name);
CREATE INDEX IF NOT EXISTS idx_product_recipes_product_id ON product_recipes(product_id);
CREATE INDEX IF NOT EXISTS idx_product_recipes_raw_material_id ON product_recipes(raw_material_id);

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

-- Verification queries
SELECT 
  id, 
  name, 
  unit, 
  cost_per_unit, 
  stock 
FROM raw_materials 
ORDER BY name;

SELECT 
  pr.id,
  p.name as product_name,
  rm.name as raw_material_name,
  pr.quantity_used,
  rm.cost_per_unit,
  (pr.quantity_used * rm.cost_per_unit) as cost
FROM product_recipes pr
JOIN products p ON pr.product_id = p.id
JOIN raw_materials rm ON pr.raw_material_id = rm.id
ORDER BY p.name, rm.name;

SELECT 
  id, 
  name, 
  cost,
  hpp,
  (price - hpp) as estimated_profit
FROM products 
ORDER BY name;
