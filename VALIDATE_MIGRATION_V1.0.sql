-- ============================================================================
-- Migration Validation Script for v1.0
-- ============================================================================
-- Purpose: Validate that migration to v1.0 was successful
-- Usage: Run this script after completing MIGRATION_ROADTO_V1.0.md
-- Expected Output: All checks should pass with no errors
-- ============================================================================

-- ============================================================================
-- SECTION 1: Schema Validation
-- ============================================================================

-- Check 1.1: Verify all required tables exist
DO $$
DECLARE
  required_tables TEXT[] := ARRAY[
    'profiles', 'customers', 'discounts', 'categories', 'payment_methods', 'settings',
    'products', 'sales', 'sale_items', 'stock_movements', 'suppliers',
    'daily_production', 'waste_items', 'raw_materials', 'product_recipes',
    'expenses', 'transaction_logs', 'schema_migrations'
  ];
  missing_tables TEXT[] := '{}';
  table_name TEXT;
BEGIN
  FOREACH table_name IN ARRAY required_tables LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_schema = 'public' AND table_name = table_name
    ) THEN
      missing_tables := array_append(missing_tables, table_name);
    END IF;
  END LOOP;
  
  IF array_length(missing_tables, 1) > 0 THEN
    RAISE EXCEPTION 'Missing tables: %', array_to_string(missing_tables, ', ');
  END IF;
  
  RAISE NOTICE '✓ All required tables exist';
END $$;

-- Check 1.2: Verify schema_migrations table has v1.0.0 entry
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM schema_migrations WHERE version = '1.0.0'
  ) THEN
    RAISE EXCEPTION 'Schema migration v1.0.0 not recorded in schema_migrations table';
  END IF;
  
  RAISE NOTICE '✓ Schema migration v1.0.0 recorded';
END $$;

-- ============================================================================
-- SECTION 2: Column Validation
-- ============================================================================

-- Check 2.1: Verify products table has all required columns
DO $$
DECLARE
  required_columns TEXT[] := ARRAY['id', 'name', 'category', 'price', 'cost', 'stock', 'hpp', 'barcode', 'image_url', 'is_active', 'created_at', 'updated_at'];
  missing_columns TEXT[] := '{}';
  column_name TEXT;
BEGIN
  FOREACH column_name IN ARRAY required_columns LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' AND table_name = 'products' AND column_name = column_name
    ) THEN
      missing_columns := array_append(missing_columns, column_name);
    END IF;
  END LOOP;
  
  IF array_length(missing_columns, 1) > 0 THEN
    RAISE EXCEPTION 'Products table missing columns: %', array_to_string(missing_columns, ', ');
  END IF;
  
  RAISE NOTICE '✓ Products table has all required columns';
END $$;

-- Check 2.2: Verify sales table has all required columns
DO $$
DECLARE
  required_columns TEXT[] := ARRAY['id', 'total_amount', 'total_cost', 'profit', 'payment_method', 'customer_id', 'discount_id', 'discount_amount', 'tax_rate', 'tax_amount', 'transaction_token', 'created_at', 'created_by'];
  missing_columns TEXT[] := '{}';
  column_name TEXT;
BEGIN
  FOREACH column_name IN ARRAY required_columns LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' AND table_name = 'sales' AND column_name = column_name
    ) THEN
      missing_columns := array_append(missing_columns, column_name);
    END IF;
  END LOOP;
  
  IF array_length(missing_columns, 1) > 0 THEN
    RAISE EXCEPTION 'Sales table missing columns: %', array_to_string(missing_columns, ', ');
  END IF;
  
  RAISE NOTICE '✓ Sales table has all required columns';
END $$;

-- Check 2.3: Verify customers table has all required columns
DO $$
DECLARE
  required_columns TEXT[] := ARRAY['id', 'name', 'phone', 'email', 'address', 'balance', 'points', 'notes', 'is_active', 'created_at', 'updated_at'];
  missing_columns TEXT[] := '{}';
  column_name TEXT;
BEGIN
  FOREACH column_name IN ARRAY required_columns LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' AND table_name = 'customers' AND column_name = column_name
    ) THEN
      missing_columns := array_append(missing_columns, column_name);
    END IF;
  END LOOP;
  
  IF array_length(missing_columns, 1) > 0 THEN
    RAISE EXCEPTION 'Customers table missing columns: %', array_to_string(missing_columns, ', ');
  END IF;
  
  RAISE NOTICE '✓ Customers table has all required columns';
END $$;

-- ============================================================================
-- SECTION 3: Constraint Validation
-- ============================================================================

-- Check 3.1: Verify foreign key constraints exist
DO $$
DECLARE
  missing_fks TEXT[] := '{}';
BEGIN
  -- Check sales.customer_id FK
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'sales_customer_id_fkey' AND table_name = 'sales'
  ) THEN
    missing_fks := array_append(missing_fks, 'sales.customer_id');
  END IF;
  
  -- Check sales.discount_id FK
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'sales_discount_id_fkey' AND table_name = 'sales'
  ) THEN
    missing_fks := array_append(missing_fks, 'sales.discount_id');
  END IF;
  
  -- Check sale_items.sale_id FK
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'sale_items_sale_id_fkey' AND table_name = 'sale_items'
  ) THEN
    missing_fks := array_append(missing_fks, 'sale_items.sale_id');
  END IF;
  
  IF array_length(missing_fks, 1) > 0 THEN
    RAISE EXCEPTION 'Missing foreign key constraints: %', array_to_string(missing_fks, ', ');
  END IF;
  
  RAISE NOTICE '✓ All required foreign key constraints exist';
END $$;

-- Check 3.2: Verify conflicting constraints were removed
DO $$
DECLARE
  conflicting_constraints TEXT[] := ARRAY['check_payment_method', 'products_category_check', 'raw_materials_unit_check'];
  existing_constraints TEXT[] := '{}';
  constraint_name TEXT;
BEGIN
  FOREACH constraint_name IN ARRAY conflicting_constraints LOOP
    IF EXISTS (
      SELECT 1 FROM information_schema.table_constraints 
      WHERE constraint_name = constraint_name
    ) THEN
      existing_constraints := array_append(existing_constraints, constraint_name);
    END IF;
  END LOOP;
  
  IF array_length(existing_constraints, 1) > 0 THEN
    RAISE EXCEPTION 'Conflicting constraints still exist: %', array_to_string(existing_constraints, ', ');
  END IF;
  
  RAISE NOTICE '✓ Conflicting constraints removed';
END $$;

-- Check 3.3: Verify data validation constraints exist
DO $$
DECLARE
  required_checks TEXT[] := ARRAY[
    'check_products_price_positive',
    'check_products_cost_nonnegative',
    'check_products_stock_nonnegative',
    'check_products_hpp_nonnegative',
    'check_sales_total_amount_positive',
    'check_sales_total_cost_nonnegative',
    'check_sales_discount_amount_nonnegative',
    'check_sales_tax_rate_nonnegative',
    'check_sales_tax_amount_nonnegative'
  ];
  missing_checks TEXT[] := '{}';
  check_name TEXT;
BEGIN
  FOREACH check_name IN ARRAY required_checks LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints 
      WHERE constraint_name = check_name
    ) THEN
      missing_checks := array_append(missing_checks, check_name);
    END IF;
  END LOOP;
  
  IF array_length(missing_checks, 1) > 0 THEN
    RAISE WARNING 'Some data validation constraints missing: %', array_to_string(missing_checks, ', ');
  ELSE
    RAISE NOTICE '✓ Data validation constraints exist';
  END IF;
END $$;

-- ============================================================================
-- SECTION 4: Index Validation
-- ============================================================================

-- Check 4.1: Verify composite indexes exist
DO $$
DECLARE
  required_indexes TEXT[] := ARRAY[
    'idx_products_active_date',
    'idx_sales_created_by_date',
    'idx_sales_customer_date',
    'idx_sale_items_product_date',
    'idx_stock_movements_type_date',
    'idx_expenses_date_category'
  ];
  missing_indexes TEXT[] := '{}';
  index_name TEXT;
BEGIN
  FOREACH index_name IN ARRAY required_indexes LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_indexes 
      WHERE schemaname = 'public' AND indexname = index_name
    ) THEN
      missing_indexes := array_append(missing_indexes, index_name);
    END IF;
  END LOOP;
  
  IF array_length(missing_indexes, 1) > 0 THEN
    RAISE WARNING 'Some composite indexes missing: %', array_to_string(missing_indexes, ', ');
  ELSE
    RAISE NOTICE '✓ Composite indexes exist';
  END IF;
END $$;

-- Check 4.2: Verify barcode index exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE schemaname = 'public' AND indexname = 'idx_products_barcode'
  ) THEN
    RAISE EXCEPTION 'Barcode index missing';
  END IF;
  
  RAISE NOTICE '✓ Barcode index exists';
END $$;

-- ============================================================================
-- SECTION 5: Function Validation
-- ============================================================================

-- Check 5.1: Verify SECURITY DEFINER functions exist
DO $$
DECLARE
  required_functions TEXT[] := ARRAY['is_admin', 'is_kasir', 'is_authenticated', 'process_checkout'];
  missing_functions TEXT[] := '{}';
  function_name TEXT;
BEGIN
  FOREACH function_name IN ARRAY required_functions LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.routines 
      WHERE routine_schema = 'public' AND routine_name = function_name
    ) THEN
      missing_functions := array_append(missing_functions, function_name);
    END IF;
  END LOOP;
  
  IF array_length(missing_functions, 1) > 0 THEN
    RAISE EXCEPTION 'Missing functions: %', array_to_string(missing_functions, ', ');
  END IF;
  
  RAISE NOTICE '✓ All required functions exist';
END $$;

-- Check 5.2: Verify functions have SECURITY DEFINER
DO $$
DECLARE
  non_definer_functions TEXT[] := '{}';
BEGIN
  SELECT array_agg(routine_name) INTO non_definer_functions
  FROM information_schema.routines
  WHERE routine_schema = 'public'
  AND routine_name IN ('is_admin', 'is_kasir', 'is_authenticated', 'process_checkout')
  AND security_type != 'DEFINER';
  
  IF array_length(non_definer_functions, 1) > 0 THEN
    RAISE EXCEPTION 'Functions not SECURITY DEFINER: %', array_to_string(non_definer_functions, ', ');
  END IF;
  
  RAISE NOTICE '✓ All functions have SECURITY DEFINER';
END $$;

-- Check 5.3: Verify HPP functions exist
DO $$
DECLARE
  required_hpp_functions TEXT[] := ARRAY['calculate_product_hpp', 'update_all_product_hpp', 'update_product_hpp_trigger'];
  missing_functions TEXT[] := '{}';
  function_name TEXT;
BEGIN
  FOREACH function_name IN ARRAY required_hpp_functions LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.routines 
      WHERE routine_schema = 'public' AND routine_name = function_name
    ) THEN
      missing_functions := array_append(missing_functions, function_name);
    END IF;
  END LOOP;
  
  IF array_length(missing_functions, 1) > 0 THEN
    RAISE EXCEPTION 'Missing HPP functions: %', array_to_string(missing_functions, ', ');
  END IF;
  
  RAISE NOTICE '✓ HPP functions exist';
END $$;

-- ============================================================================
-- SECTION 6: RLS Validation
-- ============================================================================

-- Check 6.1: Verify RLS is enabled on all tables
DO $$
DECLARE
  tables_without_rls TEXT[] := '{}';
  table_name TEXT;
BEGIN
  FOR table_name IN 
    SELECT table_name FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name IN (
      'profiles', 'customers', 'discounts', 'categories', 'payment_methods', 'settings',
      'products', 'sales', 'sale_items', 'stock_movements', 'suppliers',
      'daily_production', 'waste_items', 'raw_materials', 'product_recipes',
      'expenses', 'transaction_logs'
    )
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_schema = 'public' AND table_name = table_name AND row_security = true
    ) THEN
      tables_without_rls := array_append(tables_without_rls, table_name);
    END IF;
  END LOOP;
  
  IF array_length(tables_without_rls, 1) > 0 THEN
    RAISE EXCEPTION 'RLS not enabled on tables: %', array_to_string(tables_without_rls, ', ');
  END IF;
  
  RAISE NOTICE '✓ RLS enabled on all tables';
END $$;

-- Check 6.2: Verify no policies use direct profiles queries (recursion risk)
DO $$
DECLARE
  recursive_policies TEXT[] := '{}';
  policy_name TEXT;
BEGIN
  SELECT array_agg(policyname) INTO recursive_policies
  FROM pg_policies
  WHERE qual LIKE '%profiles%' OR with_check LIKE '%profiles%';
  
  IF array_length(recursive_policies, 1) > 0 THEN
    RAISE EXCEPTION 'Policies still use direct profiles queries (recursion risk): %', array_to_string(recursive_policies, ', ');
  END IF;
  
  RAISE NOTICE '✓ No policies use direct profiles queries (recursion risk fixed)';
END $$;

-- Check 6.3: Verify policies use SECURITY DEFINER functions
DO $$
DECLARE
  policy_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO policy_count
  FROM pg_policies
  WHERE qual LIKE '%is_admin%' OR qual LIKE '%is_kasir%' OR qual LIKE '%is_authenticated%'
  OR with_check LIKE '%is_admin%' OR with_check LIKE '%is_kasir%' OR with_check LIKE '%is_authenticated%';
  
  IF policy_count = 0 THEN
    RAISE EXCEPTION 'No policies use SECURITY DEFINER functions';
  END IF;
  
  RAISE NOTICE '✓ Policies use SECURITY DEFINER functions (%)', policy_count;
END $$;

-- ============================================================================
-- SECTION 7: Data Integrity Validation
-- ============================================================================

-- Check 7.1: Verify no orphaned sale_items
DO $$
DECLARE
  orphaned_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO orphaned_count
  FROM sale_items si
  LEFT JOIN sales s ON si.sale_id = s.id
  WHERE s.id IS NULL;
  
  IF orphaned_count > 0 THEN
    RAISE EXCEPTION 'Found % orphaned sale_items records', orphaned_count;
  END IF;
  
  RAISE NOTICE '✓ No orphaned sale_items records';
END $$;

-- Check 7.2: Verify no orphaned stock_movements
DO $$
DECLARE
  orphaned_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO orphaned_count
  FROM stock_movements sm
  LEFT JOIN products p ON sm.product_id = p.id
  WHERE p.id IS NULL;
  
  IF orphaned_count > 0 THEN
    RAISE EXCEPTION 'Found % orphaned stock_movements records', orphaned_count;
  END IF;
  
  RAISE NOTICE '✓ No orphaned stock_movements records';
END $$;

-- Check 7.3: Verify no invalid product prices
DO $$
DECLARE
  invalid_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO invalid_count
  FROM products WHERE price <= 0;
  
  IF invalid_count > 0 THEN
    RAISE EXCEPTION 'Found % products with invalid price (<= 0)', invalid_count;
  END IF;
  
  RAISE NOTICE '✓ No products with invalid price';
END $$;

-- Check 7.4: Verify no negative stock
DO $$
DECLARE
  negative_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO negative_count
  FROM products WHERE stock < 0;
  
  IF negative_count > 0 THEN
    RAISE EXCEPTION 'Found % products with negative stock', negative_count;
  END IF;
  
  RAISE NOTICE '✓ No products with negative stock';
END $$;

-- Check 7.5: Verify no invalid sales amounts
DO $$
DECLARE
  invalid_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO invalid_count
  FROM sales WHERE total_amount <= 0;
  
  IF invalid_count > 0 THEN
    RAISE EXCEPTION 'Found % sales with invalid total_amount (<= 0)', invalid_count;
  END IF;
  
  RAISE NOTICE '✓ No sales with invalid total_amount';
END $$;

-- ============================================================================
-- SECTION 8: Trigger Validation
-- ============================================================================

-- Check 8.1: Verify updated_at triggers exist
DO $$
DECLARE
  missing_triggers TEXT[] := '{}';
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.triggers 
    WHERE trigger_name = 'update_products_updated_at' AND table_name = 'products'
  ) THEN
    missing_triggers := array_append(missing_triggers, 'update_products_updated_at');
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.triggers 
    WHERE trigger_name = 'update_profiles_updated_at' AND table_name = 'profiles'
  ) THEN
    missing_triggers := array_append(missing_triggers, 'update_profiles_updated_at');
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.triggers 
    WHERE trigger_name = 'update_customers_updated_at' AND table_name = 'customers'
  ) THEN
    missing_triggers := array_append(missing_triggers, 'update_customers_updated_at');
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.triggers 
    WHERE trigger_name = 'update_discounts_updated_at' AND table_name = 'discounts'
  ) THEN
    missing_triggers := array_append(missing_triggers, 'update_discounts_updated_at');
  END IF;
  
  IF array_length(missing_triggers, 1) > 0 THEN
    RAISE WARNING 'Some updated_at triggers missing: %', array_to_string(missing_triggers, ', ');
  ELSE
    RAISE NOTICE '✓ All updated_at triggers exist';
  END IF;
END $$;

-- Check 8.2: Verify HPP triggers exist
DO $$
DECLARE
  missing_triggers TEXT[] := '{}';
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.triggers 
    WHERE trigger_name = 'trigger_update_hpp_after_insert' AND table_name = 'product_recipes'
  ) THEN
    missing_triggers := array_append(missing_triggers, 'trigger_update_hpp_after_insert');
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.triggers 
    WHERE trigger_name = 'trigger_update_hpp_after_update' AND table_name = 'product_recipes'
  ) THEN
    missing_triggers := array_append(missing_triggers, 'trigger_update_hpp_after_update');
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.triggers 
    WHERE trigger_name = 'trigger_update_hpp_after_delete' AND table_name = 'product_recipes'
  ) THEN
    missing_triggers := array_append(missing_triggers, 'trigger_update_hpp_after_delete');
  END IF;
  
  IF array_length(missing_triggers, 1) > 0 THEN
    RAISE EXCEPTION 'Missing HPP triggers: %', array_to_string(missing_triggers, ', ');
  END IF;
  
  RAISE NOTICE '✓ HPP triggers exist';
END $$;

-- Check 8.3: Verify handle_new_user trigger exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.triggers 
    WHERE trigger_name = 'on_auth_user_created' AND table_name = 'users' AND trigger_schema = 'auth'
  ) THEN
    RAISE EXCEPTION 'handle_new_user trigger missing';
  END IF;
  
  RAISE NOTICE '✓ handle_new_user trigger exists';
END $$;

-- ============================================================================
-- SECTION 9: Row Count Validation (Data Preservation)
-- ============================================================================

-- Check 9.1: Verify data preservation (row counts)
-- Note: This section requires manual verification against pre-migration counts
-- Uncomment and update expected counts after running pre-migration assessment

/*
DO $$
DECLARE
  expected_counts JSONB := '{
    "products": 14,
    "sales": 0,
    "customers": 3,
    "discounts": 3,
    "categories": 3,
    "payment_methods": 2
  }'::JSONB;
  actual_count INTEGER;
  expected_count INTEGER;
  table_name TEXT;
BEGIN
  FOR table_name IN SELECT key FROM jsonb_each_text(expected_counts) LOOP
    expected_count := (expected_counts->>table_name)::INTEGER;
    
    EXECUTE format('SELECT COUNT(*) FROM %I', table_name) INTO actual_count;
    
    IF actual_count != expected_count THEN
      RAISE WARNING 'Table %: expected % rows, found % rows', table_name, expected_count, actual_count;
    ELSE
      RAISE NOTICE '✓ Table %: % rows (expected)', table_name, actual_count;
    END IF;
  END LOOP;
END $$;
*/

-- Alternative: Just report current row counts for manual verification
RAISE NOTICE '--- Row Counts for Manual Verification ---';
DO $$
DECLARE
  table_name TEXT;
  row_count INTEGER;
BEGIN
  FOR table_name IN 
    SELECT table_name FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name IN ('products', 'sales', 'customers', 'discounts', 'categories', 'payment_methods')
    ORDER BY table_name
  LOOP
    EXECUTE format('SELECT COUNT(*) FROM %I', table_name) INTO row_count;
    RAISE NOTICE '%: % rows', table_name, row_count;
  END LOOP;
END $$;

-- ============================================================================
-- SECTION 10: Summary Report
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'MIGRATION VALIDATION SUMMARY';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE 'If you see all ✓ checks above, migration successful!';
  RAISE NOTICE 'If you see any EXCEPTION or WARNING, review and fix.';
  RAISE NOTICE '';
  RAISE NOTICE 'Next steps:';
  RAISE NOTICE '1. Test authentication (login as admin and kasir)';
  RAISE NOTICE '2. Test business functions (create sale, update stock)';
  RAISE NOTICE '3. Test RLS policies (verify access control)';
  RAISE NOTICE '4. Monitor application logs for errors';
  RAISE NOTICE '5. Monitor database performance';
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
END $$;

-- ============================================================================
-- END OF VALIDATION SCRIPT
-- ============================================================================
