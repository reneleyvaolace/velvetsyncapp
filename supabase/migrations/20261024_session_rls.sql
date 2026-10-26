-- ═══════════════════════════════════════════════════════════════
-- Velvet Sync · RLS para sesiones compartidas
--
-- ⚠️ PRERREQUISITO: aplica esta migración SOLO cuando la app tenga
-- autenticación real (Supabase Auth con `signIn`), es decir, cuando
-- `auth.uid()` devuelva un usuario. Si la app usa la anon key sin
-- login, activar RLS aquí romperá la creación/unión de sesiones.
--
-- Mientras no se aplique, las sesiones siguen funcionando como hoy.
-- ═══════════════════════════════════════════════════════════════

-- 1) Dueño de la sesión
alter table public.shared_sessions
  add column if not exists host_user_id uuid default auth.uid();

create index if not exists shared_sessions_host_idx
  on public.shared_sessions (host_user_id);

-- 2) Unión por token sin exponer la tabla a anon.
--    SECURITY DEFINER: valida el token y devuelve solo esa fila.
create or replace function public.join_session_by_token(p_token text)
returns setof public.shared_sessions
language sql
security definer
set search_path = public
as $$
  select *
    from public.shared_sessions
   where access_token = p_token
     and is_active
     and (expires_at is null or expires_at > now())
   limit 1;
$$;

revoke all on function public.join_session_by_token(text) from public;
grant execute on function public.join_session_by_token(text) to anon, authenticated;

-- 3) RLS
alter table public.shared_sessions enable row level security;

drop policy if exists "sessions_owner_select" on public.shared_sessions;
create policy "sessions_owner_select" on public.shared_sessions
  for select to authenticated
  using (host_user_id = auth.uid());

drop policy if exists "sessions_owner_insert" on public.shared_sessions;
create policy "sessions_owner_insert" on public.shared_sessions
  for insert to authenticated
  with check (host_user_id = auth.uid());

drop policy if exists "sessions_owner_update" on public.shared_sessions;
create policy "sessions_owner_update" on public.shared_sessions
  for update to authenticated
  using (host_user_id = auth.uid())
  with check (host_user_id = auth.uid());

drop policy if exists "sessions_owner_delete" on public.shared_sessions;
create policy "sessions_owner_delete" on public.shared_sessions
  for delete to authenticated
  using (host_user_id = auth.uid());

-- 4) Historial: solo el dueño ve sus sesiones cerradas.
--    (La política select de arriba ya lo cubre; este comentario documenta
--     que `fetchSessionHistory` filtra por ended_at, no por usuario.)
