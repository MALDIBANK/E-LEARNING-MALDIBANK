// ============================================================
// Fill these in from your Supabase project (Settings > API).
// The anon/public key is safe to expose in client-side code —
// Row Level Security policies (see supabase/schema.sql) are what
// actually protect the data.
// ============================================================
import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm";

export const SUPABASE_URL = "https://zjulpzgjzbinltrbzrho.supabase.co";
export const SUPABASE_ANON_KEY = "sb_publishable_3II9lb4XqHwrItKhDJOSRA_fbmBIfTI";
export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
