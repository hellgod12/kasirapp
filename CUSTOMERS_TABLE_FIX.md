# KasirApp - Customers Table Missing Fix

**Issue:** PGRST205 - Could not find the table 'public.customers' in the schema cache  
**Severity:** CRITICAL - Customers functionality completely broken  
**Analysis Date:** July 18, 2026  
**Status:** FIX IDENTIFIED

---

## Root Cause

The `customers-migration.sql` file exists in the project but has NOT been executed in the production database. The customers table, RLS policies, indexes, and triggers were never created.

---

## Migration File Status

**File:** `customers-migration.sql`  
**Status:** EXISTS BUT NOT APPLIED  
**Location:** Project root directory

**Contents:**
- ✅ Customers table creation (lines 8-20)
- ✅ Sales table customer_id column addition (line 23)
- ✅ Indexes for performance (lines 26-28)
- ✅ Updated_at trigger function (lines 31-37)
- ✅ Updated_at trigger (lines 40-44)
- ✅ Sample customers data (lines 47-51)
- ✅ RLS policies (lines 53-115)

**Why Not Applied:**
The migration file was created but never executed in Supabase SQL Editor. The deployment checklist did not include running this migration.

---

## Sales Table Foreign Key Status

**Current State:**
- The `atomic-checkout-migration.sql` has conditional logic to add `customer_id` to sales table
- It checks if customers table exists before adding the foreign key
- Since customers table doesn't exist, customer_id was added as UUID without foreign key constraint

**Line 12-16 of atomic-checkout-migration.sql:**
```sql
IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'customers') THEN
  ALTER TABLE sales ADD COLUMN IF NOT EXISTS customer_id UUID REFERENCES customers(id) ON DELETE SET NULL;
ELSE
  ALTER TABLE sales ADD COLUMN IF NOT EXISTS customer_id UUID;
END IF;
```

**Result:** customer_id column exists but has NO foreign key constraint.

---

## Required Fix

Execute the complete `customers-migration.sql` in Supabase SQL Editor. This will:
1. Create the customers table
2. Add the foreign key constraint to sales.customer_id
3. Create indexes
4. Create triggers
5. Insert sample data
6. Create RLS policies

---

## Exact SQL to Run in Supabase SQL Editor

Copy and paste the entire contents of `customers-migration.sql`:

```sql
-- Customers table migration for KasirApp
-- This enables customer management, transaction history, and loyalty tracking

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Customers table
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

-- Update sales table to include customer_id
ALTER TABLE sales ADD COLUMN IF NOT EXISTS customer_id UUID REFERENCES customers(id) ON DELETE SET NULL;

-- Index for better performance
CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone);
CREATE INDEX IF NOT EXISTS idx_customers_email ON customers(email);
CREATE INDEX IF NOT EXISTS idx_sales_customer_id ON sales(customer_id);

-- Function to update updated_at timestamp for customers
CREATE OR REPLACE FUNCTION update_customers_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for customers table
DROP TRIGGER IF EXISTS update_customers_updated_at ON customers;
CREATE TRIGGER update_customers_updated_at
  BEFORE UPDATE ON customers
  FOR EACH ROW
  EXECUTE FUNCTION update_customers_updated_at();

-- Insert sample customers
INSERT INTO customers (name, phone, email, address, balance, points) VALUES
('Budi Santoso', '081234567890', 'budi@email.com', 'Jl. Merdeka No. 1, Jakarta', 0, 100),
('Siti Rahayu', '081234567891', 'siti@email.com', 'Jl. Sudirman No. 2, Jakarta', 50000, 250),
('Ahmad Wijaya', '081234567892', 'ahmad@email.com', 'Jl. Gatot Subroto No. 3, Jakarta', 0, 50)
ON CONFLICT DO NOTHING;

-- RLS Policies for customers
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;

-- Policy: Admins can do everything
CREATE POLICY "Admins can manage customers" ON customers
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Policy: Cashiers can view customers
CREATE POLICY "Cashiers can view customers" ON customers
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'kasir')
    )
  );

-- Policy: Cashiers can update customer balance during sales
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

-- Policy: Only admins can insert/delete customers
CREATE POLICY "Admins can insert customers" ON customers
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Admins can delete customers" ON customers
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );
```

---

## Verification Steps

After running the SQL, verify the fix:

### 1. Verify customers table exists
```sql
SELECT * FROM information_schema.tables WHERE table_name = 'customers';
```
Should return 1 row.

### 2. Verify customers table structure
```sql
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'customers'
ORDER BY ordinal_position;
```
Should show all columns: id, name, phone, email, address, balance, points, notes, is_active, created_at, updated_at.

### 3. Verify foreign key constraint
```sql
SELECT
    tc.table_name, 
    kcu.column_name, 
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name 
FROM 
    information_schema.table_constraints AS tc 
    JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_name = kcu.constraint_name
    JOIN information_schema.constraint_column_usage AS ccu
      ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' 
  AND tc.table_name = 'sales';
```
Should show customer_id referencing customers(id).

### 4. Verify RLS policies
```sql
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'customers';
```
Should show 5 policies: Admins can manage customers, Cashiers can view customers, Cashiers can update customer balance, Admins can insert customers, Admins can delete customers.

### 5. Verify indexes
```sql
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename = 'customers';
```
Should show indexes: customers_pkey, idx_customers_phone, idx_customers_email.

### 6. Verify sample data
```sql
SELECT * FROM customers;
```
Should show 3 sample customers.

---

## Post-Fix Actions

1. **Test customer selection in POS**
   - Navigate to POS page
   - Verify customer dropdown appears
   - Verify customers can be selected

2. **Test customer balance update**
   - Complete a sale with a customer
   - Verify customer balance is updated

3. **Test customer management**
   - Navigate to customers page (if exists)
   - Verify customers can be created (admin only)
   - Verify customers can be viewed (admin/kasir)

---

## Prevention

Add to deployment checklist:

**Database Migration Verification:**
- [ ] Verify all migration files have been executed
- [ ] Verify customers table exists
- [ ] Verify discounts table exists
- [ ] Verify tax configuration exists
- [ ] Verify all foreign keys are in place
- [ ] Verify RLS policies are enabled

**Migration Execution Order:**
Document the correct migration execution order in DEPLOYMENT_ORDER.md:

1. supabase-schema.sql
2. supabase-auth-migration.sql
3. supabase-rls-policies.sql
4. customers-migration.sql ← ADD THIS
5. discounts-migration.sql
6. tax-migration.sql
7. store-profile-migration.sql
8. barcode-migration.sql
9. hpp-migration.sql
10. expenses-migration.sql
11. transaction-logs-migration.sql
12. atomic-checkout-migration.sql

---

## Summary

**Root Cause:** `customers-migration.sql` exists but was never executed in production database.

**Fix:** Run the complete `customers-migration.sql` in Supabase SQL Editor.

**No Code Changes Required:** Frontend code is correct. This is a database schema issue only.

**Risk Level:** HIGH - Customers functionality completely broken until fixed.

---

**Document Version:** 1.0  
**Last Updated:** July 18, 2026  
**Status:** FIX IDENTIFIED - SQL READY TO EXECUTE
