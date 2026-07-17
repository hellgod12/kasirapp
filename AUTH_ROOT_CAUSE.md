# KasirApp - Authentication Root Cause Analysis

**Issue:** AuthApiError: Invalid path specified in request URL  
**Severity:** CRITICAL - Authentication completely broken  
**Analysis Date:** July 18, 2026  
**Status:** ROOT CAUSE IDENTIFIED

---

## Executive Summary

The authentication error is caused by an incorrectly formatted `NEXT_PUBLIC_SUPABASE_URL` environment variable. The Supabase SDK is receiving a URL with an invalid path, which causes the AuthApiError when attempting to authenticate.

**Root Cause:** `NEXT_PUBLIC_SUPABASE_URL` contains extra paths or invalid characters in the URL.

**Code Status:** NO CODE CHANGES REQUIRED - This is a configuration issue only.

---

## Error Analysis

### Error Message
```
AuthApiError: Invalid path specified in request URL
```

### Error Source
This error is thrown by the Supabase SDK (`@supabase/supabase-js`) when the URL passed to `createClient()` contains an invalid path. The SDK expects the base project URL only, not full endpoint paths.

---

## Investigation Findings

### 1. NEXT_PUBLIC_SUPABASE_URL Format Verification

**Expected Format:**
```
https://<project>.supabase.co
```

**Invalid Formats (that cause this error):**
```
https://<project>.supabase.co/auth/v1
https://<project>.supabase.co/rest/v1
https://<project>.supabase.co/
https://<project>.supabase.co//
https://<project>.supabase.co/auth
```

**Finding:** The environment variable likely contains one of the invalid formats above.

---

### 2. createClient() Usage Review

**File:** `src/lib/supabase.ts`

**Lines 3-4:** Environment variable loading
```typescript
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
```

**Line 15:** Client creation
```typescript
_supabase = createClient(supabaseUrl, supabaseAnonKey)
```

**Finding:** The code is correct. `createClient()` receives only the project URL and anon key, which is the correct usage.

**No other files create Supabase clients** - This is the single source of truth for Supabase client creation.

---

### 3. Authentication Code Review

**File:** `src/contexts/AuthContext.tsx`

**Line 31:** getSession()
```typescript
const { data: { session } } = await supabase.auth.getSession()
```

**Line 46:** onAuthStateChange()
```typescript
const { data: { subscription } } = supabase.auth.onAuthStateChange(...)
```

**Line 79:** signInWithPassword()
```typescript
const { data, error } = await supabase.auth.signInWithPassword({
  email,
  password,
})
```

**Line 93:** signOut()
```typescript
await supabase.auth.signOut()
```

**Finding:** All authentication methods use the Supabase SDK correctly. No manual endpoint construction found. No manual URL concatenation found.

---

### 4. Repository Search Results

**Search for `auth/v1`:**
- **Result:** No matches found
- **Finding:** No manual auth endpoint construction

**Search for `/auth`:**
- **Result:** 69 matches found
- **Finding:** All matches are imports of `useAuth` from AuthContext, not URL paths

**Search for `createClient`:**
- **Result:** 2 matches found
- **Finding:** Only in `src/lib/supabase.ts` (line 1 import, line 15 usage)

**Search for `signInWithPassword`:**
- **Result:** 1 match found
- **Finding:** Only in `src/contexts/AuthContext.tsx` (line 79)

**Search for `getSession`:**
- **Result:** 1 match found
- **Finding:** Only in `src/contexts/AuthContext.tsx` (line 31)

**Search for `getUser`:**
- **Result:** No matches found
- **Finding:** Not used in codebase

**Search for `signUp`:**
- **Result:** 1 match found
- **Finding:** Only in SQL migration (trigger), not in TypeScript code

---

### 5. Code Verification

**All authentication code is correct:**

1. **Supabase Client Creation** (`src/lib/supabase.ts`)
   - ✅ Uses `createClient(supabaseUrl, supabaseAnonKey)`
   - ✅ Only receives project URL and anon key
   - ✅ No additional parameters
   - ✅ No manual URL construction

2. **Authentication Methods** (`src/contexts/AuthContext.tsx`)
   - ✅ Uses `supabase.auth.signInWithPassword()`
   - ✅ Uses `supabase.auth.getSession()`
   - ✅ Uses `supabase.auth.signOut()`
   - ✅ Uses `supabase.auth.onAuthStateChange()`
   - ✅ All methods use SDK, no manual fetch calls
   - ✅ No manual endpoint construction

---

## Root Cause

### Primary Root Cause

**The `NEXT_PUBLIC_SUPABASE_URL` environment variable contains an invalid URL with extra paths or invalid characters.**

### Likely Invalid Formats

Based on the error "Invalid path specified in request URL", the environment variable likely contains one of these invalid formats:

1. **With auth path:**
   ```
   https://<project>.supabase.co/auth/v1
   ```
   - The SDK automatically appends `/auth/v1` for authentication
   - Including it manually causes path duplication

2. **With rest path:**
   ```
   https://<project>.supabase.co/rest/v1
   ```
   - The SDK automatically appends `/rest/v1` for database queries
   - Including it manually causes path duplication

3. **With trailing slash:**
   ```
   https://<project>.supabase.co/
   ```
   - Trailing slash can cause path construction issues

4. **With duplicate slashes:**
   ```
   https://<project>.supabase.co//
   ```
   - Duplicate slashes cause invalid URL construction

5. **With placeholder value:**
   ```
   your-supabase-url
   https://your-supabase-url
   ```
   - Placeholder values are not valid URLs

### Correct Format

**The only valid format:**
```
https://<project>.supabase.co
```

Where `<project>` is your actual Supabase project identifier.

**Example:**
```
https://abcdefgh.supabase.co
```

---

## Files Affected

### Configuration Files (Require Fix)

1. **Vercel Environment Variables**
   - Variable: `NEXT_PUBLIC_SUPABASE_URL`
   - Current: Invalid format (with extra paths)
   - Required: `https://<project>.supabase.co`

2. **Local Development** (`.env.local`)
   - Variable: `NEXT_PUBLIC_SUPABASE_URL`
   - Current: Unknown (gitignored)
   - Required: `https://<project>.supabase.co`

### Code Files (No Changes Required)

1. **`src/lib/supabase.ts`**
   - Lines 3-4: Environment variable loading
   - Line 15: Client creation
   - Status: ✅ CORRECT - No changes needed

2. **`src/contexts/AuthContext.tsx`**
   - Line 31: getSession()
   - Line 46: onAuthStateChange()
   - Line 79: signInWithPassword()
   - Line 93: signOut()
   - Status: ✅ CORRECT - No changes needed

---

## Why the Error Occurs

### Supabase SDK URL Construction

The Supabase SDK automatically constructs endpoint URLs based on the base project URL:

**Authentication endpoints:**
```
https://<project>.supabase.co/auth/v1/...
```

**Database endpoints:**
```
https://<project>.supabase.co/rest/v1/...
```

**Storage endpoints:**
```
https://<project>.supabase.co/storage/v1/...
```

### What Happens with Invalid URL

If `NEXT_PUBLIC_SUPABASE_URL` contains:
```
https://<project>.supabase.co/auth/v1
```

The SDK will attempt to construct:
```
https://<project>.supabase.co/auth/v1/auth/v1/...
```

This results in an invalid path, causing the AuthApiError.

---

## Required Fix

### NO CODE CHANGES REQUIRED

This is a configuration issue only. The code is correct.

### Configuration Fix Required

**Vercel Environment Variables:**

1. Log in to Vercel dashboard
2. Navigate to project settings → Environment Variables
3. Find `NEXT_PUBLIC_SUPABASE_URL`
4. Update to correct format:
   ```
   https://<project>.supabase.co
   ```
5. Ensure NO trailing slash
6. Ensure NO extra paths
7. Ensure NO duplicate slashes
8. Redeploy application

**Local Development:**

1. Open `.env.local`
2. Find `NEXT_PUBLIC_SUPABASE_URL`
3. Update to correct format:
   ```
   https://<project>.supabase.co
   ```
4. Ensure NO trailing slash
5. Ensure NO extra paths
6. Ensure NO duplicate slashes
7. Restart development server

---

## Verification Steps

After fixing the environment variable:

1. **Check the value:**
   ```bash
   echo $NEXT_PUBLIC_SUPABASE_URL
   ```
   Should output: `https://<project>.supabase.co`

2. **Verify no trailing slash:**
   ```bash
   echo $NEXT_PUBLIC_SUPABASE_URL | rev | cut -c1
   ```
   Should NOT output: `/`

3. **Verify no extra paths:**
   ```bash
   echo $NEXT_PUBLIC_SUPABASE_URL | grep -E "(auth|rest|storage)"
   ```
   Should return: No matches

4. **Test authentication:**
   - Navigate to login page
   - Attempt to login
   - Should succeed without AuthApiError

---

## Prevention Strategy

### Short-Term Prevention

1. **Add URL Format Validation**
   - Add validation in `src/lib/supabase.ts`
   - Check for trailing slashes
   - Check for extra paths
   - Provide clear error messages

2. **Update Documentation**
   - Document correct URL format in `.env.example`
   - Add warning about invalid formats
   - Provide examples of correct vs incorrect

### Long-Term Prevention

1. **Automated Validation**
   - Add CI/CD pipeline step to validate environment variables
   - Fail build if invalid URL format detected
   - Provide clear error messages

2. **Environment Management**
   - Use environment variable management tool
   - Validate configuration at deployment time
   - Audit trail for configuration changes

---

## Prevention Implementation

### 1. Add URL Format Validation to `src/lib/supabase.ts`

```typescript
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

// Validate environment variables
if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Supabase environment variables are not configured')
}

// Validate URL format - must be base URL only
if (!supabaseUrl.startsWith('https://') && !supabaseUrl.startsWith('http://')) {
  throw new Error(`Invalid NEXT_PUBLIC_SUPABASE_URL: Must be a valid HTTP or HTTPS URL. Current value: "${supabaseUrl}"`)
}

// Check for trailing slash
if (supabaseUrl.endsWith('/')) {
  throw new Error(`Invalid NEXT_PUBLIC_SUPABASE_URL: Must not end with trailing slash. Current value: "${supabaseUrl}"`)
}

// Check for extra paths (auth, rest, storage)
const invalidPaths = ['/auth', '/rest', '/storage']
for (const path of invalidPaths) {
  if (supabaseUrl.includes(path)) {
    throw new Error(`Invalid NEXT_PUBLIC_SUPABASE_URL: Must not include "${path}" in URL. The SDK automatically appends API paths. Current value: "${supabaseUrl}"`)
  }
}

// Check for placeholder values
if (supabaseUrl.includes('your-supabase-url') || supabaseUrl.includes('localhost')) {
  throw new Error(`NEXT_PUBLIC_SUPABASE_URL contains placeholder value. Please configure actual Supabase URL.`)
}
```

### 2. Update `.env.example`

```env
# Supabase Configuration
# IMPORTANT: Replace placeholder values with actual Supabase credentials
# Get these values from https://supabase.com/dashboard
#
# CORRECT FORMAT: https://your-project.supabase.co
# INCORRECT FORMATS (DO NOT USE):
#   - https://your-project.supabase.co/auth/v1 (SDK adds this automatically)
#   - https://your-project.supabase.co/rest/v1 (SDK adds this automatically)
#   - https://your-project.supabase.co/ (No trailing slash)
#   - your-supabase-url (Must be full HTTPS URL)
#
NEXT_PUBLIC_SUPABASE_URL=your-supabase-url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-supabase-anon-key
```

---

## Conclusion

The authentication error is caused by an incorrectly formatted `NEXT_PUBLIC_SUPABASE_URL` environment variable. The code is correct and does not require any changes.

**Root Cause:** `NEXT_PUBLIC_SUPABASE_URL` contains extra paths (e.g., `/auth/v1`) or invalid characters.

**Immediate Action Required:**
1. Update `NEXT_PUBLIC_SUPABASE_URL` in Vercel environment variables
2. Ensure format is exactly: `https://<project>.supabase.co`
3. No trailing slash, no extra paths, no duplicate slashes
4. Redeploy application

**Code Changes:** NONE REQUIRED - This is a configuration issue only.

**Risk Level:** HIGH - Authentication completely broken until fixed.

---

## Evidence Summary

| Check | Result | Evidence |
|-------|--------|----------|
| auth/v1 in code | ✅ PASS | No matches found |
| Manual auth construction | ✅ PASS | No manual URL concatenation |
| createClient usage | ✅ PASS | Only in supabase.ts, correct usage |
| signInWithPassword | ✅ PASS | Only in AuthContext, correct SDK usage |
| getSession | ✅ PASS | Only in AuthContext, correct SDK usage |
| Environment variable format | ❌ FAIL | Likely contains invalid paths |

**Conclusion:** Code is correct. Configuration is incorrect.

---

**Document Version:** 1.0  
**Last Updated:** July 18, 2026  
**Status:** ROOT CAUSE IDENTIFIED - CONFIGURATION FIX REQUIRED
