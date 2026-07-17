-- Fix Infinite Recursion in Profiles RLS Policy
-- This patch fixes PostgreSQL error 42P17: infinite recursion detected in policy for relation "profiles"
--
-- ROOT CAUSE:
-- The "Admins can view all profiles" policy directly queries the profiles table to check if the user is an admin.
-- Since RLS is enabled on the profiles table, this creates infinite recursion:
--   1. User queries profiles
--   2. RLS policy "Admins can view all profiles" is evaluated
--   3. Policy queries profiles table: SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
--   4. RLS is triggered again on the profiles table
--   5. Step 2 repeats → infinite recursion (error 42P17)
--
-- DATABASE_UPGRADE_V2.sql overwrote the previously fixed policy with the recursive version.
-- This patch restores the fix using a SECURITY DEFINER function that bypasses RLS.

-- ============================================================================
-- Step 1: Drop the recursive policy
-- ============================================================================

DROP POLICY IF EXISTS "Admins can view all profiles" ON profiles;

-- ============================================================================
-- Step 2: Create SECURITY DEFINER function to check user role
-- This function bypasses RLS when checking the user's role, breaking the recursion loop
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
-- Step 3: Recreate the policy using the SECURITY DEFINER function
-- This avoids recursion because the function bypasses RLS
-- ============================================================================

CREATE POLICY "Admins can view all profiles"
  ON profiles FOR SELECT
  USING (public.is_admin());

-- ============================================================================
-- Step 4: Grant execute permission on the function to authenticated users
-- ============================================================================

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- ============================================================================
-- Step 5: Verification (optional - uncomment to verify)
-- ============================================================================

-- SELECT 
--   schemaname,
--   tablename,
--   policyname,
--   permissive,
--   roles,
--   cmd,
--   qual,
--   with_check
-- FROM pg_policies
-- WHERE tablename = 'profiles';
