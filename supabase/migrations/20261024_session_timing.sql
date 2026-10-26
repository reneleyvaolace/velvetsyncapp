-- ═══════════════════════════════════════════════════════════════
-- Velvet Sync · tiempo de sesión autoritativo en servidor
-- Añade contabilidad de duración a `shared_sessions` y una función
-- para calcular el tiempo restante sin confiar en el reloj del móvil.
-- Idempotente.
-- ═══════════════════════════════════════════════════════════════

alter table public.shared_sessions
  add column if not exists started_at        timestamptz,
  add column if not exists duration_seconds  integer not null default 0,
  add column if not exists paused_total_ms   bigint  not null default 0,
  add column if not exists paused_at         timestamptz,
  add column if not exists ended_at          timestamptz,
  add column if not exists ended_reason      text;

comment on column public.shared_sessions.started_at is
  'Inicio de la sesión según el reloj del servidor.';
comment on column public.shared_sessions.duration_seconds is
  'Duración contratada en segundos (0 = ilimitada).';
comment on column public.shared_sessions.ended_reason is
  'host_stop | guest_stop | expired | disconnect';

-- Segundos restantes calculados en servidor.
-- Devuelve NULL si la sesión no ha empezado o no existe.
create or replace function public.session_remaining_seconds(p_session uuid)
returns integer
language sql
stable
as $$
  select greatest(
    0,
    s.duration_seconds - (
      extract(epoch from (coalesce(s.ended_at, now()) - s.started_at))::int
      - (s.paused_total_ms / 1000)::int
      - (case
           when s.paused_at is not null
           then extract(epoch from (now() - s.paused_at))::int
           else 0
         end)
    )
  )
  from public.shared_sessions s
  where s.id = p_session
    and s.started_at is not null
    and s.duration_seconds > 0;
$$;

-- Arrancar la cuenta de tiempo desde el host.
-- Devuelve la marca de inicio del servidor para que el cliente no la invente.
create or replace function public.session_start_timing(
  p_session uuid,
  p_duration_seconds integer
)
returns timestamptz
language sql
as $$
  update public.shared_sessions
     set started_at       = coalesce(started_at, now()),
         duration_seconds = p_duration_seconds,
         ended_at         = null,
         ended_reason     = null
   where id = p_session
  returning started_at;
$$;

-- Pausa: congela el reloj. El tiempo en pausa no consume la sesión.
create or replace function public.session_pause_timing(p_session uuid)
returns timestamptz
language sql
as $$
  update public.shared_sessions
     set paused_at = coalesce(paused_at, now())
   where id = p_session
     and ended_at is null
  returning paused_at;
$$;

-- Reanudar: acumula lo pausado y devuelve los segundos restantes.
create or replace function public.session_resume_timing(p_session uuid)
returns integer
language plpgsql
as $$
declare
  v_remaining integer;
begin
  update public.shared_sessions
     set paused_total_ms = paused_total_ms
         + coalesce((extract(epoch from (now() - paused_at)) * 1000)::bigint, 0),
         paused_at = null
   where id = p_session
     and paused_at is not null;

  select coalesce(public.session_remaining_seconds(p_session), 0)
    into v_remaining;

  return v_remaining;
end;
$$;

create or replace function public.session_end_timing(
  p_session uuid,
  p_reason text
)
returns void
language sql
as $$
  update public.shared_sessions
     set ended_at     = now(),
         ended_reason = p_reason,
         is_active    = false
   where id = p_session
     and ended_at is null;
$$;

-- Índice para listar historial por usuario/dispositivo.
create index if not exists shared_sessions_started_at_idx
  on public.shared_sessions (started_at desc);
