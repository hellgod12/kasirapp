-- Fix Profiles RLS for Login Issue
-- This script fixes PostgreSQL error 42P17 and login issues caused by recursive RLS policy

-- ============================================================================
-- STEP 1: List Current Policies on Profiles Table
-- Run this to see current state
-- ============================================================================

SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY policyname;

-- ============================================================================
-- STEP 2: Remove Recursive Policy
-- Policy causing recursion: "Admins can view all profiles"
-- Reason: It queries profiles table within the policy itself
-- Recursion loop: Query profiles → RLS policy → Query profiles → RLS policy → ...
-- ============================================================================

DROP POLICY IF EXISTS "Admins can view all profiles" ON profiles;

-- ============================================================================
-- STEP 3: Create SECURITY DEFINER Function to Check User Role
-- This function bypasses RLS, breaking the recursion loop
-- ============================================================================

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

-- ============================================================================
-- STEP 4: Recreate Policy Using SECURITY DEFINER Function
-- This avoids recursion because the function bypasses RLS
-- ============================================================================

CREATE POLICY "Admins can view all profiles"
  ON profiles FOR SELECT
  USING (public.is_admin());

-- ============================================================================
-- STEP 5: Grant Execute Permission on Function
-- ============================================================================

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- ============================================================================
-- STEP 6: Verify Fix
-- Run this to confirm the policy is now using the function
-- ============================================================================

SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY policyname;
