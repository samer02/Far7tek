import { createClient } from '@supabase/supabase-js';
import type { Database } from './types';

const EXTERNAL_SUPABASE_URL = 'https://jvvgxtqwjrznkirjrisw.supabase.co';
const EXTERNAL_SUPABASE_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp2dmd4dHF3anJ6bmtpcmpyaXN3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMzMDczMzQsImV4cCI6MjEwODg4MzMzNH0._w-1b-DdlWFbrucROUDQjCJEQmUkoVVn8yu3QC-2wyk';

function cleanEnvUrl(url?: string): string {
  if (!url || url.includes('lovable.cloud')) {
    return EXTERNAL_SUPABASE_URL;
  }
  return url;
}

function cleanEnvKey(key?: string): string {
  if (!key || key.startsWith('sb_publishable_')) {
    return EXTERNAL_SUPABASE_KEY;
  }
  return key;
}

function createSupabaseClient() {
  const envUrl =
    (import.meta as any).env?.['VITE_SUPABASE_URL'] ||
    process.env['VITE_SUPABASE_URL'] ||
    process.env['SUPABASE_URL'];

  const envKey =
    (import.meta as any).env?.['VITE_SUPABASE_PUBLISHABLE_KEY'] ||
    process.env['VITE_SUPABASE_PUBLISHABLE_KEY'] ||
    process.env['SUPABASE_PUBLISHABLE_KEY'];

  const SUPABASE_URL = cleanEnvUrl(envUrl);
  const SUPABASE_PUBLISHABLE_KEY = cleanEnvKey(envKey);

  return createClient<Database>(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
    auth: {
      storage: typeof window !== 'undefined' ? window.localStorage : undefined,
      persistSession: true,
      autoRefreshToken: true,
    },
  });
}

let _supabase: ReturnType<typeof createSupabaseClient> | undefined;

// Import the supabase client like this:
// import { supabase } from "@/integrations/supabase/client";
export const supabase = new Proxy({} as ReturnType<typeof createSupabaseClient>, {
  get(_, prop, receiver) {
    if (!_supabase) _supabase = createSupabaseClient();
    return Reflect.get(_supabase, prop, receiver);
  },
});
