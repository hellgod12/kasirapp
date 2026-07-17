# Migration Roadmap to v1.0 - Zero Data Loss Plan

**Document Date:** July 18, 2026  
**Project:** KasirApp  
**Purpose:** Migrate existing database to v1.0 production schema with zero data loss

---

## Executive Summary

This document provides a step-by-step roadmap to migrate an existing KasirApp database from the fragmented migration state to the clean v1.0 production schema without any data loss.

**Migration Strategy:** Incremental with data preservation  
**Estimated Downtime:** 5-10 minutes  
**Risk Level:** MEDIUM (with backup)  
**Rollback:** Full rollback available

---

## Pre-Migration Checklist

### 1. Database Backup (CRITICAL)

**Action:** Create full database backup before migration

```sql
-- Via Supabase Dashboard
-- 1. Go to Database > Backups
-- 2. Click "Create Backup"
-- 3. Download backup file
-- 4. Store in secure location
```

**Verification:**
- [ ] Backup completed successfully
- [ ] Backup file downloaded
- [ ] Backup file verified (can be restored)
- [ ] Backup stored in secure location

### 2. Current State Assessment

**Action:** Document current database state

```sql
-- Run this to document current state
SELECT 
  table_name,
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = t.table_name) as column_count,
  (SELECT COUNT(*) FROM pg_indexes WHERE tablename = t.table_name) as index_count
FROM information_schema.tables t
WHERE table_schema = 'public'
AND table_type = 'BASE TABLE'
ORDER BY table_name;
```

**Document:**
- [ ] Current table count
- [ ] Current row counts per table
- [ ] Current RLS policies
- [ ] Current functions
- [ ] Current triggers

### 3. Application Downtime Schedule

**Action:** Schedule maintenance window

**Recommended:** Low-traffic period (e.g., 2:00 AM - 3:00 AM)

**Notification:**
- [ ] Users notified 24 hours in advance
- [ ] Maintenance banner displayed
- [ ] Support team notified

---

## Migration Steps

### Phase 1: Preparation (5 minutes)

#### Step 1.1: Create Migration Tracking Table

**Action:** Create schema_migrations table if not exists

```sql
CREATE TABLE IF NOT EXISTS schema_migrations (
  version TEXT PRIMARY KEY,
  applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  checksum TEXT,
  description TEXT
);
```

**Risk:** LOW - New table only

**Rollback:** DROP TABLE schema_migrations

---

#### Step 1.2: Create SECURITY DEFINER Functions

**Action:** Create role check functions to fix RLS recursion

```sql
-- Create is_admin function
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

-- Create is_kasir function
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

-- Create is_authenticated function
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_kasir() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_authenticated() TO authenticated;
```

**Risk:** LOW - New functions only

**Rollback:** DROP FUNCTION public.is_admin(), public.is_kasir(), public.is_authenticated()

---

### Phase 2: Schema Updates (10 minutes)

#### Step 2.1: Add Missing Columns

**Action:** Add missing columns to existing tables

```sql
-- Add is_active to products if not exists
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

-- Add hpp to products if not exists
ALTER TABLE products ADD COLUMN IF NOT EXISTS hpp DECIMAL(10, 2) DEFAULT 0;

-- Add barcode to products if not exists
ALTER TABLE products ADD COLUMN IF NOT EXISTS barcode TEXT UNIQUE;

-- Add customer_id to sales if not exists (without FK initially)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'sales' AND column_name = 'customer_id'
  ) THEN
    ALTER TABLE sales ADD COLUMN customer_id UUID;
  END IF;
END $$;

-- Add discount_id to sales if not exists (without FK initially)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'sales' AND column_name = 'discount_id'
  ) THEN
    ALTER TABLE sales ADD COLUMN discount_id UUID;
  END IF;
END $$;

-- Add discount_amount to sales if not exists
ALTER TABLE sales ADD COLUMN IF NOT EXISTS discount_amount DECIMAL(10, 2) DEFAULT 0;

-- Add tax_rate to sales if not exists
ALTER TABLE sales ADD COLUMN IF NOT EXISTS tax_rate DECIMAL(5, 2) DEFAULT 0;

-- Add tax_amount to sales if not exists
ALTER TABLE sales ADD COLUMN IF NOT EXISTS tax_amount DECIMAL(10, 2) DEFAULT 0;

-- Add transaction_token to sales if not exists
ALTER TABLE sales ADD COLUMN IF NOT EXISTS transaction_token TEXT UNIQUE;
```

**Risk:** LOW - IF NOT EXISTS ensures idempotency

**Rollback:** ALTER TABLE DROP COLUMN for each added column

---

#### Step 2.2: Remove Conflicting Constraints

**Action:** Remove constraints that conflict with dynamic data

```sql
-- Remove payment_method CHECK constraint if exists
ALTER TABLE sales DROP CONSTRAINT IF EXISTS check_payment_method;

-- Remove products.category CHECK constraint if exists
ALTER TABLE products DROP CONSTRAINT IF EXISTS products_category_check;

-- Remove raw_materials.unit CHECK constraint if exists
ALTER TABLE raw_materials DROP CONSTRAINT IF EXISTS raw_materials_unit_check;
```

**Risk:** LOW - Only removes constraints, no data loss

**Rollback:** Recreate constraints if needed

---

#### Step 2.3: Add Missing Foreign Keys

**Action:** Add proper foreign key constraints

```sql
-- Add customer_id FK if customers table exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'customers') THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints 
      WHERE constraint_name = 'sales_customer_id_fkey'
      AND table_name = 'sales'
    ) THEN
      ALTER TABLE sales 
      ADD CONSTRAINT sales_customer_id_fkey 
      FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL;
    END IF;
  END IF;
END $$;

-- Add discount_id FK if discounts table exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'discounts') THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints 
      WHERE constraint_name = 'sales_discount_id_fkey'
      AND table_name = 'sales'
    ) THEN
      ALTER TABLE sales 
      ADD CONSTRAINT sales_discount_id_fkey 
      FOREIGN KEY (discount_id) REFERENCES discounts(id) ON DELETE SET NULL;
    END IF;
  END IF;
END $$;
```

**Risk:** MEDIUM - May fail if orphaned records exist

**Rollback:** ALTER TABLE DROP CONSTRAINT for each FK

**Mitigation:** Clean orphaned records before adding FKs

---

#### Step 2.4: Add Missing Composite Indexes

**Action:** Add composite indexes for performance

```sql
-- Add composite indexes
CREATE INDEX IF NOT EXISTS idx_products_active_date ON products(is_active, created_at);
CREATE INDEX IF NOT EXISTS idx_sales_created_by_date ON sales(created_at, created_by);
CREATE INDEX IF NOT EXISTS idx_sales_customer_date ON sales(customer_id, created_at);
CREATE INDEX IF NOT EXISTS idx_sale_items_product_date ON sale_items(product_id, created_at);
CREATE INDEX IF NOT EXISTS idx_stock_movements_type_date ON stock_movements(type, created_at);
CREATE INDEX IF NOT EXISTS idx_expenses_date_category ON expenses(expense_date, category);
```

**Risk:** LOW - IF NOT EXISTS ensures idempotency

**Rollback:** DROP INDEX for each added index

---

#### Step 2.5: Add Data Validation Constraints

**Action:** Add CHECK constraints for data validation

```sql
-- Add validation constraints
ALTER TABLE products ADD CONSTRAINT check_products_price_positive CHECK (price > 0);
ALTER TABLE products ADD CONSTRAINT check_products_cost_nonnegative CHECK (cost >= 0);
ALTER TABLE products ADD CONSTRAINT check_products_stock_nonnegative CHECK (stock >= 0);
ALTER TABLE products ADD CONSTRAINT check_products_hpp_nonnegative CHECK (hpp >= 0);

ALTER TABLE sales ADD CONSTRAINT check_sales_total_amount_positive CHECK (total_amount > 0);
ALTER TABLE sales ADD CONSTRAINT check_sales_total_cost_nonnegative CHECK (total_cost >= 0);
ALTER TABLE sales ADD CONSTRAINT check_sales_discount_amount_nonnegative CHECK (discount_amount >= 0);
ALTER TABLE sales ADD CONSTRAINT check_sales_tax_rate_nonnegative CHECK (tax_rate >= 0);
ALTER TABLE sales ADD CONSTRAINT check_sales_tax_amount_nonnegative CHECK (tax_amount >= 0);

ALTER TABLE sale_items ADD CONSTRAINT check_sale_items_quantity_positive CHECK (quantity > 0);
ALTER TABLE sale_items ADD CONSTRAINT check_sale_items_price_positive CHECK (price > 0);
ALTER TABLE sale_items ADD CONSTRAINT check_sale_items_cost_nonnegative CHECK (cost >= 0);
ALTER TABLE sale_items ADD CONSTRAINT check_sale_items_subtotal_positive CHECK (subtotal > 0);

ALTER TABLE customers ADD CONSTRAINT check_customers_points_nonnegative CHECK (points >= 0);

ALTER TABLE discounts ADD CONSTRAINT check_discounts_value_positive CHECK (value > 0);
ALTER TABLE discounts ADD CONSTRAINT check_discounts_min_purchase_nonnegative CHECK (min_purchase >= 0);

ALTER TABLE expenses ADD CONSTRAINT check_expenses_amount_positive CHECK (amount > 0);

ALTER TABLE waste_items ADD CONSTRAINT check_waste_items_quantity_positive CHECK (quantity > 0);

ALTER TABLE daily_production ADD CONSTRAINT check_daily_production_quantity_produced_nonnegative CHECK (quantity_produced >= 0);
ALTER TABLE daily_production ADD CONSTRAINT check_daily_production_quantity_sold_nonnegative CHECK (quantity_sold >= 0);
ALTER TABLE daily_production ADD CONSTRAINT check_daily_production_quantity_waste_nonnegative CHECK (quantity_waste >= 0);
ALTER TABLE daily_production ADD CONSTRAINT check_daily_production_quantity_remaining_nonnegative CHECK (quantity_remaining >= 0);

ALTER TABLE raw_materials ADD CONSTRAINT check_raw_materials_cost_per_unit_positive CHECK (cost_per_unit > 0);
ALTER TABLE raw_materials ADD CONSTRAINT check_raw_materials_stock_nonnegative CHECK (stock >= 0);

ALTER TABLE product_recipes ADD CONSTRAINT check_product_recipes_quantity_used_positive CHECK (quantity_used > 0);
```

**Risk:** MEDIUM - May fail if existing data violates constraints

**Rollback:** ALTER TABLE DROP CONSTRAINT for each added constraint

**Mitigation:** Clean invalid data before adding constraints

---

### Phase 3: RLS Policy Migration (5 minutes)

#### Step 3.1: Drop Old RLS Policies

**Action:** Drop all existing RLS policies that use direct profiles queries

```sql
-- Drop all policies that query profiles directly
DROP POLICY IF EXISTS "Admins can view all profiles" ON profiles;
DROP POLICY IF EXISTS "Admins can view all products" ON products;
DROP POLICY IF EXISTS "Admins can insert products" ON products;
DROP POLICY IF EXISTS "Admins can update products" ON products;
DROP POLICY IF EXISTS "Admins can delete products" ON products;
DROP POLICY IF EXISTS "Admins can view all sales" ON sales;
DROP POLICY IF EXISTS "Admins can update sales" ON sales;
DROP POLICY IF EXISTS "Admins can view all sale items" ON sale_items;
DROP POLICY IF EXISTS "Admins can view all stock movements" ON stock_movements;
DROP POLICY IF EXISTS "Admins can insert stock movements" ON stock_movements;
DROP POLICY IF EXISTS "Admins can view all daily production" ON daily_production;
DROP POLICY IF EXISTS "Admins can insert daily production" ON daily_production;
DROP POLICY IF EXISTS "Admins can update daily production" ON daily_production;
DROP POLICY IF EXISTS "Admins can view all waste items" ON waste_items;
DROP POLICY IF EXISTS "Admins can insert waste items" ON waste_items;
DROP POLICY IF EXISTS "Admins can view all suppliers" ON suppliers;
DROP POLICY IF EXISTS "Admins can insert suppliers" ON suppliers;
DROP POLICY IF EXISTS "Admins can update suppliers" ON suppliers;
DROP POLICY IF EXISTS "Admins can delete suppliers" ON suppliers;
DROP POLICY IF EXISTS "Admins can manage customers" ON customers;
DROP POLICY IF EXISTS "Admins can manage discounts" ON discounts;
DROP POLICY IF EXISTS "Admins can insert categories" ON categories;
DROP POLICY IF EXISTS "Admins can update categories" ON categories;
DROP POLICY IF EXISTS "Admins can delete categories" ON categories;
DROP POLICY IF EXISTS "Admins can insert payment methods" ON payment_methods;
DROP POLICY IF EXISTS "Admins can update payment methods" ON payment_methods;
DROP POLICY IF EXISTS "Admins can delete payment methods" ON payment_methods;
DROP POLICY IF EXISTS "Admins can insert settings" ON settings;
DROP POLICY IF EXISTS "Admins can update settings" ON settings;
DROP POLICY IF EXISTS "Admins can delete settings" ON settings;
DROP POLICY IF EXISTS "Admins can insert raw materials" ON raw_materials;
DROP POLICY IF EXISTS "Admins can update raw materials" ON raw_materials;
DROP POLICY IF EXISTS "Admins can delete raw materials" ON raw_materials;
DROP POLICY IF EXISTS "Admins can insert product recipes" ON product_recipes;
DROP POLICY IF EXISTS "Admins can update product recipes" ON product_recipes;
DROP POLICY IF EXISTS "Admins can delete product recipes" ON product_recipes;
DROP POLICY IF EXISTS "Admins can insert expenses" ON expenses;
DROP POLICY IF EXISTS "Admins can update expenses" ON expenses;
DROP POLICY IF EXISTS "Admins can delete expenses" ON expenses;
DROP POLICY IF EXISTS "Allow admins to read transaction logs" ON transaction_logs;
DROP POLICY IF EXISTS "Allow admins to insert transaction logs" ON transaction_logs;
```

**Risk:** LOW - IF EXISTS ensures idempotency

**Rollback:** Recreate old policies from backup

---

#### Step 3.2: Create New RLS Policies

**Action:** Create RLS policies using SECURITY DEFINER functions

```sql
-- Profiles policies
CREATE POLICY "Admins can view all profiles"
  ON profiles FOR SELECT
  USING (public.is_admin());

-- Products policies
CREATE POLICY "Admins can manage products" ON products
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "Cashiers can view products" ON products
  FOR SELECT
  USING (public.is_authenticated());

-- Sales policies
CREATE POLICY "Admins can view all sales" ON sales
  FOR SELECT
  USING (public.is_admin());

CREATE POLICY "Cashiers can view own sales" ON sales
  FOR SELECT
  USING (public.is_kasir() AND created_by = auth.uid());

CREATE POLICY "Authenticated users can insert sales" ON sales
  FOR INSERT
  WITH CHECK (public.is_authenticated() AND created_by = auth.uid());

CREATE POLICY "Admins can update sales" ON sales
  FOR UPDATE
  USING (public.is_admin());

-- Sale items policies
CREATE POLICY "Admins can view all sale items" ON sale_items
  FOR SELECT
  USING (public.is_admin());

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
CREATE POLICY "Admins can view all stock movements" ON stock_movements
  FOR SELECT
  USING (public.is_admin());

CREATE POLICY "Cashiers can view own stock movements" ON stock_movements
  FOR SELECT
  USING (public.is_kasir() AND created_by = auth.uid());

CREATE POLICY "Admins can insert stock movements" ON stock_movements
  FOR INSERT
  WITH CHECK (public.is_admin() AND created_by = auth.uid());

CREATE POLICY "Cashiers can insert stock movements for POS" ON stock_movements
  FOR INSERT
  WITH CHECK (public.is_kasir() AND created_by = auth.uid() AND type = 'out');

-- Suppliers policies
CREATE POLICY "Admins can manage suppliers" ON suppliers
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Daily production policies
CREATE POLICY "Admins can manage daily production" ON daily_production
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin() AND created_by = auth.uid());

-- Waste items policies
CREATE POLICY "Admins can manage waste items" ON waste_items
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin() AND created_by = auth.uid());

-- Customers policies
CREATE POLICY "Admins can manage customers" ON customers
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "Cashiers can view customers" ON customers
  FOR SELECT
  USING (public.is_authenticated());

CREATE POLICY "Cashiers can update customer balance" ON customers
  FOR UPDATE
  USING (public.is_authenticated())
  WITH CHECK (public.is_authenticated());

-- Discounts policies
CREATE POLICY "Admins can manage discounts" ON discounts
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "Cashiers can view discounts" ON discounts
  FOR SELECT
  USING (public.is_authenticated());

-- Categories policies
CREATE POLICY "Admins can manage categories" ON categories
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Payment methods policies
CREATE POLICY "Admins can manage payment methods" ON payment_methods
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Settings policies
CREATE POLICY "Admins can manage settings" ON settings
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Raw materials policies
CREATE POLICY "Admins can manage raw materials" ON raw_materials
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Product recipes policies
CREATE POLICY "Admins can manage product recipes" ON product_recipes
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Expenses policies
CREATE POLICY "Admins can manage expenses" ON expenses
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Transaction logs policies
CREATE POLICY "Allow admins to read transaction logs" ON transaction_logs
  FOR SELECT
  TO authenticated
  USING (public.is_admin());

CREATE POLICY "Allow admins to insert transaction logs" ON transaction_logs
  FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin());
```

**Risk:** MEDIUM - May affect access if functions fail

**Rollback:** Drop new policies, recreate old policies

**Mitigation:** Test authentication flows after migration

---

### Phase 4: Function Consolidation (3 minutes)

#### Step 4.1: Consolidate Duplicate Functions

**Action:** Ensure single version of each function

```sql
-- update_updated_at_column - already exists, keep as is
-- calculate_product_hpp - already exists, keep as is
-- update_all_product_hpp - already exists, keep as is
-- handle_new_user - already exists, keep as is
-- process_checkout - already exists, update with SECURITY DEFINER

-- Update process_checkout to use SECURITY DEFINER
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
-- [Same implementation as DATABASE_V1.0_PRODUCTION.sql]
-- Copy from DATABASE_V1.0_PRODUCTION.sql lines 822-1025
$$;

GRANT EXECUTE ON FUNCTION public.process_checkout TO authenticated;
```

**Risk:** LOW - OR REPLACE ensures idempotency

**Rollback:** Restore function from backup

---

### Phase 5: Data Validation (2 minutes)

#### Step 5.1: Validate Data Integrity

**Action:** Run validation queries to ensure no data loss

```sql
-- Check for orphaned records
SELECT 'Orphaned sale_items' as check, COUNT(*) as count
FROM sale_items si
LEFT JOIN sales s ON si.sale_id = s.id
WHERE s.id IS NULL;

SELECT 'Orphaned stock_movements' as check, COUNT(*) as count
FROM stock_movements sm
LEFT JOIN products p ON sm.product_id = p.id
WHERE p.id IS NULL;

-- Check for invalid data
SELECT 'Products with negative price' as check, COUNT(*) as count
FROM products WHERE price <= 0;

SELECT 'Products with negative stock' as check, COUNT(*) as count
FROM products WHERE stock < 0;

SELECT 'Sales with negative amount' as check, COUNT(*) as count
FROM sales WHERE total_amount <= 0;

-- Check row counts before/after
SELECT 'Products row count' as check, COUNT(*) as count FROM products;
SELECT 'Sales row count' as check, COUNT(*) as count FROM sales;
SELECT 'Customers row count' as check, COUNT(*) as count FROM customers;
```

**Risk:** NONE - Read-only queries

**Rollback:** N/A

---

#### Step 5.2: Record Migration

**Action:** Record migration in schema_migrations table

```sql
INSERT INTO schema_migrations (version, checksum, description) VALUES
('1.0.0', md5(current_timestamp::text), 'Migrated to v1.0 production schema')
ON CONFLICT (version) DO NOTHING;
```

**Risk:** LOW - Simple insert

**Rollback:** DELETE from schema_migrations where version = '1.0.0'

---

### Phase 6: Post-Migration Validation (5 minutes)

#### Step 6.1: Test Authentication

**Action:** Test login and authentication flows

**Steps:**
1. Login as admin user
2. Verify admin can access all resources
3. Login as kasir user
4. Verify kasir can access allowed resources
5. Verify RLS policies work correctly

**Expected Results:**
- Admin can view/edit all tables
- Kasir can view products (read-only)
- Kasir can create sales
- Kasir cannot access admin-only tables

**Rollback:** If authentication fails, rollback RLS policies

---

#### Step 6.2: Test Business Functions

**Action:** Test core business functions

**Steps:**
1. Create a test sale
2. Verify stock updates
3. Verify profit calculation
4. Test discount application
5. Test tax calculation

**Expected Results:**
- Sale created successfully
- Stock updated correctly
- Profit calculated correctly
- Discount applied correctly
- Tax calculated correctly

**Rollback:** If functions fail, rollback to previous version

---

#### Step 6.3: Verify Data Integrity

**Action:** Verify no data was lost

```sql
-- Compare row counts with pre-migration counts
-- (Use counts from Step 1.2)

SELECT 'Post-migration row counts' as status;
SELECT COUNT(*) as products_count FROM products;
SELECT COUNT(*) as sales_count FROM sales;
SELECT COUNT(*) as customers_count FROM customers;
SELECT COUNT(*) as discounts_count FROM discounts;
```

**Expected Results:**
- All row counts match pre-migration counts
- No data lost

**Rollback:** If data loss detected, restore from backup

---

## Rollback Plan

### Rollback Triggers

Rollback should be triggered if:
1. Authentication fails
2. Data loss detected
3. Business functions fail
4. Performance degradation > 50%
5. Critical errors in application logs

### Rollback Steps

#### Step R1: Restore Database Backup

**Action:** Restore from pre-migration backup

```sql
-- Via Supabase Dashboard
-- 1. Go to Database > Backups
-- 2. Select pre-migration backup
-- 3. Click "Restore"
-- 4. Wait for restoration to complete
```

**Estimated Time:** 5-10 minutes

**Risk:** LOW - Restores to known good state

---

#### Step R2: Verify Restoration

**Action:** Verify database is restored correctly

```sql
-- Verify row counts match pre-migration
SELECT COUNT(*) FROM products;
SELECT COUNT(*) FROM sales;
-- etc.
```

**Expected Results:**
- All data restored
- Schema matches pre-migration state

---

## Risk Mitigation

### Risk 1: Data Loss

**Mitigation:**
- Full backup before migration
- Row count validation before/after
- Orphaned record detection
- Immediate rollback if data loss detected

### Risk 2: Authentication Failure

**Mitigation:**
- Test authentication immediately after RLS migration
- Keep old policies documented for rollback
- Have DBA on standby during migration

### Risk 3: Constraint Violations

**Mitigation:**
- Clean invalid data before adding constraints
- Use IF NOT EXISTS for idempotency
- Test constraints in staging first

### Risk 4: Performance Degradation

**Mitigation:**
- Monitor query performance during migration
- Have index rollback plan
- Test in staging environment first

### Risk 5: Downtime Exceeded

**Mitigation:**
- Practice migration in staging
- Time each step
- Have rollback plan ready
- Communicate with users

---

## Timeline

| Phase | Duration | Description |
|-------|----------|-------------|
| Pre-Migration | 30 min | Backup, assessment, notification |
| Phase 1: Preparation | 5 min | Create tracking table, functions |
| Phase 2: Schema Updates | 10 min | Add columns, indexes, constraints |
| Phase 3: RLS Migration | 5 min | Drop old policies, create new |
| Phase 4: Function Consolidation | 3 min | Consolidate duplicate functions |
| Phase 5: Data Validation | 2 min | Validate data integrity |
| Phase 6: Post-Migration Validation | 5 min | Test authentication, functions |
| **Total Downtime** | **30 min** | Application unavailable |

**Note:** Actual downtime can be reduced to 5-10 minutes by performing Phases 1-5 before maintenance window, with only Phase 6 requiring downtime.

---

## Success Criteria

Migration is successful if:
- [ ] All data preserved (row counts match)
- [ ] Authentication works for both admin and kasir
- [ ] RLS policies work correctly
- [ ] Business functions (checkout, stock update) work
- [ ] No data validation errors
- [ ] Performance within 10% of baseline
- [ ] No critical errors in logs

---

## Post-Migration Tasks

### 1. Update Application Code

**Action:** Update application to use new schema

**Changes Required:**
- Update TypeScript interfaces for new columns
- Update API calls for new functions
- Update error handling for new constraints

### 2. Update Documentation

**Action:** Update database documentation

**Changes Required:**
- Update schema documentation
- Update migration documentation
- Update API documentation

### 3. Monitor Production

**Action:** Monitor for issues

**Monitoring:**
- Error logs
- Performance metrics
- User feedback
- Database metrics

### 4. Archive Old Migration Files

**Action:** Archive old migration files

**Action:**
- Move old migration files to archive folder
- Document migration history
- Keep for reference

---

## Contact Information

**Database Administrator:** [Name]  
**Application Developer:** [Name]  
**Support Team:** [Contact]  
**Emergency Contact:** [Contact]

---

**Document Completed:** July 18, 2026  
**Migration Scheduled:** TBD  
**Migration Executed:** TBD
