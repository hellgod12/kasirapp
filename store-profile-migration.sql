-- Store profile and branding migration for KasirApp
-- This enables comprehensive store profile management

-- Add additional store profile settings
INSERT INTO settings (key, value, description) VALUES
  ('store_address', '', 'Store physical address'),
  ('store_phone', '', 'Store contact phone number'),
  ('store_email', '', 'Store contact email'),
  ('store_logo_url', '', 'Store logo image URL'),
  ('receipt_header', 'TERIMA KASIH', 'Receipt header text'),
  ('receipt_footer', 'Barang yang sudah dibeli tidak dapat ditukar/dikembalikan', 'Receipt footer text')
ON CONFLICT (key) DO NOTHING;
