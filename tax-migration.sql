-- Tax calculation migration for KasirApp
-- This enables tax configuration and calculation for transactions

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Update sales table to include tax
ALTER TABLE sales ADD COLUMN IF NOT EXISTS tax_rate DECIMAL(5, 2) DEFAULT 0;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS tax_amount DECIMAL(10, 2) DEFAULT 0;

-- Add tax configuration to settings (using existing settings table)
-- Insert default tax settings if not exists
INSERT INTO settings (key, value) VALUES
  ('tax_enabled', 'false'),
  ('tax_rate', '11'),
  ('tax_name', 'PPN')
ON CONFLICT (key) DO NOTHING;

-- Create index for better performance on sales with tax
CREATE INDEX IF NOT EXISTS idx_sales_tax_rate ON sales(tax_rate);
