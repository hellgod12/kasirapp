-- Barcode field migration for KasirApp
-- This enables barcode scanning for faster checkout

-- Add barcode column to products table
ALTER TABLE products ADD COLUMN IF NOT EXISTS barcode TEXT UNIQUE;

-- Create index for faster barcode lookups
CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode);

-- Add comment to column
COMMENT ON COLUMN products.barcode IS 'Product barcode for scanning (optional)';

-- Update sample products with barcodes
UPDATE products SET barcode = '8991001001' WHERE name = 'Roti Coklat';
UPDATE products SET barcode = '8991001002' WHERE name = 'Roti Keju';
UPDATE products SET barcode = '8991001003' WHERE name = 'Croissant';
UPDATE products SET barcode = '8991001004' WHERE name = 'Donat Coklat';
UPDATE products SET barcode = '8991001005' WHERE name = 'Roti Tawar';
UPDATE products SET barcode = '8991002001' WHERE name = 'Keripik Singkong';
UPDATE products SET barcode = '8991002002' WHERE name = 'Keripik Pisang';
UPDATE products SET barcode = '8991002003' WHERE name = 'Pisang Goreng';
UPDATE products SET barcode = '8991002004' WHERE name = 'Kentang Goreng';
UPDATE products SET barcode = '8991003001' WHERE name = 'Es Teh Manis';
UPDATE products SET barcode = '8991003002' WHERE name = 'Es Jeruk';
UPDATE products SET barcode = '8991003003' WHERE name = 'Kopi Susu';
UPDATE products SET barcode = '8991003004' WHERE name = 'Jus Alpukat';
UPDATE products SET barcode = '8991003005' WHERE name = 'Es Campur';
