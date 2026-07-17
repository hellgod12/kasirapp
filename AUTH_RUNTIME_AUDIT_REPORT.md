# Authentication Runtime Audit Report

**Report Date:** July 18, 2026  
**Error:** AuthApiError: Invalid login credentials  
**Status:** Runtime Verification Required

---

## Critical Findings from Code Audit

### Finding 1: Supabase Client Initialization (src/lib/supabase.ts)

**Code Analysis:**
```typescript
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

let _supabase: SupabaseClient | null = null

export const supabase = new Proxy({} as SupabaseClient, {
  get(_target, prop) {
    if (!_supabase) {
      if (!supabaseUrl || !supabaseAnonKey) {
        throw new Error('Supabase environment variables are not configured')
      }
      _supabase = createClient(supabaseUrl, supabaseAnonKey)
    }
    return _supabase[prop as keyof SupabaseClient]
  }
})
```

**Issues Identified:**
- ✅ Singleton pattern is correct (lazy initialization)
- ✅ Error thrown if env vars missing
- ⚠️ **NO RUNTIME LOGGING** - Cannot see what URL/Key is actually used
- ⚠️ **NO VALIDATION** - Does not verify URL/Key belong to same project

### Finding 2: Login Implementation (src/contexts/AuthContext.tsx)

**Code Analysis:**
```typescript
const login = async (email: string, password: string) => {
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  })

  if (error) throw error

  if (data.user) {
    await fetchUserProfile(data.user)
  }
}
```

**Issues Identified:**
- ✅ No email/password transformation (no trim, no modification)
- ✅ Direct pass-through to Supabase
- ⚠️ **NO RUNTIME LOGGING** - Cannot see what email/password is actually sent
- ⚠️ **NO ERROR DETAILS LOGGED** - Only throws error without context

### Finding 3: Login Page (src/app/login/page.tsx)

**Code Analysis:**
```typescript
const handleSubmit = async (e: React.FormEvent) => {
  e.preventDefault()
  setError('')
  setLoading(true)

  try {
    await login(email, password)
    router.push('/dashboard')
  } catch (err) {
    console.error('LOGIN PAGE ERROR:', err)
    if (err instanceof Error) {
      setError(`Login gagal: ${err.message}`)
    } else {
      setError('Login gagal: Error tidak diketahui')
    }
  } finally {
    setLoading(false)
  }
}
```

**Issues Identified:**
- ✅ Error is displayed to user
- ✅ Console error logging exists
- ⚠️ **NO RUNTIME VALUE LOGGING** - Cannot see actual email/password values
- ⚠️ **NO SUPABASE CLIENT INFO LOGGED** - Cannot see which project is being used

### Finding 4: Middleware

**Result:** No middleware.ts file found in project root or src directory.

**Conclusion:** No middleware interception of authentication.

---

## Root Cause Hypotheses

### Hypothesis 1: Wrong Supabase Project URL
**Probability:** HIGH  
**Evidence:** No runtime logging to verify URL  
**Impact:** signInWithPassword() calls wrong project, user doesn't exist there

### Hypothesis 2: Wrong ANON Key
**Probability:** HIGH  
**Evidence:** No validation that ANON key belongs to same project as URL  
**Impact:** Authentication fails due to key mismatch

### Hypothesis 3: Email/Password Case Sensitivity
**Probability:** MEDIUM  
**Evidence:** User confirmed admin@kasirapp.com exists  
**Impact:** Case mismatch in email or password

### Hypothesis 4: Stale Session/Cookie
**Probability:** LOW  
**Evidence:** No middleware, but localStorage may have stale data  
**Impact:** Session conflicts

---

## Runtime Verification Script

Create a new file: `src/lib/auth-debug.ts`

```typescript
'use client'

import { createClient } from '@supabase/supabase-js'

export function debugAuthConfig() {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

  console.log('=== AUTH DEBUG INFO ===')
  console.log('Supabase URL:', supabaseUrl)
  console.log('Supabase URL Type:', typeof supabaseUrl)
  console.log('Supabase URL Length:', supabaseUrl?.length)
  console.log('Supabase ANON Key:', supabaseAnonKey ? `${supabaseAnonKey.substring(0, 10)}...` : 'MISSING')
  console.log('Supabase ANON Key Type:', typeof supabaseAnonKey)
  console.log('Supabase ANON Key Length:', supabaseAnonKey?.length)
  
  // Extract project reference from URL
  if (supabaseUrl) {
    const urlMatch = supabaseUrl.match(/https:\/\/([a-z0-9]+)\.supabase\.co/)
    if (urlMatch) {
      console.log('Project Reference:', urlMatch[1])
    } else {
      console.log('Project Reference: INVALID URL FORMAT')
    }
  }
  
  console.log('=====================')
}

export async function debugLoginAttempt(email: string, password: string) {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

  console.log('=== LOGIN ATTEMPT DEBUG ===')
  console.log('Email:', email)
  console.log('Email Type:', typeof email)
  console.log('Email Length:', email.length)
  console.log('Email Trimmed:', email.trim())
  console.log('Email Lowercase:', email.toLowerCase())
  console.log('Password Length:', password.length)
  console.log('Password Type:', typeof password)
  console.log('Password Trimmed:', password.trim())
  console.log('==========================')

  if (!supabaseUrl || !supabaseAnonKey) {
    console.error('MISSING ENV VARS')
    return
  }

  const client = createClient(supabaseUrl, supabaseAnonKey)
  
  console.log('Calling signInWithPassword...')
  const { data, error } = await client.auth.signInWithPassword({
    email,
    password,
  })

  console.log('Response Data:', data)
  console.log('Response Error:', error)
  
  if (error) {
    console.error('Error Name:', error.name)
    console.error('Error Message:', error.message)
    console.error('Error Status:', error.status)
    console.error('Error Code:', (error as any).code)
  }

  console.log('==========================')
  
  return { data, error }
}

export function debugLocalStorage() {
  console.log('=== LOCAL STORAGE DEBUG ===')
  
  // Check for Supabase session
  const session = localStorage.getItem('supabase.auth.token')
  console.log('Supabase Session:', session ? 'EXISTS' : 'NOT FOUND')
  
  // Check for any auth-related keys
  for (let i = 0; i < localStorage.length; i++) {
    const key = localStorage.key(i)
    if (key?.includes('supabase') || key?.includes('auth')) {
      console.log(`Key: ${key}`)
    }
  }
  
  console.log('==========================')
}
```

---

## Modified Login Page with Debug Logging

Replace `src/app/login/page.tsx` with this version temporarily:

```typescript
'use client'

import { useState } from 'react'
import { useAuth } from '@/contexts/AuthContext'
import { useRouter } from 'next/navigation'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Loader2, Cake } from 'lucide-react'
import { debugAuthConfig, debugLoginAttempt, debugLocalStorage } from '@/lib/auth-debug'

export default function LoginPage() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const { login } = useAuth()
  const router = useRouter()

  // Debug: Log config on mount
  useState(() => {
    debugAuthConfig()
    debugLocalStorage()
  })

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setLoading(true)

    try {
      // Debug: Log login attempt
      console.log('=== FORM SUBMISSION ===')
      console.log('Email from form:', email)
      console.log('Password from form:', password ? '***' + password.slice(-2) : 'EMPTY')
      
      // Debug: Test with direct Supabase call
      const debugResult = await debugLoginAttempt(email, password)
      
      if (debugResult.error) {
        throw debugResult.error
      }
      
      // If debug succeeds, try normal login
      await login(email, password)
      router.push('/dashboard')
    } catch (err) {
      console.error('LOGIN PAGE ERROR:', err)
      if (err instanceof Error) {
        setError(`Login gagal: ${err.message}`)
      } else {
        setError('Login gagal: Error tidak diketahui')
      }
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-orange-50 via-white to-cream p-4">
      <Card className="w-full max-w-md shadow-xl">
        <CardHeader className="space-y-4 text-center">
          <div className="flex justify-center">
            <div className="w-16 h-16 bg-gradient-to-br from-orange-500 to-red-500 rounded-2xl flex items-center justify-center shadow-lg">
              <Cake className="w-8 h-8 text-white" />
            </div>
          </div>
          <CardTitle className="text-3xl font-bold text-gray-800">KasirApp</CardTitle>
          <CardDescription className="text-gray-600">
            Masuk untuk mengelola toko Anda
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <label htmlFor="email" className="text-sm font-medium text-gray-700">
                Email
              </label>
              <Input
                id="email"
                type="email"
                placeholder="your@email.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                className="h-11"
              />
            </div>
            <div className="space-y-2">
              <label htmlFor="password" className="text-sm font-medium text-gray-700">
                Password
              </label>
              <Input
                id="password"
                type="password"
                placeholder="••••••••"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                className="h-11"
              />
            </div>
            {error && (
              <div className="p-3 bg-red-50 border border-red-200 rounded-lg text-red-600 text-sm">
                {error}
              </div>
            )}
            <Button
              type="submit"
              className="w-full h-11 bg-gradient-to-r from-orange-500 to-red-500 hover:from-orange-600 hover:to-red-600 text-white font-medium shadow-md"
              disabled={loading}
            >
              {loading ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Masuk...
                </>
              ) : (
                'Masuk'
              )}
            </Button>
          </form>
        </CardContent>
      </Card>
    </div>
  )
}
```

---

## Verification Steps

### Step 1: Create debug file
Create `src/lib/auth-debug.ts` with the code above.

### Step 2: Modify login page
Replace `src/app/login/page.tsx` with the debug version above.

### Step 3: Run development server
```bash
npm run dev
```

### Step 4: Open browser console
Press F12 to open browser developer tools and go to Console tab.

### Step 5: Attempt login
Enter credentials and click "Masuk".

### Step 6: Review console output
Look for:
- `=== AUTH DEBUG INFO ===` section
- Actual Supabase URL being used
- Project reference extracted from URL
- ANON key prefix
- Email and password values being sent
- Supabase response details

### Step 7: Compare with Supabase Dashboard
1. Open Supabase Dashboard
2. Go to Settings → API
3. Compare Project URL with console output
4. Compare ANON key with console output

---

## Expected Console Output

### If URL/Key are correct:
```
=== AUTH DEBUG INFO ===
Supabase URL: https://your-project-ref.supabase.co
Project Reference: your-project-ref
Supabase ANON Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
=====================
```

### If URL/Key are wrong:
```
=== AUTH DEBUG INFO ===
Supabase URL: https://wrong-project.supabase.co
Project Reference: wrong-project
Supabase ANON KEY: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
=====================
```

### If login fails:
```
=== LOGIN ATTEMPT DEBUG ===
Email: admin@kasirapp.com
Password Length: 12
Response Error: AuthApiError: Invalid login credentials
Error Status: 400
Error Code: invalid_credentials
==========================
```

---

## Root Cause Determination

### If Project Reference Mismatch:
**Root Cause:** Application connecting to wrong Supabase project  
**Fix:** Update `.env.local` with correct URL and ANON key

### If ANON Key Mismatch:
**Root Cause:** ANON key belongs to different project  
**Fix:** Update `.env.local` with correct ANON key

### If Email Case Mismatch:
**Root Cause:** Email case sensitivity issue  
**Fix:** Ensure email matches exactly (including case)

### If Password Issue:
**Root Cause:** Password incorrect or user needs reset  
**Fix:** Reset password in Supabase Dashboard

---

## Next Actions

1. Create `src/lib/auth-debug.ts`
2. Modify `src/app/login/page.tsx` with debug logging
3. Run dev server and attempt login
4. Review console output
5. Compare with Supabase Dashboard settings
6. Identify exact mismatch
7. Fix `.env.local` accordingly
8. Remove debug code after fix

---

**Report Completed:** July 18, 2026  
**Status:** Awaiting Runtime Verification Results
