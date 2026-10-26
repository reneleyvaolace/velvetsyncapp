-- ═══════════════════════════════════════════════════════════════
-- Velvet Sync · catálogo dirigido por datos (P0.1)
-- Añade transporte, banderas y modos a `device_catalog`.
-- Idempotente: se puede ejecutar varias veces.
-- ═══════════════════════════════════════════════════════════════

alter table public.device_catalog
  add column if not exists wireless          text     not null default '',
  add column if not exists barcode           text     not null default '',
  add column if not exists is_encrypt        boolean  not null default false,
  add column if not exists is_ipao           boolean  not null default false,
  add column if not exists new_command       boolean  not null default false,
  add column if not exists private_protocol  boolean  not null default false,
  add column if not exists modes             jsonb    not null default '[]'::jsonb,
  add column if not exists features          jsonb    not null default '[]'::jsonb;

comment on column public.device_catalog.wireless is
  'Transporte: ble (GATT), newble (GATT cifrado) o legacy/2.4G (advertising).';
comment on column public.device_catalog.modes is
  'Lista de modos: [{"id":1,"name":"Onda","code":"11","group":"classic"}]';
comment on column public.device_catalog.features is
  'Capacidades: ["kegel","inflation","video2","battery", ...]';

create index if not exists device_catalog_barcode_idx
  on public.device_catalog (barcode);

-- Backfill de `features` a partir del texto legacy `supported_funcs`.
-- Ajusta la lista si tu catálogo usa otros nombres.
update public.device_catalog
set features = coalesce(
  (
    select jsonb_agg(f)
    from unnest(array['kegel','inflation','discharge','heating','shake','strike',
                      'video','video2','scene','script','music','training',
                      'trends','game','voice','battery']) as f
    where lower(coalesce(supported_funcs, '')) like '%' || f || '%'
  ),
  '[]'::jsonb
)
where (features is null or features = '[]'::jsonb)
  and coalesce(supported_funcs, '') <> '';

-- Ejemplo de modos para un modelo concreto (ajusta el id):
-- update public.device_catalog
-- set modes = '[
--   {"id":1,"name":"Ola","code":"11","group":"classic"},
--   {"id":2,"name":"Pulso","code":"12","group":"classic"},
--   {"id":3,"name":"Pareja","code":"26","group":"time"}
-- ]'::jsonb
-- where id = 'TU_ID';
