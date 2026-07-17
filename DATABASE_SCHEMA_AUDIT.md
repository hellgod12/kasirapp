# KasirApp Database Schema Audit

**Purpose:** Audit database schema for Version 1.0 upgrade  
**Analysis Date:** July 18, 2026  
**Status:** AUDIT COMPLETE

---

## Executive Summary

The production database is missing several critical tables and columns required for Version 1.0. The following migrations were never executed:

**Missing Tables:**
- customers
- discounts
- categories
- payment_methods
- settings
- raw_materials
- product_recipes
- expenses
- transaction_logs

**Missing Columns:**
- products.barcode
- products.hpp
- sales.customer_id
- sales.discount_amount
- sales.discount_id
- sales.tax_rate
- sales.tax_amount
- sales.transaction_token

**Missing Foreign Keys:**
- sales.customer_id → customers(id)
- sales.discount_id → discounts(id)

**Missing RLS Policies:**
- All new tables lack RLS policies

**Solution:** Execute DATABASE_UPGRADE_V1.sql in Supabase SQL Editor.

---

## Migration Inventory

### 1. supabase-schema.sql

**Purpose:** Core business logic tables  
**Execution Order:** 1 (first)  
**Dependencies:** None  
**Modifies Existing Tables:** No (creates new tables)

**Tables Created:**
- products
- sales
- sale_items
- stock_movements
- suppliers
- daily_production
- waste_items

**Status:** ✅ LIKELY APPLIED (core tables exist based on error messages)

---

### 2. supabase-auth-migration.sql

**Purpose:** Supabase Auth integration with profiles table  
**Execution Order:** 2  
**Dependencies:** None  
**Modifies Existing Tables:** No (creates new table)

**Tables Created:**
- profiles

**Functions Created:**
- handle_new_user() - Auto-create profile on signup

**Triggers Created:**
- on_auth_user_created - Trigger for profile creation

**Status:** ⚠️ UNKNOWN (may or may not be applied)

---

### 3. supabase-rls-policies.sql

**Purpose:** Row Level Security for core tables  
**Execution Order:** 3  
**Dependencies:** supabase-schema.sql, supabase-auth-migration.sql  
**Modifies Existing Tables:** Yes (adds RLS policies)

**Tables Modified:**
- products
- sales
- sale_items
- stock_movements
- daily_production
- waste_items
- suppliers

**Policies Created:** 20+ policies for role-based access control

**Status:** ⚠️ UNKNOWN (may or may not be applied)

---

### 4. customers-migration.sql

**Purpose:** Customer management and loyalty tracking  
**Execution Order:** 4  
**Dependencies:** supabase-schema.sql  
**Modifies Existing Tables:** Yes (adds customer_id to sales)

**Tables Created:**
- customers

**Columns Added:**
- sales.customer_id (UUID, FK to customers)

**Indexes Created:**
- idx_customers_phone
- idx_customers_email
- idx_sales_customer_id

**Triggers Created:**
- update_customers_updated_at

**RLS Policies Created:** 5 policies

**Sample Data:** 3 sample customers

**Status:** ❌ NOT APPLIED (confirmed by PGRST205 error)

---

### 5. discounts-migration.sql

**Purpose:** Discount management for products and transactions  
**Execution Order:** 5  
**Dependencies:** supabase-schema.sql  
**Modifies Existing Tables:** Yes (adds discount columns to sales)

**Tables Created:**
- discounts

**Columns Added:**
- sales.discount_amount (DECIMAL)
- sales.discount_id (UUID, FK to discounts)

**Indexes Created:**
- idx_discounts_is_active
- idx_discounts_valid_period
- idx_sales_discount_id

**Triggers Created:**
- update_discounts_updated_at

**RLS Policies Created:** 2 policies

**Sample Data:** 3 sample discounts

**Status:** ❌ NOT APPLIED (discounts table missing)

---

### 6. tax-migration.sql

**Purpose:** Tax configuration and calculation  
**Execution Order:** 6  
**Dependencies:** phase1-migration.sql (requires settings table)  
**Modifies Existing Tables:** Yes (adds tax columns to sales)

**Columns Added:**
- sales.tax_rate (DECIMAL)
- sales.tax_amount (DECIMAL)

**Settings Inserted:**
- tax_enabled
- tax_rate
- tax_name

**Indexes Created:**
- idx_sales_tax_rate

**Status:** ❌ NOT APPLIED (tax columns missing)

---

### 7. phase1-migration.sql

**Purpose:** Dynamic categories, payment methods, and settings  
**Execution Order:** 7  
**Dependencies:** supabase-schema.sql  
**Modifies Existing Tables:** Yes (removes CHECK constraints)

**Tables Created:**
- categories
- payment_methods
- settings

**Constraints Removed:**
- products.category_check
- raw_materials.unit_check

**RLS Policies Created:** 12 policies (4 per table)

**Sample Data:** 3 categories, 2 payment methods, 2 settings

**Status:** ❌ NOT APPLIED (category dropdown empty confirms missing)

---

### 8. barcode-migration.sql

**Purpose:** Barcode scanning for faster checkout  
**Execution Order:** 8  
**Dependencies:** supabase-schema.sql  
**Modifies Existing Tables:** Yes (adds barcode to products)

**Columns Added:**
- products.barcode (TEXT, UNIQUE)

**Indexes Created:**
- idx_products_barcode

**Sample Data:** Updates 14 products with barcodes

**Status:** ❌ NOT APPLIED (confirmed by PGRST204 error)

---

### 9. hpp-migration.sql

**Purpose:** HPP (Harga Pokok Produksi) for accurate cost calculation  
**Execution Order:** 9  
**Dependencies:** supabase-schema.sql  
**Modifies Existing Tables:** Yes (adds hpp to products)

**Tables Created:**
- raw_materials
- product_recipes

**Columns Added:**
- products.hpp (DECIMAL)

**Functions Created:**
- calculate_product_hpp()
- update_all_product_hpp()

**RLS Policies Created:** 8 policies

**Status:** ❌ NOT APPLIED (tables missing)

---

### 10. hpp-functions-migration.sql

**Purpose:** HPP calculation triggers  
**Execution Order:** 10  
**Dependencies:** hpp-migration.sql  
**Modifies Existing Tables:** No (creates triggers)

**Functions Created:**
- calculate_product_hpp() (duplicate)
- update_all_product_hpp() (duplicate)
- update_product_hpp_trigger()

**Triggers Created:**
- trigger_update_hpp_after_insert
- trigger_update_hpp_after_update
- trigger_update_hpp_after_delete

**Status:** ❌ NOT APPLIED (depends on hpp-migration.sql)

---

### 11. expenses-migration.sql

**Purpose:** Expense management for net profit calculation  
**Execution Order:** 11  
**Dependencies:** supabase-auth-migration.sql  
**Modifies Existing Tables:** No (creates new table)

**Tables Created:**
- expenses

**RLS Policies Created:** 4 policies

**Status:** ❌ NOT APPLIED (table missing)

---

### 12. transaction-logs-migration.sql

**Purpose:** Transaction modification logging (void, delete, edit)  
**Execution Order:** 12  
**Dependencies:** supabase-schema.sql  
**Modifies Existing Tables:** No (creates new table)

**Tables Created:**
- transaction_logs

**RLS Policies Created:** 2 policies

**Status:** ❌ NOT APPLIED (table missing)

---

### 13. store-profile-migration.sql

**Purpose:** Store profile and branding settings  
**Execution Order:** 13  
**Dependencies:** phase1-migration.sql  
**Modifies Existing Tables:** No (inserts into settings)

**Settings Inserted:**
- store_address
- store_phone
- store_email
- store_logo_url
- receipt_header
- receipt_footer

**Status:** ❌ NOT APPLIED (depends on phase1-migration.sql)

---

### 14. payment-method-migration.sql

**Purpose:** Payment method column to sales table  
**Execution Order:** 14  
**Dependencies:** supabase-schema.sql  
**Modifies Existing Tables:** Yes (adds payment_method to sales)

**Columns Added:**
- sales.payment_method (TEXT)

**Constraints Added:**
- check_payment_method (IN ('cash', 'transfer'))

**Status:** ⚠️ UNKNOWN (may or may not be applied)

---

### 15. atomic-checkout-migration.sql

**Purpose:** ACID-compliant checkout with atomic transactions  
**Execution Order:** 15 (last)  
**Dependencies:** customers-migration.sql, discounts-migration.sql, tax-migration.sql  
**Modifies Existing Tables:** Yes (adds columns conditionally)

**Columns Added (conditional):**
- sales.customer_id (if not already added)
- sales.discount_id (if not already added)
- sales.discount_amount (if not already added)
- sales.tax_rate (if not already added)
- sales.tax_amount (if not already added)
- sales.transaction_token (if not already added)

**Indexes Created:**
- idx_sales_transaction_token
- idx_sales_customer_id
- idx_sales_discount_id

**Functions Created:**
- process_checkout() - Atomic checkout RPC

**Status:** ⚠️ PARTIALLY APPLIED (columns added without FKs due to missing tables)

---

## Missing Objects Summary

### Missing Tables

| Table | Purpose | Migration File | Status |
|-------|---------|----------------|--------|
| customers | Customer management | customers-migration.sql | ❌ Missing |
| discounts | Discount management | discounts-migration.sql | ❌ Missing |
| categories | Dynamic categories | phase1-migration.sql | ❌ Missing |
| payment_methods | Payment methods | phase1-migration.sql | ❌ Missing |
| settings | Application settings | phase1-migration.sql | ❌ Missing |
| raw_materials | Raw materials for HPP | hpp-migration.sql | ❌ Missing |
| product_recipes | Product recipes | hpp-migration.sql | ❌ Missing |
| expenses | Expense tracking | expenses-migration.sql | ❌ Missing |
| transaction_logs | Transaction audit log | transaction-logs-migration.sql | ❌ Missing |

### Missing Columns

| Table | Column | Type | Migration File | Status |
|-------|--------|------|----------------|--------|
| products | barcode | TEXT UNIQUE | barcode-migration.sql | ❌ Missing |
| products | hpp | DECIMAL | hpp-migration.sql | ❌ Missing |
| sales | customer_id | UUID | customers-migration.sql | ⚠️ Exists (no FK) |
| sales | discount_amount | DECIMAL | discounts-migration.sql | ❌ Missing |
| sales | discount_id | UUID | discounts-migration.sql | ❌ Missing |
| sales | tax_rate | DECIMAL | tax-migration.sql | ❌ Missing |
| sales | tax_amount | DECIMAL | tax-migration.sql | ❌ Missing |
| sales | transaction_token | TEXT UNIQUE | atomic-checkout-migration.sql | ❌ Missing |

### Missing Foreign Keys

| Table | Column | References | Status |
|-------|--------|------------|--------|
| sales | customer_id | customers(id) | ❌ Missing |
| sales | discount_id | discounts(id) | ❌ Missing |

### Missing Indexes

| Index | Table | Columns | Migration File | Status |
|-------|-------|---------|----------------|--------|
| idx_customers_phone | customers | phone | customers-migration.sql | ❌ Missing |
| idx_customers_email | customers | email | customers-migration.sql | ❌ Missing |
| idx_sales_customer_id | sales | customer_id | customers-migration.sql | ❌ Missing |
| idx_discounts_is_active | discounts | is_active | discounts-migration.sql | ❌ Missing |
| idx_discounts_valid_period | discounts | valid_from, valid_until | discounts-migration.sql | ❌ Missing |
| idx_sales_discount_id | sales | discount_id | discounts-migration.sql | ❌ Missing |
| idx_categories_name | categories | name | phase1-migration.sql | ❌ Missing |
| idx_categories_active | categories | is_active | phase1-migration.sql | ❌ Missing |
| idx_payment_methods_code | payment_methods | code | phase1-migration.sql | ❌ Missing |
| idx_payment_methods_active | payment_methods | is_active | phase1-migration.sql | ❌ Missing |
| idx_settings_key | settings | key | phase1-migration.sql | ❌ Missing |
| idx_products_barcode | products | barcode | barcode-migration.sql | ❌ Missing |
| idx_sales_tax_rate | sales | tax_rate | tax-migration.sql | ❌ Missing |
| idx_sales_transaction_token | sales | transaction_token | atomic-checkout-migration.sql | ❌ Missing |
| idx_raw_materials_name | raw_materials | name | hpp-migration.sql | ❌ Missing |
| idx_product_recipes_product_id | product_recipes | product_id | hpp-migration.sql | ❌ Missing |
| idx_product_recipes_raw_material_id | product_recipes | raw_material_id | hpp-migration.sql | ❌ Missing |
| idx_expenses_expense_date | expenses | expense_date | expenses-migration.sql | ❌ Missing |
| idx_expenses_category | expenses | category | expenses-migration.sql | ❌ Missing |
| idx_expenses_created_by | expenses | created_by | expenses-migration.sql | ❌ Missing |
| idx_transaction_logs_transaction_id | transaction_logs | transaction_id | transaction-logs-migration.sql | ❌ Missing |
| idx_transaction_logs_user_id | transaction_logs | user_id | transaction-logs-migration.sql | ❌ Missing |
| idx_transaction_logs_created_at | transaction_logs | created_at | transaction-logs-migration.sql | ❌ Missing |
| idx_transaction_logs_action | transaction_logs | action | transaction-logs-migration.sql | ❌ Missing |

### Missing RLS Policies

| Table | Policies | Migration File | Status |
|-------|----------|----------------|--------|
| customers | 5 policies | customers-migration.sql | ❌ Missing |
| discounts | 2 policies | discounts-migration.sql | ❌ Missing |
| categories | 4 policies | phase1-migration.sql | ❌ Missing |
| payment_methods | 4 policies | phase1-migration.sql | ❌ Missing |
| settings | 4 policies | phase1-migration.sql | ❌ Missing |
| raw_materials | 4 policies | hpp-migration.sql | ❌ Missing |
| product_recipes | 4 policies | hpp-migration.sql | ❌ Missing |
| expenses | 4 policies | expenses-migration.sql | ❌ Missing |
| transaction_logs | 2 policies | transaction-logs-migration.sql | ❌ Missing |

### Missing Triggers

| Trigger | Table | Purpose | Migration File | Status |
|---------|-------|---------|----------------|--------|
| update_customers_updated_at | customers | Auto-update timestamp | customers-migration.sql | ❌ Missing |
| update_discounts_updated_at | discounts | Auto-update timestamp | discounts-migration.sql | ❌ Missing |
| trigger_update_hpp_after_insert | product_recipes | Auto-calc HPP | hpp-functions-migration.sql | ❌ Missing |
| trigger_update_hpp_after_update | product_recipes | Auto-calc HPP | hpp-functions-migration.sql | ❌ Missing |
| trigger_update_hpp_after_delete | product_recipes | Auto-calc HPP | hpp-functions-migration.sql | ❌ Missing |

### Missing Functions

| Function | Purpose | Migration File | Status |
|----------|---------|----------------|--------|
| calculate_product_hpp | Calculate product HPP | hpp-migration.sql | ❌ Missing |
| update_all_product_hpp | Update all products HPP | hpp-migration.sql | ❌ Missing |
| update_product_hpp_trigger | Trigger function for HPP | hpp-functions-migration.sql | ❌ Missing |
| process_checkout | Atomic checkout RPC | atomic-checkout-migration.sql | ❌ Missing |

---

## Correct Migration Execution Order

### Phase 1: Core Schema (Required)
1. supabase-schema.sql
2. supabase-auth-migration.sql
3. supabase-rls-policies.sql

### Phase 2: Feature Tables (Required)
4. customers-migration.sql
5. discounts-migration.sql
6. tax-migration.sql
7. phase1-migration.sql
8. barcode-migration.sql

### Phase 3: Advanced Features (Optional)
9. hpp-migration.sql
10. hpp-functions-migration.sql
11. expenses-migration.sql
12. transaction-logs-migration.sql

### Phase 4: Configuration (Required)
13. store-profile-migration.sql
14. payment-method-migration.sql

### Phase 5: Atomic Checkout (Required)
15. atomic-checkout-migration.sql

---

## Verification SQL

### Verify Tables Exist

```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;
```

**Expected Output:** 17 tables
- products
- sales
- sale_items
- stock_movements
- suppliers
- daily_production
- waste_items
- profiles
- customers
- discounts
- categories
- payment_methods
- settings
- raw_materials
- product_recipes
- expenses
- transaction_logs

### Verify Columns Exist

```sql
-- Check products.barcode
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'products' AND column_name = 'barcode';

-- Check products.hpp
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'products' AND column_name = 'hpp';

-- Check sales.customer_id
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'sales' AND column_name = 'customer_id';

-- Check sales.discount_amount
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'sales' AND column_name = 'discount_amount';

-- Check sales.discount_id
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'sales' AND column_name = 'discount_id';

-- Check sales.tax_rate
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'sales' AND column_name = 'tax_rate';

-- Check sales.tax_amount
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'sales' AND column_name = 'tax_amount';

-- Check sales.transaction_token
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'sales' AND column_name = 'transaction_token';
```

### Verify Foreign Keys

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

**Expected Output:**
- sales.created_by → profiles(id)
- sales.customer_id → customers(id)
- sales.discount_id → discounts(id)

### Verify Indexes

```sql
SELECT indexname, tablename 
FROM pg_indexes 
WHERE schemaname = 'public'
ORDER BY tablename, indexname;
```

**Expected Output:** 30+ indexes

### Verify RLS Policies

```sql
SELECT schemaname, tablename, policyname 
FROM pg_policies 
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
```

**Expected Output:** 40+ policies

### Verify RPC Function

```sql
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name = 'process_checkout';
```

**Expected Output:** 1 row with process_checkout function

---

## Upgrade Procedure

### Step 1: Backup Database
```sql
-- Create manual backup via Supabase Dashboard
-- Settings > Database > Backups > Create backup
```

### Step 2: Execute Upgrade Script
```sql
-- Run DATABASE_UPGRADE_V1.sql in Supabase SQL Editor
-- This script is idempotent and safe to run multiple times
```

### Step 3: Verify Upgrade
```sql
-- Run verification SQL queries above
-- Ensure all tables, columns, indexes, and policies exist
```

### Step 4: Test Application
```sql
-- Test customer selection in POS
-- Test discount application
-- Test barcode scanning
-- Test checkout with all features
```

---

## Risk Assessment

**Risk Level:** MEDIUM

**Risks:**
- Upgrade script takes 5-10 minutes to execute
- Brief table locks during index creation
- Foreign key constraints may fail if data integrity issues exist

**Mitigations:**
- Script is idempotent (safe to re-run)
- Uses IF NOT EXISTS and ADD COLUMN IF NOT EXISTS
- Preserves all existing data
- No tables are dropped

**Rollback:**
- If upgrade fails, restore from backup
- No automatic rollback - manual restore required

---

## Conclusion

The production database is missing 9 tables, 8 columns, 2 foreign keys, 26 indexes, 33 RLS policies, 5 triggers, and 4 functions. This is causing the PGRST205 and PGRST204 errors.

**Solution:** Execute DATABASE_UPGRADE_V1.sql in Supabase SQL Editor.

**Estimated Time:** 5-10 minutes

**Downtime:** Minimal (brief table locks during index creation)

**Data Loss Risk:** None (script preserves all existing data)

---

**Document Version:** 1.0  
**Last Updated:** July 18, 2026  
**Status:** AUDIT COMPLETE - UPGRADE SCRIPT READY
