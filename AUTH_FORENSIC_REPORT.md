# Supabase Authentication Forensic Report

**Report Date:** July 18, 2026  
**Error:** AuthApiError: Invalid login credentials  
**Issue:** User cannot sign in despite existing in auth.users and public.profiles

---

## Forensic SQL Queries

Run these queries in Supabase SQL Editor to diagnose the root cause.

---

## SECTION 1: Inspect auth.users Table

### Query 1.1: List all users with critical fields
```sql
SELECT 
  id,
  email,
  email_confirmed_at,
  created_at,
  updated_at,
  last_sign_in_at,
  raw_app_meta_data,
  raw_user_meta_data,
  is_anonymous,
  encrypted_password IS NOT NULL as has_password,
  phone,
  phone_confirmed_at
FROM auth.users
ORDER BY created_at DESC;
```

### Query 1.2: Check specific user by email (replace with actual email)
```sql
SELECT 
  id,
  email,
  email_confirmed_at,
  created_at,
  updated_at,
  last_sign_in_at,
  encrypted_password IS NOT NULL as has_password,
  LENGTH(encrypted_password) as password_length,
  raw_app_meta_data,
  raw_user_meta_data,
  is_anonymous
FROM auth.users
WHERE email = 'your-email@example.com';
```

### Query 1.3: Check for users without confirmed emails
```sql
SELECT 
  id,
  email,
  email_confirmed_at,
  created_at,
  encrypted_password IS NOT NULL as has_password
FROM auth.users
WHERE email_confirmed_at IS NULL
ORDER BY created_at DESC;
```

### Query 1.4: Check for users without passwords
```sql
SELECT 
  id,
  email,
  email_confirmed_at,
  created_at,
  raw_app_meta_data,
  raw_user_meta_data
FROM auth.users
WHERE encrypted_password IS NULL
ORDER BY created_at DESC;
```

---

## SECTION 2: Inspect auth.identities Table

### Query 2.1: List all identities
```sql
SELECT 
  id,
  user_id,
  identity_data,
  provider,
  provider_id,
  last_sign_in_at,
  created_at,
  updated_at
FROM auth.identities
ORDER BY created_at DESC;
```

### Query 2.2: Check identities for specific user (replace UUID)
```sql
SELECT 
  i.id,
  i.user_id,
  i.identity_data,
  i.provider,
  i.provider_id,
  i.last_sign_in_at,
  i.created_at,
  u.email
FROM auth.identities i
JOIN auth.users u ON u.id = i.user_id
WHERE u.email = 'your-email@example.com';
```

### Query 2.3: Check for users without identities
```sql
SELECT 
  u.id,
  u.email,
  u.created_at,
  u.email_confirmed_at
FROM auth.users u
LEFT JOIN auth.identities i ON u.id = i.user_id
WHERE i.id IS NULL
ORDER BY u.created_at DESC;
```

---

## SECTION 3: Verify Identity Provider

### Query 3.1: Check provider distribution
```sql
SELECT 
  provider,
  COUNT(*) as user_count
FROM auth.identities
GROUP BY provider
ORDER BY user_count DESC;
```

### Query 3.2: Check if user has email provider identity
```sql
SELECT 
  i.id,
  i.user_id,
  i.provider,
  i.identity_data,
  u.email
FROM auth.identities i
JOIN auth.users u ON u.id = i.user_id
WHERE u.email = 'your-email@example.com'
AND i.provider = 'email';
```

---

## SECTION 4: Check Email Confirmation Status

### Query 4.1: Users with unconfirmed emails
```sql
SELECT 
  id,
  email,
  created_at,
  email_confirmed_at,
  NOW() - created_at as age,
  encrypted_password IS NOT NULL as has_password
FROM auth.users
WHERE email_confirmed_at IS NULL
ORDER BY created_at DESC;
```

### Query 4.2: Check if email confirmation is required in settings
```sql
-- This query checks the auth configuration
-- Note: This may require access to system tables
SELECT * FROM auth.config WHERE key LIKE '%confirm%';
```

---

## SECTION 5: Verify Encrypted Password

### Query 5.1: Check password hash format
```sql
SELECT 
  id,
  email,
  encrypted_password IS NOT NULL as has_password,
  LENGTH(encrypted_password) as password_length,
  SUBSTRING(encrypted_password, 1, 10) as password_prefix
FROM auth.users
WHERE email = 'your-email@example.com';
```

### Query 5.2: Check for invalid password hashes
```sql
SELECT 
  id,
  email,
  encrypted_password IS NOT NULL as has_password,
  LENGTH(encrypted_password) as password_length
FROM auth.users
WHERE encrypted_password IS NOT NULL
AND LENGTH(encrypted_password) < 50
ORDER BY created_at DESC;
```

---

## SECTION 6: Check for Soft Deletion

### Query 6.1: Check for deleted_at field (if exists)
```sql
SELECT 
  id,
  email,
  deleted_at,
  created_at,
  updated_at
FROM auth.users
WHERE deleted_at IS NOT NULL
ORDER BY deleted_at DESC;
```

### Query 6.2: Check for banned users (if using app metadata)
```sql
SELECT 
  id,
  email,
  raw_app_meta_data,
  raw_user_meta_data
FROM auth.users
WHERE 
  raw_app_meta_data::text LIKE '%banned%' 
  OR raw_user_meta_data::text LIKE '%banned%'
ORDER BY created_at DESC;
```

---

## SECTION 7: Inspect Auth Hooks

### Query 7.1: Check for custom auth hooks
```sql
-- Check for functions that might be intercepting auth
SELECT 
  routine_name,
  routine_type,
  data_type,
  is_deterministic,
  external_name,
  external_language
FROM information_schema.routines
WHERE routine_schema = 'auth'
AND routine_name LIKE '%hook%'
OR routine_name LIKE '%auth%'
ORDER BY routine_name;
```

### Query 7.2: Check for triggers on auth.users
```sql
SELECT 
  trigger_name,
  event_manipulation,
  event_object_table,
  action_statement,
  action_timing
FROM information_schema.triggers
WHERE event_object_schema = 'auth'
AND event_object_table = 'users'
ORDER BY trigger_name;
```

---

## SECTION 8: Verify public.profiles Link

### Query 8.1: Check profiles table
```sql
SELECT 
  p.id,
  p.email,
  p.name,
  p.role,
  p.created_at,
  u.email_confirmed_at,
  u.encrypted_password IS NOT NULL as has_password
FROM public.profiles p
LEFT JOIN auth.users u ON p.id = u.id
ORDER BY p.created_at DESC;
```

### Query 8.2: Check for orphaned profiles (no matching auth user)
```sql
SELECT 
  p.id,
  p.email,
  p.name,
  p.role,
  p.created_at
FROM public.profiles p
LEFT JOIN auth.users u ON p.id = u.id
WHERE u.id IS NULL;
```

### Query 8.3: Check for auth users without profiles
```sql
SELECT 
  u.id,
  u.email,
  u.created_at,
  u.email_confirmed_at
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.id
WHERE p.id IS NULL;
```

---

## SECTION 9: Account Recreation SQL

### WARNING: Only use if account is corrupted

### Step 1: Backup existing user data
```sql
-- Backup user data before deletion
SELECT 
  u.id,
  u.email,
  u.raw_app_meta_data,
  u.raw_user_meta_data,
  p.name,
  p.role
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.id
WHERE u.email = 'your-email@example.com';
```

### Step 2: Delete corrupted user (CAREFUL - irreversible)
```sql
-- Delete from profiles first (due to FK)
DELETE FROM public.profiles
WHERE id = (SELECT id FROM auth.users WHERE email = 'your-email@example.com');

-- Delete identities
DELETE FROM auth.identities
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'your-email@example.com');

-- Delete from auth.users
DELETE FROM auth.users
WHERE email = 'your-email@example.com';
```

### Step 3: Recreate user via Supabase Dashboard
**Recommended:** Use Supabase Dashboard → Authentication → Users → Add User
- Enter email
- Set password
- Set auto-confirm to true
- Set role in raw_user_meta_data

### Step 4: Recreate profile manually (if needed)
```sql
INSERT INTO public.profiles (id, email, name, role, created_at, updated_at)
VALUES (
  (SELECT id FROM auth.users WHERE email = 'your-email@example.com'),
  'your-email@example.com',
  'User Name',
  'admin', -- or 'kasir'
  NOW(),
  NOW()
);
```

---

## SECTION 10: Common Root Causes

### Cause 1: Email Not Confirmed
**Evidence:** `email_confirmed_at` is NULL in auth.users  
**Fix:** 
```sql
-- Force confirm email (use with caution)
UPDATE auth.users
SET email_confirmed_at = NOW()
WHERE email = 'your-email@example.com';
```

### Cause 2: Missing Password
**Evidence:** `encrypted_password` is NULL  
**Fix:** User must reset password via Supabase Dashboard

### Cause 3: Missing Identity
**Evidence:** No matching row in auth.identities  
**Fix:** Recreate user via Supabase Dashboard

### Cause 4: Wrong Project URL/Key
**Evidence:** N/A (client-side configuration)  
**Fix:** Verify .env.local or environment variables

### Cause 5: Auth Hook Blocking
**Evidence:** Custom functions/triggers in auth schema  
**Fix:** Review and disable problematic hooks

---

## SECTION 11: Client-Side Verification

### Check Environment Variables
```bash
# Verify these match your Supabase project
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
```

### Verify signInWithPassword() Usage
```typescript
// Correct usage
const { data, error } = await supabase.auth.signInWithPassword({
  email: 'user@example.com',
  password: 'password123',
});

// Check error
if (error) {
  console.error('Login error:', error.message);
  console.error('Error code:', error.status);
}
```

---

## SECTION 12: Diagnostic Checklist

Run through this checklist systematically:

- [ ] User exists in auth.users (Query 1.2)
- [ ] email_confirmed_at is NOT NULL (Query 1.2)
- [ ] encrypted_password is NOT NULL (Query 1.2)
- [ ] User has identity in auth.identities (Query 2.2)
- [ ] Identity provider is 'email' (Query 3.2)
- [ ] Profile exists in public.profiles (Query 8.1)
- [ ] No auth hooks blocking login (Query 7.1)
- [ ] Project URL matches Supabase project
- [ ] ANON_KEY belongs to same project
- [ ] Email provider enabled in Supabase Dashboard
- [ ] Password login enabled in Supabase Dashboard

---

## SECTION 13: Next Steps

1. Run Query 1.2 with the failing user's email
2. Run Query 2.2 to check identities
3. Run Query 8.1 to check profile linkage
4. Compare results against Diagnostic Checklist
5. Identify missing/incorrect data
6. Apply appropriate fix from Section 10
7. Test login again

---

**Report Completed:** July 18, 2026  
**Status:** Awaiting SQL execution results
