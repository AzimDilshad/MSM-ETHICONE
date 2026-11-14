import { createClient } from '@supabase/supabase-js';
const url = import.meta.env.VITE_SUPABASE_URL;
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;
export const organisationId = import.meta.env.VITE_ORGANISATION_ID as string | undefined;
export const supabase = url && anonKey ? createClient(url, anonKey) : null;
