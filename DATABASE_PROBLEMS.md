# Database Problems Report

**Report Date:** July 18, 2026  
**Project:** KasirApp  
**Severity:** HIGH  
**Status:** BLOCKING DEPLOYMENT

---

## Executive Summary

**Total Database Issues:** 12  
**Critical Issues:** 4  
**High Priority Issues:** 5  
**Medium Priority Issues:** 3

The database layer has significant structural problems that prevent reliable deployment and maintenance. The most critical issue is migration fragmentation, which makes it impossible to guarantee consistent database state across environments.

---

## PROBLEM #1: Migration Fragmentation

**Severity:** CRITICAL  
**Category:** Migration Management  
**Status:** UNFIXED

### Description
The database schema is spread across 25 separate SQL migration files with no documented execution order, version tracking, or rollback procedures.

### Impact
- Cannot reliably deploy to production
- Risk of schema drift between environments
- Impossible to rollback migrations
- No version tracking for database changes
- Cannot determine which migrations have been applied
- Risk of data loss during deployment

### Files Affected
All 25 SQL migration files in root directory:
1. supabase-schema.sql
2. supabase-auth-migration.sql
3. supabase-rls-policies.sql
4. phase1-migration.sql
5. customers-migration.sql
6. discounts-migration.sql
7. tax-migration.sql
8. barcode-migration.sql
9. hpp-migration.sql
10. hpp-functions-migration.sql
11. expenses-migration.sql
12. transaction-logs-migration.sql
13. payment-method-migration.sql
14. store-profile-migration.sql
15. atomic-checkout-migration.sql
16. DATABASE_UPGRADE_V1.sql
17. DATABASE_UPGRADE_V2.sql
18. FIX_PROFILES_RLS_LOGIN.sql
19. FIX_PROFILES_RLS_RECURSION.sql
20. fix-profiles-rls-recursion.sql
21. fix-user-deletion.sql
22. add-product-soft-delete.sql
23. create-admin-account.sql
24. clear-sample-data.sql
25. inspect-dependencies.sql

### Root Cause
No migration management system. Each migration was created as a standalone SQL file without considering overall migration strategy.

### Evidence
```bash
# List of all SQL files
ls *.sql
# Returns 25 files with no execution order
```

### Fix Required
1. Create schema_migrations table:
```sql
CREATE TABLE schema_migrations (
  version TEXT PRIMARY KEY,
  applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  checksum TEXT,
  description TEXT
);
```

2. Consolidate all migrations into single DATABASE_UPGRADE_V3.sql
3. Add version numbers to each migration block
4. Add rollback procedures for each migration
5. Document execution order
6. Test on fresh database
7. Create migration runner script

### Estimated Effort
3-4 days

---

## PROBLEM #2: RLS Recursion Risk

**Severity:** CRITICAL  
**Category:** Security  
**Status:** PARTIALLY FIXED

### Description
Multiple RLS policies query the profiles table directly to check user roles. This creates infinite recursion when RLS is enabled on the profiles table itself, causing PostgreSQL error 42P17.

### Impact
- PostgreSQL error 42P17 (infinite recursion detected)
- Authentication may fail
- Potential security bypass
- Users cannot login
- Application becomes unusable

### Files Affected
- supabase-rls-policies.sql (lines 19-53, 69-106, 114-137, 157-200, 207-236, 241-265, 271-309)
- DATABASE_UPGRADE_V2.sql (lines 402-410)
- phase1-migration.sql (lines 66-95, 97-127, 129-159)
- customers-migration.sql (lines 56-115)
- hpp-migration.sql (lines 32-71, 73-112)
- expenses-migration.sql (lines 18-57)

### Root Cause
RLS policies use direct subqueries to profiles table instead of SECURITY DEFINER functions.

### Evidence
```sql
-- Example of problematic policy
CREATE POLICY "Admins can view all products"
  ON products FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles  -- Direct query causes recursion
      WHERE id = auth.uid() AND role = 'admin'
    )
  );
```

### Current Fix Status
- FIX_PROFILES_RLS_LOGIN.sql created to fix profiles table
- Fix applied to profiles table only
- Other tables still vulnerable

### Fix Required
1. Create SECURITY DEFINER functions:
```sql
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE sql
_AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$;

CREATE OR REPLACE FUNCTION is_kasir()
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE sql
AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'kasir'
  );
$$;
```

2. Replace all direct profiles queries with function calls
3. Apply to all tables: products, sales, sale_items, stock_movements, daily_production, waste_items, suppliers, raw_materials, product_recipes, expenses, customers, categories, payment_methods, settings
4. Grant execute permissions to authenticated users

### Estimated Effort
2-3 days

---

## PROBLEM #3: Missing Foreign Key Constraints

**Severity:** HIGH  
**Category:** Data Integrity  
**Status:** UNFIXED

### Description
Some foreign keys are added conditionally without proper validation, leading to inconsistent data integrity across environments.

### Impact
- Orphaned records possible
- Data inconsistency
- Referential integrity not enforced
- Potential data corruption

### Files Affected
- atomic-checkout-migration.sql (lines 12-16)
- customers-migration.sql (line 23)

### Root Cause
Conditional foreign key creation without proper validation.

### Evidence
```sql
-- atomic-checkout-migration.sql
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'customers') THEN
    ALTER TABLE sales ADD COLUMN IF NOT EXISTS customer_id UUID REFERENCES customers(id) ON DELETE SET NULL;
  ELSE
    ALTER TABLE sales ADD COLUMN IF NOT EXISTS customer_id UUID;  -- No FK!
  END IF;
END $$;
```

### Fix Required
1. Ensure all tables exist before adding foreign keys
2. Remove conditional logic
3. Add proper foreign key constraints
4. Add ON DELETE CASCADE/SET NULL appropriately
5. Test referential integrity

### Estimated Effort
1 day

---

## PROBLEM #4: Duplicate Policy Definitions

**Severity:** MEDIUM  
**Category:** Migration Management  
**Status:** UNFIXED

### Description
Same RLS policies are defined in multiple migration files, creating potential conflicts during migration execution.

### Impact
- Migration conflicts
- Policy duplication
- Unpredictable behavior
- Migration failures

### Files Affected
- supabase-rls-policies.sql
- DATABASE_UPGRADE_V2.sql
- phase1-migration.sql

### Root Cause
No coordination between migration files. Policies redefined without checking for existence.

### Evidence
```sql
-- supabase-rls-policies.sql
CREATE POLICY "Admins can view all products" ON products...

-- DATABASE_UPGRADE_V2.sql
CREATE POLICY "Admins can view all products" ON products...
```

### Fix Required
1. Remove duplicate policy definitions
2. Use CREATE POLICY IF NOT EXISTS
3. Consolidate all policies into single migration
4. Document policy ownership

### Estimated Effort
0.5 day

---

## PROBLEM #5: Missing Composite Indexes

**Severity:** MEDIUM  
**Category:** Performance  
**Status:** UNFIXED

### Description
No composite indexes for common query patterns, leading to suboptimal query performance.

### Impact
- Slow query performance
- Increased database load
- Poor user experience
- Scalability issues

### Files Affected
All migration files (missing indexes)

### Root Cause
Indexes not planned based on query patterns.

### Missing Indexes
1. (created_at, created_by) on sales
2. (product_id, created_at) on sale_items
3. (expense_date, category) on expenses
4. (is_active, created_at) on products
5. (customer_id, created_at) on sales
6. (type, created_at) on stock_movements

### Fix Required
```sql
CREATE INDEX idx_sales_created_by_date ON sales(created_at, created_by);
CREATE INDEX idx_sale_items_product_date ON sale_items(product_id, created_at);
CREATE INDEX idx_expenses_date_category ON expenses(expense_date, category);
CREATE INDEX idx_products_active_date ON products(is_active, created_at);
CREATE INDEX idx_sales_customer_date ON sales(customer_id, created_at);
CREATE INDEX idx_stock_movements_type_date ON stock_movements(type, created_at);
```

### Estimated Effort
0.5 day

---

## PROBLEM #6: No Database Version Tracking

**Severity:** HIGH  
**Category:** Migration Management  
**Status:** UNFIXED

### Description
No schema_migrations table to track which migrations have been applied, making it impossible to determine database state.

### Impact
- Cannot determine migration status
- Risk of re-running migrations
- Cannot rollback reliably
- No audit trail
- Deployment risk

### Files Affected
All migration files (no version tracking)

### Root Cause
No migration management system implemented.

### Fix Required
1. Create schema_migrations table:
```sql
CREATE TABLE schema_migrations (
  version TEXT PRIMARY KEY,
  applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  checksum TEXT,
  description TEXT
);
```

2. Add migration version to each migration
3. Record migration execution
4. Add checksum validation
5. Add rollback tracking

### Estimated Effort
1 day

---

## PROBLEM #7: Conditional Column Addition Without Validation

**Severity:** MEDIUM  
**Category:** Data Integrity  
**Status:** UNFIXED

### Description
Columns are added conditionally without proper validation of existing schema, leading to potential schema inconsistencies.

### Impact
- Schema inconsistencies
- Migration failures
- Data type mismatches
- Application errors

### Files Affected
- atomic-checkout-migration.sql (multiple ADD COLUMN IF NOT EXISTS)
- hpp-migration.sql (line 25)
- customers-migration.sql (line 23)

### Root Cause
Using ADD COLUMN IF NOT EXISTS without checking column type or constraints.

### Evidence
```sql
-- atomic-checkout-migration.sql
ALTER TABLE sales ADD COLUMN IF NOT EXISTS customer_id UUID REFERENCES customers(id) ON DELETE SET NULL;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS discount_id UUID REFERENCES discounts(id) ON DELETE SET NULL;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS discount_amount DECIMAL(10, 2) DEFAULT 0;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS tax_rate DECIMAL(5, 2) DEFAULT 0;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS tax_amount DECIMAL(10, 2) DEFAULT 0;
ALTER TABLE sales ADD COLUMN IF NOT EXISTS transaction_token TEXT UNIQUE;
```

### Fix Required
1. Check column existence before adding
2. Validate column type if exists
3. Add constraints properly
4. Document schema changes
5. Test on existing databases

### Estimated Effort
1 day

---

## PROBLEM #8: No Data Validation Constraints

**Severity:** MEDIUM  
**Category:** Data Integrity  
**Status:** UNFIXED

### Description
Missing CHECK constraints for business rules, allowing invalid data to be stored.

### Impact
- Invalid data possible
- Business rule violations
- Data quality issues
- Application errors

### Files Affected
- All table definitions

### Missing Constraints
1. products.price > 0
2. products.cost >= 0
3. products.stock >= 0
4. sales.total_amount > 0
5. sale_items.quantity > 0
6. expenses.amount > 0

### Fix Required
```sql
ALTER TABLE products ADD CONSTRAINT chk_price_positive CHECK (price > 0);
ALTER TABLE products ADD CONSTRAINT chk_cost_non_negative CHECK (cost >= 0);
ALTER TABLE products ADD CONSTRAINT chk_stock_non_negative CHECK (stock >= 0);
ALTER TABLE sales ADD CONSTRAINT chk_total_positive CHECK (total_amount > 0);
ALTER TABLE sale_items ADD CONSTRAINT chk_quantity_positive CHECK (quantity > 0);
ALTER TABLE expenses ADD CONSTRAINT chk_amount_positive CHECK (amount > 0);
```

### Estimated Effort
0.5 day

---

## PROBLEM #9: No Trigger for Updated Timestamp

**Severity:** LOW  
**Category:** Data Consistency  
**Status:** PARTIALLY FIXED

### Description
Some tables lack triggers to automatically update updated_at timestamp, leading to stale timestamp data.

### Impact
- Stale timestamp data
- Inconsistent audit trail
- Difficult to track changes

### Files Affected
- customers table (has trigger)
- products table (has trigger)
- Other tables (missing trigger)

### Root Cause
Triggers not consistently applied to all tables.

### Fix Required
1. Add update_updated_at_column function to all tables
2. Create triggers for all tables with updated_at column
3. Test trigger functionality

### Estimated Effort
0.5 day

---

## PROBLEM #10: No Backup Strategy Documented

**Severity:** HIGH  
**Category:** Operations  
**Status:** UNFIXED

### Description
No backup strategy documented or implemented, risking data loss.

### Impact
- Risk of data loss
- No disaster recovery plan
- Compliance risk
- Business continuity risk

### Files Affected
None (missing documentation)

### Root Cause
Backup strategy not considered during development.

### Fix Required
1. Document backup strategy
2. Configure automated backups in Supabase
3. Test backup restoration
4. Document restore procedure
5. Set up backup monitoring

### Estimated Effort
1 day

---

## PROBLEM #11: No Database Monitoring

**Severity:** MEDIUM  
**Category:** Operations  
**Status:** UNFIXED

### Description
No database monitoring in place to detect performance issues, slow queries, or connection problems.

### Impact
- Cannot detect performance issues
- Cannot identify slow queries
- Cannot monitor connection pool
- Difficult to troubleshoot

### Files Affected
None (missing monitoring)

### Root Cause
Monitoring not configured.

### Fix Required
1. Configure Supabase monitoring
2. Set up slow query logging
3. Monitor connection pool
4. Set up alerting
5. Document monitoring procedures

### Estimated Effort
1 day

---

## PROBLEM #12: Sample Data Not Isolated

**Severity:** LOW  
**Category:** Data Management  
**Status:** UNFIXED

### Description
Sample data is mixed with schema definitions, making it difficult to deploy clean databases.

### Impact
- Sample data in production
- Difficult to reset database
- Data pollution
- Testing issues

### Files Affected
- supabase-schema.sql (lines 118-132)
- customers-migration.sql (lines 47-51)

### Root Cause
Sample data not separated from schema.

### Fix Required
1. Remove sample data from schema files
2. Create separate sample-data.sql
3. Document sample data usage
4. Add flag to include/exclude sample data

### Estimated Effort
0.5 day

---

## FIX ORDER RECOMMENDATION

Based on dependencies and impact:

1. **PROBLEM #1: Migration Fragmentation** (3-4 days) - Blocks deployment
2. **PROBLEM #2: RLS Recursion** (2-3 days) - Blocks authentication
3. **PROBLEM #6: Database Version Tracking** (1 day) - Required for migration management
4. **PROBLEM #3: Missing Foreign Keys** (1 day) - Data integrity
5. **PROBLEM #10: Backup Strategy** (1 day) - Operations critical
6. **PROBLEM #5: Missing Indexes** (0.5 day) - Performance
7. **PROBLEM #8: Data Validation** (0.5 day) - Data quality
8. **PROBLEM #4: Duplicate Policies** (0.5 day) - Migration cleanup
9. **PROBLEM #7: Conditional Columns** (1 day) - Schema consistency
10. **PROBLEM #11: Database Monitoring** (1 day) - Operations
11. **PROBLEM #9: Updated Timestamps** (0.5 day) - Data consistency
12. **PROBLEM #12: Sample Data** (0.5 day) - Data management

**Total Estimated Effort:** 13-15 days (3 weeks)

---

## TESTING REQUIREMENTS

Each database fix must include:

1. **Schema Validation** - Verify schema is correct
2. **Migration Testing** - Test migration on fresh database
3. **Rollback Testing** - Test rollback procedures
4. **Performance Testing** - Verify no performance regression
5. **Data Integrity Testing** - Verify referential integrity
6. **Backup/Restore Testing** - Test backup and restore

---

## ROLLBACK PLAN

If any database change causes issues:

1. Stop application
2. Restore from backup
3. Verify data integrity
4. Investigate issue
5. Fix migration
6. Re-test
7. Re-deploy

---

## NEXT STEPS

1. Prioritize PROBLEM #1 (Migration Fragmentation)
2. Prioritize PROBLEM #2 (RLS Recursion)
3. Create consolidated migration file
4. Implement version tracking
5. Test on development environment
6. Document all procedures

---

**Report Completed:** July 18, 2026  
**Next Review:** After migration consolidation
