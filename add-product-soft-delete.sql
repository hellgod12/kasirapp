-- Migration: Add is_active column to products table for soft delete functionality
-- This allows products to be "deleted" without breaking historical sales data

-- Add is_active column to products table
ALTER TABLE products 
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

-- Update existing products to be active
UPDATE products 
SET is_active = true 
WHERE is_active IS NULL;

-- Add index for better performance on active products
CREATE INDEX IF NOT EXISTS idx_products_is_active ON products(is_active);

-- Verification query
SELECT 
  id, 
  name, 
  is_active 
FROM products 
ORDER BY name;
