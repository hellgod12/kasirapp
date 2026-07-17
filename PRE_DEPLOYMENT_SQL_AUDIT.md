# KasirApp Database Upgrade - Pre-Deployment SQL Audit

**Script:** DATABASE_UPGRADE_V1.sql  
**Audit Date:** July 18, 2026  
**Auditor:** Cascade AI  
**Purpose:** Verify script safety before production execution

---

## Executive Summary

**VERDICT:** SAFE TO EXECUTE

The DATABASE_UPGRADE_V1.sql script is **fully idempotent** and safe to run multiple times. It uses appropriate safe checks throughout, preserves all existing data, and contains no destructive operations.

**Safety Score:** 9.5/10 (Minor issue with GRANT EXECUTE not idempotent)

---

## Idempotency Verification

### Section 1: Enable Extensions
**Line 13:** `CREATE EXTENSION IF NOT EXISTS "uuid-ossp";`
- ✅ SAFE - Uses IF NOT EXISTS
- ✅ IDEMPOTENT - Safe to run multiple times

### Section 2: Create Missing Tables
**Lines 20-130:** All table creation statements
- ✅ SAFE - All use `CREATE TABLE IF NOT EXISTS`
- ✅ IDEMPOTENT - Tables only created if they don't exist
- ✅ NO DROP TABLE statements
- ✅ NO TRUNCATE statements
- ✅ NO DELETE statements

**Tables Created:**
- profiles (line 20)
- customers (line 30)
- discounts (line 45)
- categories (line 60)
- payment_methods (line 71)
- settings (line 81)
- raw_materials (line 90)
- product_recipes (line 100)
- expenses (line 110)
- transaction_logs (line 121)

### Section 3: Add Missing Columns
**Lines 137-148:** All ALTER TABLE statements
- ✅ SAFE - All use `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`
- ✅ PRESERVES DATA - Only adds new columns, doesn't modify existing data
- ✅ IDEMPOTENT - Columns only added if they don't exist

**Columns Added:**
- products.hpp (line 138)
- products.barcode (line 139)
- sales.customer_id (line 143)
- sales.discount_amount (line 144)
- sales.discount_id (line 145)
- sales.tax_rate (line 146)
- sales.tax_amount (line 147)
- sales.transaction_token (line 148)

### Section 4: Add Foreign Key Constraints
**Lines 155-180:** Foreign key additions
- ✅ SAFE - Uses DO block with IF NOT EXISTS check on information_schema
- ✅ IDEMPOTENT - Constraints only added if they don't exist
- ✅ CORRECT ORDER - Foreign keys added after tables created in Section 2

**Foreign Keys Added:**
- sales.customer_id → customers(id) (lines 155-166)
- sales.discount_id → discounts(id) (lines 169-180)

**Verification:**
- Checks `information_schema.table_constraints` before adding
- Only adds if constraint doesn't exist
- Referenced tables (customers, discounts) created in Section 2

### Section 5: Remove Check Constraints
**Lines 186-187:** Constraint removal
- ✅ SAFE - Uses `DROP CONSTRAINT IF EXISTS`
- ✅ IDEMPOTENT - Only drops if constraint exists
- ✅ NECESSARY - Required for dynamic categories feature

**Constraints Removed:**
- products_category_check (line 186)
- raw_materials_unit_check (line 187)

### Section 6: Create Indexes
**Lines 194-238:** All index creation statements
- ✅ SAFE - All use `CREATE INDEX IF NOT EXISTS`
- ✅ IDEMPOTENT - Indexes only created if they don't exist
- ✅ NO DROP INDEX statements
- ✅ NO RECREATE statements

**Indexes Created:** 26 indexes across all tables

### Section 7: Create Triggers and Functions
**Lines 245-367:** Functions and triggers
- ✅ SAFE - All functions use `CREATE OR REPLACE FUNCTION`
- ✅ SAFE - All triggers use `DROP TRIGGER IF EXISTS` before CREATE
- ✅ IDEMPOTENT - Functions replaced if they exist
- ✅ NO DUPLICATE TRIGGERS - Old triggers dropped before creating new ones

**Functions Created (CREATE OR REPLACE):**
- update_updated_at_column (line 245)
- update_customers_updated_at (line 261)
- update_discounts_updated_at (line 277)
- calculate_product_hpp (line 293)
- update_all_product_hpp (line 309)
- update_product_hpp_trigger (line 318)
- handle_new_user (line 348)

**Triggers Created:**
- update_profiles_updated_at (lines 254-258)
- update_customers_updated_at (lines 270-274)
- update_discounts_updated_at (lines 286-290)
- trigger_update_hpp_after_insert (lines 335-337)
- trigger_update_hpp_after_update (lines 339-341)
- trigger_update_hpp_after_delete (lines 343-345)
- on_auth_user_created (lines 363-367)

### Section 8: Enable Row Level Security
**Lines 374-383:** RLS enablement
- ✅ SAFE - `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` is idempotent
- ✅ IDEMPOTENT - Enabling RLS twice is safe (no error)
- ✅ NO DISABLE statements

**Tables with RLS Enabled:**
- profiles, customers, discounts, categories, payment_methods, settings, raw_materials, product_recipes, expenses, transaction_logs

### Section 9: Create RLS Policies
**Lines 390-752:** All policy creation statements
- ✅ SAFE - All use `DROP POLICY IF EXISTS` before CREATE
- ✅ IDEMPOTENT - Policies replaced if they exist
- ✅ NO DUPLICATE POLICIES - Old policies dropped before creating new ones

**Policies Created:** 33 policies across 9 tables

### Section 10: Insert Default Data
**Lines 759-814:** Data insertion
- ✅ SAFE - All INSERT statements use `ON CONFLICT DO NOTHING`
- ✅ SAFE - UPDATE statements use `WHERE ... IS NULL` condition
- ✅ PRESERVES DATA - Only inserts if data doesn't exist
- ✅ NO DELETE statements
- ✅ NO TRUNCATE statements

**Data Inserted:**
- Categories (lines 759-763)
- Payment methods (lines 766-769)
- Settings (lines 772-784)
- Customers (lines 787-791)
- Discounts (lines 794-798)
- Product barcodes (lines 801-814)

### Section 11: Create Atomic Checkout RPC Function
**Lines 820-1003:** RPC function
- ✅ SAFE - Uses `CREATE OR REPLACE FUNCTION`
- ✅ IDEMPOTENT - Function replaced if it exists
- ✅ NO DROP FUNCTION statements

**Function:** process_checkout (atomic checkout with ACID compliance)

### Section 12: Grant Execute Permission
**Line 1006:** `GRANT EXECUTE ON FUNCTION process_checkout TO authenticated;`
- ⚠️ MINOR ISSUE - Not idempotent (will succeed if already granted, but not checked)
- ✅ SAFE - Granting execute permission multiple times is harmless
- ✅ NO RISK - PostgreSQL allows duplicate GRANT statements without error

**Recommendation:** This is safe as-is. PostgreSQL ignores duplicate GRANT statements.

---

## Destructive Operations Verification

### DROP Operations
- ✅ NO DROP TABLE statements
- ✅ NO DROP COLUMN statements
- ✅ NO DROP DATABASE statements
- ✅ NO DROP SCHEMA statements

**DROP Statements Present (All Safe):**
- `DROP CONSTRAINT IF EXISTS` (lines 186-187) - Safe, necessary for upgrade
- `DROP TRIGGER IF EXISTS` (lines 254, 270, 286, 331-333, 363) - Safe, prevents duplicate triggers
- `DROP POLICY IF EXISTS` (lines 390-752) - Safe, prevents duplicate policies

### DELETE Operations
- ✅ NO DELETE FROM statements
- ✅ NO TRUNCATE statements
- ✅ NO data deletion

### TRUNCATE Operations
- ✅ NO TRUNCATE TABLE statements

### Recreate Operations
- ✅ NO CREATE OR REPLACE TABLE statements
- ✅ Tables only created with IF NOT EXISTS

---

## Data Preservation Verification

### ALTER TABLE Statements
**Lines 137-148:** All column additions
- ✅ PRESERVES DATA - Uses ADD COLUMN IF NOT EXISTS
- ✅ DEFAULT VALUES - New columns have DEFAULT values
- ✅ NULLABLE - New columns are nullable where appropriate
- ✅ NO DATA LOSS - Existing rows get default values for new columns

### UPDATE Statements
**Lines 801-814:** Product barcode updates
- ✅ PRESERVES DATA - Uses `WHERE ... IS NULL` condition
- ✅ SAFE - Only updates rows where barcode is NULL
- ✅ NO OVERWRITE - Doesn't overwrite existing barcodes

---

## Foreign Key Ordering Verification

### Table Creation Order (Section 2)
1. profiles (line 20) - No dependencies
2. customers (line 30) - No dependencies
3. discounts (line 45) - No dependencies
4. categories (line 60) - No dependencies
5. payment_methods (line 71) - No dependencies
6. settings (line 81) - No dependencies
7. raw_materials (line 90) - No dependencies
8. product_recipes (line 100) - Depends on products, raw_materials ✅
9. expenses (line 110) - Depends on profiles ✅
10. transaction_logs (line 121) - Depends on sales ✅

**Verification:**
- ✅ products referenced by product_recipes - products exists from supabase-schema.sql
- ✅ raw_materials referenced by product_recipes - created in same section (line 90)
- ✅ profiles referenced by expenses - created in same section (line 20)
- ✅ sales referenced by transaction_logs - exists from supabase-schema.sql

### Foreign Key Addition Order (Section 4)
**Lines 155-180:** Foreign keys added after table creation
- ✅ customers table created in Section 2 (line 30)
- ✅ discounts table created in Section 2 (line 45)
- ✅ Foreign keys added only after tables exist
- ✅ Uses IF NOT EXISTS check on information_schema

**Conclusion:** Foreign key ordering is correct and safe.

---

## Index Creation Safety Verification

**Lines 194-238:** All index statements
- ✅ SAFE - All use `CREATE INDEX IF NOT EXISTS`
- ✅ IDEMPOTENT - Indexes only created if they don't exist
- ✅ NO DROP INDEX statements
- ✅ NO RECREATE statements
- ✅ Brief lock time - Acceptable for production

**Index Count:** 26 indexes

---

## Trigger Safety Verification

**Lines 254, 270, 286, 331-333, 363:** Trigger creation
- ✅ SAFE - All use `DROP TRIGGER IF EXISTS` before CREATE
- ✅ IDEMPOTENT - Old triggers dropped before creating new ones
- ✅ NO DUPLICATE TRIGGERS
- ✅ NO RECREATE without DROP

**Trigger Count:** 7 triggers

---

## Function Safety Verification

**Lines 245, 261, 277, 293, 309, 318, 348, 820:** Function creation
- ✅ SAFE - All use `CREATE OR REPLACE FUNCTION`
- ✅ IDEMPOTENT - Functions replaced if they exist
- ✅ NO DROP FUNCTION statements
- ✅ NO RECREATE without REPLACE

**Function Count:** 8 functions

---

## RLS Policy Safety Verification

**Lines 390-752:** Policy creation
- ✅ SAFE - All use `DROP POLICY IF EXISTS` before CREATE
- ✅ IDEMPOTENT - Old policies dropped before creating new ones
- ✅ NO DUPLICATE POLICIES
- ✅ NO RECREATE without DROP

**Policy Count:** 33 policies

---

## Safe Checks Summary

| Check Type | Count | Status |
|------------|-------|--------|
| CREATE TABLE IF NOT EXISTS | 10 | ✅ SAFE |
| ALTER TABLE ADD COLUMN IF NOT EXISTS | 8 | ✅ SAFE |
| CREATE INDEX IF NOT EXISTS | 26 | ✅ SAFE |
| DROP CONSTRAINT IF EXISTS | 2 | ✅ SAFE |
| DROP TRIGGER IF EXISTS | 7 | ✅ SAFE |
| DROP POLICY IF EXISTS | 33 | ✅ SAFE |
| CREATE OR REPLACE FUNCTION | 8 | ✅ SAFE |
| ON CONFLICT DO NOTHING | 5 | ✅ SAFE |
| DO $$ IF NOT EXISTS $$ | 2 | ✅ SAFE |
| GRANT EXECUTE | 1 | ⚠️ NOT IDEMPOTENT (but safe) |

**Total Safe Checks:** 100+ statements with safe guards

---

## Potential Issues

### Issue 1: GRANT EXECUTE Not Idempotent
**Line 1006:** `GRANT EXECUTE ON FUNCTION process_checkout TO authenticated;`

**Severity:** MINOR  
**Risk:** None - PostgreSQL allows duplicate GRANT statements  
**Impact:** Script will succeed even if permission already granted  
**Mitigation:** Not required - PostgreSQL handles this gracefully

**Recommendation:** Accept as-is. No action needed.

---

## Data Loss Risk Assessment

**Risk Level:** NONE

**Reasons:**
- No DROP TABLE statements
- No DROP COLUMN statements
- No DELETE statements
- No TRUNCATE statements
- All ALTER TABLE use ADD COLUMN IF NOT EXISTS
- All INSERT use ON CONFLICT DO NOTHING
- All UPDATE use WHERE conditions to preserve existing data
- All CREATE use IF NOT EXISTS

**Conclusion:** Zero risk of data loss.

---

## Performance Impact Assessment

**Estimated Execution Time:** 5-10 minutes

**Performance Considerations:**
- Table creation: Fast (tables are small)
- Index creation: Brief lock time (acceptable)
- Foreign key addition: Brief lock time (acceptable)
- Data insertion: Fast (small sample data)
- RLS policy creation: Fast

**Downtime:** Minimal (brief table locks during index creation)

**Recommendation:** Execute during low-traffic period.

---

## Rollback Strategy

**If Upgrade Fails:**
1. Restore from manual backup created before execution
2. No automatic rollback required
3. Script is idempotent - can be re-run if partial failure

**Backup Required:**
- Create manual backup via Supabase Dashboard before execution
- Settings > Database > Backups > Create backup

---

## Verification Steps

### Pre-Execution
1. Create manual database backup
2. Verify backup completed successfully
3. Note current database size for comparison

### Post-Execution
1. Run verification queries from DATABASE_SCHEMA_AUDIT.md
2. Verify all tables exist (17 tables)
3. Verify all columns exist (8 new columns)
4. Verify all indexes exist (26 indexes)
5. Verify all RLS policies exist (33 policies)
6. Verify all functions exist (8 functions)
7. Verify all triggers exist (7 triggers)
8. Test application functionality

---

## Final Safety Checklist

- ✅ Script is fully idempotent
- ✅ No DROP TABLE statements
- ✅ No DROP COLUMN statements
- ✅ No DELETE statements
- ✅ No TRUNCATE statements
- ✅ All CREATE use IF NOT EXISTS
- ✅ All ALTER TABLE use ADD COLUMN IF NOT EXISTS
- ✅ All CREATE INDEX use IF NOT EXISTS
- ✅ All DROP use IF EXISTS
- ✅ All functions use CREATE OR REPLACE
- ✅ All triggers dropped before creation
- ✅ All policies dropped before creation
- ✅ Foreign keys added after tables created
- ✅ Data preservation guaranteed
- ✅ Zero data loss risk
- ✅ Safe to run multiple times

---

## Final Verdict

**SAFE TO EXECUTE**

The DATABASE_UPGRADE_V1.sql script is safe for production execution. It is fully idempotent, preserves all existing data, and contains no destructive operations. The script uses appropriate safe checks throughout and can be run multiple times without adverse effects.

**Minor Issue:** GRANT EXECUTE statement is not idempotent, but this is not a risk as PostgreSQL handles duplicate GRANT statements gracefully.

**Recommendation:** Execute the script in Supabase SQL Editor after creating a manual backup.

---

**Audit Completed:** July 18, 2026  
**Auditor:** Cascade AI  
**Safety Score:** 9.5/10  
**Status:** APPROVED FOR EXECUTION
