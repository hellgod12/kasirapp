-- Clear Sample/Dummy Data from Database
-- This migration removes all sample data from products and categories tables
-- Run this to clean the database before adding real user data

-- Step 1: Delete all products (this will cascade to related tables if foreign keys are set up)
DELETE FROM products;

-- Step 2: Delete all categories
DELETE FROM categories;

-- Step 3: Delete sample raw materials (if any)
DELETE FROM raw_materials;

-- Step 4: Delete sample product recipes (if any)
DELETE FROM product_recipes;

-- Step 5: Delete sample payment methods (if you want to reset to default)
-- Uncomment if you want to reset payment methods
-- DELETE FROM payment_methods;

-- Step 6: Verify the tables are empty
SELECT 'Products count:' as table_name, COUNT(*) as count FROM products
UNION ALL
SELECT 'Categories count:', COUNT(*) FROM categories
UNION ALL
SELECT 'Raw materials count:', COUNT(*) FROM raw_materials
UNION ALL
SELECT 'Product recipes count:', COUNT(*) FROM product_recipes
UNION ALL
SELECT 'Payment methods count:', COUNT(*) FROM payment_methods;
