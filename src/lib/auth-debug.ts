'use client'

import { createClient } from '@supabase/supabase-js'

const EXPECTED_URL = 'https://ectswacabwnpdvhwqasc.supabase.co'

export function logEnvironment() {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

  console.log('[ENV] NEXT_PUBLIC_SUPABASE_URL:', supabaseUrl)
  console.log('[ENV] URL matches expected:', supabaseUrl === EXPECTED_URL)
  
  const urlMatch = supabaseUrl?.match(/https:\/\/([a-z0-9]+)\.supabase\.co/)
  console.log('[ENV] Project Reference:', urlMatch ? urlMatch[1] : 'INVALID')
  console.log('[ENV] ANON Key (first 20 chars):', supabaseAnonKey ? supabaseAnonKey.substring(0, 20) : 'MISSING')
}

export function logBeforeLogin(email: string, password: string) {
  console.log('[BEFORE LOGIN] Email:', email)
  console.log('[BEFORE LOGIN] Password Length:', password.length)
}

export async function logSignInWithPassword(email: string, password: string) {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

  console.log('[AUTH REQUEST] Target URL:', supabaseUrl)
  console.log('[AUTH REQUEST] Calling signInWithPassword...')

  const client = createClient(supabaseUrl!, supabaseAnonKey!)
  
  const { data, error } = await client.auth.signInWithPassword({ email, password })

  console.log('[AUTH RESPONSE] Data:', data)
  console.log('[AUTH RESPONSE] Error:', error)
  console.log('[AUTH RESPONSE] Status:', error ? error.status : 'SUCCESS')

  return { data, error }
}

export function logAfterLogin(data: any) {
  if (!data?.user) {
    console.log('[AFTER LOGIN] No user in response')
    return
  }

  console.log('[AFTER LOGIN] Session User ID:', data.user.id)
  console.log('[AFTER LOGIN] Session User Email:', data.user.email)
  console.log('[AFTER LOGIN] Access Token Exists:', !!data.session?.access_token)
}

export async function logProfileLookup(userId: string, supabaseUrl: string, supabaseAnonKey: string) {
  console.log('[PROFILE LOOKUP] Querying profiles for user ID:', userId)
  
  const client = createClient(supabaseUrl, supabaseAnonKey)
  
  const { data: profile, error } = await client
    .from('profiles')
    .select('*')
    .eq('id', userId)
    .single()

  console.log('[PROFILE LOOKUP] Result:', profile)
  console.log('[PROFILE LOOKUP] Error:', error)

  return { profile, error }
}
