import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || ''
const supabasePublishableKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY || ''

const isConfigured = Boolean(
  supabaseUrl &&
  supabasePublishableKey &&
  !supabaseUrl.includes('your-project-ref') &&
  !supabasePublishableKey.includes('your-supabase-publishable-key')
)

window.isSupabaseConfigured = isConfigured

if (isConfigured) {
  try {
    window.gymSupabase = createClient(supabaseUrl, supabasePublishableKey)
  } catch (err) {
    console.warn('Could not initialize Supabase client:', err)
    window.gymSupabase = null
    window.isSupabaseConfigured = false
  }
} else {
  window.gymSupabase = null
  console.info('PowerFit: Running in Local Demo Mode (configure .env with real Supabase credentials to sync with database).')
}

window.initializeGymSupabase?.()

