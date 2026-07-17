# Database Schema Analysis Report

**Analysis Date:** July 18, 2026  
**Project:** KasirApp  
**Purpose:** Analyze existing migrations and identify conflicts for v1.0 consolidation

---

## Executive Summary

**Total Migration Files:** 17  
**Total Tables:** 15  
**Total Functions:** 8  
**Total RLS Policies:** 50+  
**Critical Conflicts:** 10

The current database schema is fragmented across 17 migration files with significant duplication, conflicts, and the critical RLS recursion vulnerability. A complete consolidation is required for production readiness.

---

## Migration Files Inventory

### Core Schema Files
1. **supabase-schema.sql** (133 lines)
   - Tables: products, sales, sale_items, stock_movements, suppliers, daily_production, waste_items
   - Indexes: 8
   - Triggers: 1 (update_products_updated_at)
   - Sample data: 14 products

2. **supabase-auth-migration.sql** (79 lines)
   - Tables: profiles
   - Functions: handle_new_user(), update_updated_at_column()
   - Triggers: 2 (on_auth_user_created, update_profiles_updated_at)
   - RLS Policies: 3

3. **supabase-rls-policies.sql** (325 lines)
   - RLS Policies: 30 (with recursion risk)
   - Tables: products, sales, sale_items, stock_movements, daily_production, waste_items, suppliers

### Feature Migration Files
4. **phase1-migration.sql** (187 lines)
   - Tables: categories, payment_methods, settings
   - RLS Policies: 12 (with recursion risk)
   - Sample data: 3 categories, 2 payment methods, 2 settings

5. **atomic-checkout-migration.sql** (316 lines)
   - Functions: process_checkout()
   - Columns: customer_id, discount_id, discount_amount, tax_rate, tax_amount, transaction_token
   - Indexes: 3
   - Conditional FKs (problematic)

6. **customers-migration.sql** (116 lines)
   - Tables: customers
   - Functions: update_customers_updated_at()
   - RLS Policies: 5 (with recursion risk)
   - Sample data: 3 customers

7. **discounts-migration.sql** (77 lines)
   - Tables: discounts
   - Functions: update_discounts_updated_at()
   - RLS Policies: 2 (with recursion risk)
   - Sample data: 3 discounts

8. **tax-migration.sql** (21 lines)
   - Columns: tax_rate, tax_amount
   - Settings: 3 tax settings

9. **barcode-migration.sql** (28 lines)
   - Columns: barcode
   - Sample data: 14 barcodes

10. **hpp-migration.sql** (174 lines)
    - Tables: raw_materials, product_recipes
    - Columns: hpp
    - Functions: calculate_product_hpp(), update_all_product_hpp()
    - RLS Policies: 8 (with recursion risk)

11. **hpp-functions-migration.sql** (76 lines)
    - Functions: calculate_product_hpp(), update_all_product_hpp(), update_product_hpp_trigger()
    - Triggers: 3 (HPP auto-update)

12. **expenses-migration.sql** (75 lines)
    - Tables: expenses
    - RLS Policies: 4 (with recursion risk)

13. **transaction-logs-migration.sql** (53 lines)
    - Tables: transaction_logs
    - RLS Policies: 2

14. **payment-method-migration.sql** (23 lines)
    - Columns: payment_method
    - Constraint: check_payment_method (conflicts with dynamic payment_methods)

15. **store-profile-migration.sql** (13 lines)
    - Settings: 6 store profile settings

### Upgrade/Fix Files
16. **DATABASE_UPGRADE_V2.sql** (1025 lines)
    - Comprehensive upgrade script
    - Tables: 15
    - Functions: 8
    - RLS Policies: 50+ (with recursion risk)
    - Sample data: scattered

17. **FIX_PROFILES_RLS_LOGIN.sql** (82 lines)
    - Functions: is_admin()
    - Fixes RLS recursion for profiles table only

---

## Critical Conflicts

### 1. RLS Recursion Risk (CRITICAL)

**Affected Files:**
- supabase-rls-policies.sql (30 policies)
- phase1-migration.sql (12 policies)
- customers-migration.sql (5 policies)
- discounts-migration.sql (2 policies)
- hpp-migration.sql (8 policies)
- expenses-migration.sql (4 policies)
- DATABASE_UPGRADE_V2.sql (50+ policies)

**Issue:** All policies query profiles table directly:
```sql
CREATE POLICY "Admins can view all products"
  ON products FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles  -- RECURSION RISK
      WHERE id = auth.uid() AND role = 'admin'
    )
  );
```

**Impact:** PostgreSQL error 42P17, authentication failure

**Fix Status:** Partially fixed for profiles table only (FIX_PROFILES_RLS_LOGIN.sql)

**Required Fix:** Replace all direct profiles queries with SECURITY DEFINER functions (is_admin(), is_kasir())

---

### 2. Duplicate Function Definitions

**update_updated_at_column():**
- supabase-schema.sql (line 100)
- supabase-auth-migration.sql (line 60)
- customers-migration.sql (line 31)
- discounts-migration.sql (line 31)
- DATABASE_UPGRADE_V2.sql (line 247)

**calculate_product_hpp():**
- hpp-migration.sql (line 120)
- hpp-functions-migration.sql (line 5)
- DATABASE_UPGRADE_V2.sql (line 295)

**update_all_product_hpp():**
- hpp-migration.sql (line 136)
- hpp-functions-migration.sql (line 21)
- DATABASE_UPGRADE_V2.sql (line 311)

**handle_new_user():**
- supabase-auth-migration.sql (line 39)
- DATABASE_UPGRADE_V2.sql (line 350)

**Impact:** Conflicts during migration execution, unpredictable behavior

---

### 3. Duplicate Policy Definitions

**Same policies defined in multiple files:**
- "Admins can view all profiles" - supabase-auth-migration.sql, DATABASE_UPGRADE_V2.sql
- "Admins can manage customers" - customers-migration.sql, DATABASE_UPGRADE_V2.sql
- "Admins can manage discounts" - discounts-migration.sql, DATABASE_UPGRADE_V2.sql
- "Users can view categories" - phase1-migration.sql, DATABASE_UPGRADE_V2.sql
- "Users can view payment methods" - phase1-migration.sql, DATABASE_UPGRADE_V2.sql
- "Users can view settings" - phase1-migration.sql, DATABASE_UPGRADE_V2.sql
- And many more...

**Impact:** Migration conflicts, policy duplication

---

### 4. Conditional Foreign Keys (HIGH)

**File:** atomic-checkout-migration.sql (lines 10-17, 21-28)

**Issue:**
```sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'customers') THEN
    ALTER TABLE sales ADD COLUMN IF NOT EXISTS customer_id UUID REFERENCES customers(id) ON DELETE SET NULL;
  ELSE
    ALTER TABLE sales ADD COLUMN IF NOT EXISTS customer_id UUID;  -- NO FK!
  END IF;
END $$;
```

**Impact:** Orphaned records possible, data integrity risk

---

### 5. Payment Method Constraint Conflict

**File:** payment-method-migration.sql (lines 9-11)

**Issue:**
```sql
ALTER TABLE sales 
ADD CONSTRAINT check_payment_method 
CHECK (payment_method IN ('cash', 'transfer'));
```

**Conflict:** phase1-migration.sql creates dynamic payment_methods table, making this constraint obsolete

**Impact:** Cannot add new payment methods dynamically

---

### 6. Missing is_active Column

**File:** add-product-soft-delete.sql (not reviewed, referenced in audit)

**Issue:** products table lacks is_active column for soft delete

**Impact:** Cannot implement soft delete without migration

---

### 7. Inconsistent Column Additions

**Multiple files add columns with IF NOT EXISTS:**
- atomic-checkout-migration.sql: customer_id, discount_id, discount_amount, tax_rate, tax_amount, transaction_token
- tax-migration.sql: tax_rate, tax_amount
- barcode-migration.sql: barcode
- hpp-migration.sql: hpp

**Impact:** Unpredictable column order, potential conflicts

---

### 8. Sample Data Scattered

**Sample data in multiple files:**
- supabase-schema.sql: 14 products
- customers-migration.sql: 3 customers
- discounts-migration.sql: 3 discounts
- barcode-migration.sql: 14 barcodes
- DATABASE_UPGRADE_V2.sql: categories, payment methods, settings, customers, discounts, barcodes

**Impact:** Duplicate data, inconsistent state, difficult to manage

---

### 9. Trigger Conflicts

**Multiple files create/drop triggers:**
- update_products_updated_at - supabase-schema.sql
- update_profiles_updated_at - supabase-auth-migration.sql, DATABASE_UPGRADE_V2.sql
- update_customers_updated_at - customers-migration.sql, DATABASE_UPGRADE_V2.sql
- update_discounts_updated_at - discounts-migration.sql, DATABASE_UPGRADE_V2.sql
- HPP triggers - hpp-functions-migration.sql, DATABASE_UPGRADE_V2.sql

**Impact:** Trigger recreation, potential data loss

---

### 10. No Migration Version Tracking

**Issue:** No schema_migrations table to track applied migrations

**Impact:** Cannot determine migration state, risk of re-running migrations

---

## Complete Table Inventory

### Authentication Tables
1. **profiles** - User profiles linked to auth.users
   - Columns: id, email, name, role, created_at, updated_at
   - RLS: Yes (with recursion risk)
   - Triggers: handle_new_user(), update_profiles_updated_at

### Business Tables
2. **products** - Product catalog
   - Columns: id, name, category, price, cost, stock, image_url, hpp, barcode, created_at, updated_at
   - RLS: Yes (with recursion risk)
   - Triggers: update_products_updated_at
   - Indexes: category, barcode

3. **sales** - Sales transactions
   - Columns: id, total_amount, total_cost, profit, payment_method, customer_id, discount_id, discount_amount, tax_rate, tax_amount, transaction_token, created_at, created_by
   - RLS: Yes (with recursion risk)
   - Indexes: created_at, customer_id, discount_id, transaction_token, tax_rate

4. **sale_items** - Sale line items
   - Columns: id, sale_id, product_id, quantity, price, cost, subtotal, created_at
   - RLS: Yes (with recursion risk)
   - Indexes: sale_id, product_id

5. **stock_movements** - Stock changes
   - Columns: id, product_id, type, quantity, reference_id, notes, created_at, created_by
   - RLS: Yes (with recursion risk)
   - Indexes: product_id, type

6. **suppliers** - Supplier information
   - Columns: id, name, contact, address, created_at
   - RLS: Yes (with recursion risk)

7. **daily_production** - Production tracking
   - Columns: id, product_id, date, quantity_produced, quantity_sold, quantity_waste, quantity_remaining, created_at, created_by
   - RLS: Yes (with recursion risk)
   - Indexes: date, product_id

8. **waste_items** - Waste tracking
   - Columns: id, product_id, quantity, reason, created_at, created_by
   - RLS: Yes (with recursion risk)

### Customer Management Tables
9. **customers** - Customer information
   - Columns: id, name, phone, email, address, balance, points, notes, is_active, created_at, updated_at
   - RLS: Yes (with recursion risk)
   - Triggers: update_customers_updated_at
   - Indexes: phone, email

### Discount Tables
10. **discounts** - Discount management
    - Columns: id, name, type, value, min_purchase, max_discount, is_active, valid_from, valid_until, created_at, updated_at
    - RLS: Yes (with recursion risk)
    - Triggers: update_discounts_updated_at
    - Indexes: is_active, valid_period

### Configuration Tables
11. **categories** - Product categories
    - Columns: id, name, icon, color, is_active, sort_order, created_at
    - RLS: Yes (with recursion risk)
    - Indexes: name, is_active

12. **payment_methods** - Payment methods
    - Columns: id, name, code, is_active, sort_order, created_at
    - RLS: Yes (with recursion risk)
    - Indexes: code, is_active

13. **settings** - Application settings
    - Columns: id, key, value, description, updated_at
    - RLS: Yes (with recursion risk)
    - Indexes: key

### Production Tables
14. **raw_materials** - Raw material inventory
    - Columns: id, name, unit, cost_per_unit, stock, created_at
    - RLS: Yes (with recursion risk)
    - Indexes: name

15. **product_recipes** - Product recipes
    - Columns: id, product_id, raw_material_id, quantity_used, created_at
    - RLS: Yes (with recursion risk)
    - Indexes: product_id, raw_material_id
    - Triggers: HPP auto-update triggers

### Expense Tables
16. **expenses** - Business expenses
    - Columns: id, expense_date, category, description, amount, created_by, created_at
    - RLS: Yes (with recursion risk)
    - Indexes: expense_date, category, created_by

### Audit Tables
17. **transaction_logs** - Transaction modification logs
    - Columns: id, transaction_id, action, reason, old_data, new_data, user_id, created_at
    - RLS: Yes (with recursion risk)
    - Indexes: transaction_id, user_id, created_at, action

---

## Complete Function Inventory

### Utility Functions
1. **update_updated_at_column()** - Update updated_at timestamp (DUPLICATE)
2. **update_customers_updated_at()** - Update customers updated_at (DUPLICATE)
3. **update_discounts_updated_at()** - Update discounts updated_at (DUPLICATE)

### Auth Functions
4. **handle_new_user()** - Create profile on user signup (DUPLICATE)

### Role Check Functions (MISSING - CRITICAL)
5. **is_admin()** - Check if user is admin (PARTIALLY IMPLEMENTED)
6. **is_kasir()** - Check if user is cashier (MISSING)

### HPP Functions
7. **calculate_product_hpp()** - Calculate product HPP (DUPLICATE)
8. **update_all_product_hpp()** - Update all product HPP (DUPLICATE)
9. **update_product_hpp_trigger()** - Trigger function for HPP updates

### Business Functions
10. **process_checkout()** - Atomic checkout function

---

## Complete Index Inventory

### Products Indexes
- idx_products_category
- idx_products_barcode
- idx_products_active (missing)

### Sales Indexes
- idx_sales_created_at
- idx_sales_customer_id
- idx_sales_discount_id
- idx_sales_transaction_token
- idx_sales_tax_rate
- idx_sales_created_by_date (missing)
- idx_sales_customer_date (missing)

### Sale Items Indexes
- idx_sale_items_sale_id
- idx_sale_items_product_id
- idx_sale_items_product_date (missing)

### Stock Movements Indexes
- idx_stock_movements_product_id
- idx_stock_movements_type
- idx_stock_movements_type_date (missing)

### Customers Indexes
- idx_customers_phone
- idx_customers_email

### Discounts Indexes
- idx_discounts_is_active
- idx_discounts_valid_period

### Categories Indexes
- idx_categories_name
- idx_categories_active

### Payment Methods Indexes
- idx_payment_methods_code
- idx_payment_methods_active

### Settings Indexes
- idx_settings_key

### Raw Materials Indexes
- idx_raw_materials_name

### Product Recipes Indexes
- idx_product_recipes_product_id
- idx_product_recipes_raw_material_id

### Expenses Indexes
- idx_expenses_expense_date
- idx_expenses_category
- idx_expenses_created_by

### Transaction Logs Indexes
- idx_transaction_logs_transaction_id
- idx_transaction_logs_user_id
- idx_transaction_logs_created_at
- idx_transaction_logs_action

---

## Missing Composite Indexes

### Recommended Composite Indexes
1. idx_sales_created_by_date ON sales(created_at, created_by)
2. idx_sale.items_product_date ON sale_items(product_id, created_at)
3. idx_expenses_date_category ON expenses(expense_date, category)
4. idx_products_active_date ON products(is_active, created_at)
5. idx_sales_customer_date ON sales(customer_id, created_at)
6. idx_stock_movements_type_date ON stock_movements(type, created_at)

---

## Data Validation Constraints

### Existing Constraints
- products.category CHECK (bakery, cemilan, minuman) - REMOVED in phase1
- raw_materials.unit CHECK (kg, gram, liter, ml, pcs) - REMOVED in phase1
- sales.payment_method CHECK (cash, transfer) - CONFLICTS with dynamic payment_methods
- profiles.role CHECK (admin, kasir)
- discounts.type CHECK (percentage, fixed)
- expenses.category CHECK (Electricity, Water, Salary, Rent, Raw Materials, Transportation, Marketing, Other)
- transaction_logs.action CHECK (void, delete, edit)

### Missing Constraints
- products.price > 0
- products.cost >= 0
- products.stock >= 0
- sales.total_amount > 0
- sale_items.quantity > 0
- expenses.amount > 0

---

## Sample Data Inventory

### Products (14 items)
- Bakery: Roti Coklat, Roti Keju, Croissant, Donat Coklat, Roti Tawar
- Cemilan: Keripik Singkong, Keripik Pisang, Pisang Goreng, Kentang Goreng
- Minuman: Es Teh Manis, Es Jeruk, Kopi Susu, Jus Alpukat, Es Campur

### Customers (3 items)
- Budi Santoso
- Siti Rahayu
- Ahmad Wijaya

### Discounts (3 items)
- Diskon Member 10%
- Diskon Member 20%
- Diskon Tetap 5000

### Categories (3 items)
- bakery (Cake, orange-red gradient)
- cemilan (Cookie, yellow-orange gradient)
- minuman (Coffee, blue-indigo gradient)

### Payment Methods (2 items)
- Tunai (Cash)
- Transfer

### Settings (11 items)
- low_stock_threshold: 10
- store_name: KasirApp
- store_address: (empty)
- store_phone: (empty)
- store_email: (empty)
- store_logo_url: (empty)
- receipt_header: TERIMA KASIH
- receipt_footer: Barang yang sudah dibeli tidak dapat ditukar/dikembalikan
- tax_enabled: false
- tax_rate: 11
- tax_name: PPN

---

## Consolidation Strategy

### Phase 1: Design Clean Schema
1. Define all tables with complete columns
2. Add missing columns (is_active to products)
3. Remove conflicting constraints
4. Add missing validation constraints
5. Add missing composite indexes

### Phase 2: Fix RLS Recursion
1. Create SECURITY DEFINER functions (is_admin, is_kasir)
2. Replace all direct profiles queries with function calls
3. Apply to all tables with RLS

### Phase 3: Consolidate Functions
1. Remove duplicate function definitions
2. Keep single version of each function
3. Ensure all functions use SECURITY DEFINER where needed

### Phase 4: Consolidate Triggers
1. Remove duplicate trigger definitions
2. Keep single version of each trigger
3. Ensure proper trigger execution order

### Phase 5: Consolidate Sample Data
1. Remove duplicate sample data
2. Keep single version in separate file
3. Add flag to include/exclude sample data

### Phase 6: Add Migration Tracking
1. Create schema_migrations table
2. Add version tracking
3. Add checksum validation

---

## Next Steps

1. **Design DATABASE_V1.0_PRODUCTION.sql** - Complete clean schema
2. **Create migration roadmap** - Zero data loss migration plan
3. **Generate validation script** - Verify migration success

---

**Analysis Completed:** July 18, 2026  
**Next Action:** Design consolidated v1.0 production schema
