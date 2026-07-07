-- ═══════════════════════════════════════════════════════════════
-- Velvet Sync · Supabase Migration 001: Init
-- ═══════════════════════════════════════════════════════════════

-- 1. PROFILES
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username VARCHAR(20) UNIQUE NOT NULL CHECK (username ~ '^[a-zA-Z0-9_]{3,20}$'),
  display_name VARCHAR(50) NOT NULL,
  avatar_url TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  last_seen_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_profiles_username ON profiles(username);
CREATE INDEX IF NOT EXISTS idx_profiles_display_name ON profiles(display_name);
CREATE INDEX IF NOT EXISTS idx_profiles_last_seen ON profiles(last_seen_at);

-- 2. CONTACTS
CREATE TABLE IF NOT EXISTS contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  contact_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, contact_user_id)
);
CREATE INDEX IF NOT EXISTS idx_contacts_user_id ON contacts(user_id);

-- 3. SESSION INVITES
CREATE TABLE IF NOT EXISTS session_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id TEXT NOT NULL,
  from_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  to_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  access_token TEXT NOT NULL,
  device_id TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'expired')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_invites_to_user ON session_invites(to_user_id, status);
CREATE INDEX IF NOT EXISTS idx_invites_from_user ON session_invites(from_user_id, status);

-- ═══════════════════════════════════════════════════════════════
-- 4. INACTIVIDAD: Deshabilitar cuentas inactivas
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION deactivate_inactive_accounts(days_threshold INT DEFAULT 90)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  deactivated_count INT;
BEGIN
  UPDATE profiles
  SET is_active = FALSE
  WHERE is_active = TRUE
    AND last_seen_at < NOW() - (days_threshold || ' days')::INTERVAL;

  GET DIAGNOSTICS deactivated_count = ROW_COUNT;
  RETURN deactivated_count;
END;
$$;

-- Programar ejecución diaria (requiere pg_cron habilitado en Supabase)
-- SELECT cron.schedule('deactivate-inactive-accounts', '0 3 * * *', $$SELECT deactivate_inactive_accounts(90);$$);

-- ═══════════════════════════════════════════════════════════════
-- 5. EDGE FUNCTION: delete-user (desplegar en Supabase dashboard)
-- ═══════════════════════════════════════════════════════════════
-- Crea una función en Supabase > Edge Functions > delete-user > index.ts:
--
-- import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
-- 
-- Deno.serve(async (req) => {
--   const authHeader = req.headers.get('Authorization')
--   const { user_id } = await req.json()
--   
--   const supabase = createClient(
--     Deno.env.get('SUPABASE_URL')!,
--     Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
--   )
--   
--   const { data: { user }, error: getUserError } = await supabase.auth.admin.getUserById(user_id)
--   if (getUserError || !user) {
--     return new Response(JSON.stringify({ error: 'User not found' }), { status: 404 })
--   }
--   
--   const { error: deleteError } = await supabase.auth.admin.deleteUser(user_id)
--   if (deleteError) {
--     return new Response(JSON.stringify({ error: deleteError.message }), { status: 500 })
--   }
--   
--   return new Response(JSON.stringify({ success: true }), { status: 200 })
-- })
