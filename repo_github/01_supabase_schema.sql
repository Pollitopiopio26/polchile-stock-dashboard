-- ═══════════════════════════════════════════════════════════════════
--  FASE 1 · Esquema inicial · Control de Stock Polchile en Supabase
-- ═══════════════════════════════════════════════════════════════════

-- 1) CATÁLOGO (equivalente a la pestaña "Catalogo")
create table if not exists catalogo (
  codigo       text primary key,
  producto     text not null,
  familia      text not null default 'Sin familia',
  tipo         text default '',
  precio       numeric default 0,
  stock_total  numeric default 0,
  actualizado  timestamptz default now()
);

-- 2) STOCK POR BODEGA (equivalente a la pestaña "Stock", primera calidad)
create table if not exists stock (
  codigo        text not null,
  bodega_nombre text not null,
  nombre        text default '',
  unidmed       text default '',
  stk_fisico    numeric default 0,
  actualizado   timestamptz default now(),
  primary key (codigo, bodega_nombre)
);

-- 3) PRODUCTOS DE SEGUNDA (equivalente a la pestaña "Productos Segunda")
create table if not exists productos_segunda (
  codigo        text not null,
  bodega_nombre text not null,
  nombre        text default '',
  unidmed       text default '',
  stk_fisico    numeric default 0,
  actualizado   timestamptz default now(),
  primary key (codigo, bodega_nombre)
);

-- 4) PERFILES DE USUARIO (rol + vista asignada)
-- rol: 'admin' (ve todo) | 'vendedor' (ve precios/familias, sin desglose de bodega) | 'bodega' (ve solo su bodega)
create table if not exists profiles (
  id              uuid primary key references auth.users(id) on delete cascade,
  email           text,
  nombre          text,
  rol             text not null default 'vendedor' check (rol in ('admin','vendedor','bodega')),
  bodega_asignada text, -- solo se usa si rol = 'bodega'
  creado          timestamptz default now()
);

-- ─────────────────────────────────────────────────────────────────
--  SEGURIDAD (Row Level Security)
-- ─────────────────────────────────────────────────────────────────

alter table catalogo           enable row level security;
alter table stock               enable row level security;
alter table productos_segunda   enable row level security;
alter table profiles            enable row level security;

-- Cualquier usuario AUTENTICADO puede leer catálogo y stock.
-- (Más adelante, cuando confirmemos las reglas finales por rol,
--  acá se agregan políticas más finas — ej. que 'bodega' solo vea su fila.)
create policy "catalogo_lectura_autenticados"
  on catalogo for select
  to authenticated
  using (true);

create policy "stock_lectura_autenticados"
  on stock for select
  to authenticated
  using (true);

create policy "segunda_lectura_autenticados"
  on productos_segunda for select
  to authenticated
  using (true);

-- Cada usuario puede leer SU PROPIO perfil (para saber su rol al hacer login)
create policy "perfil_propio"
  on profiles for select
  to authenticated
  using (auth.uid() = id);

-- Nadie puede escribir estas tablas desde el navegador (ni con login).
-- Solo el backend de sincronización (Apps Script, con la service_role key)
-- podrá insertar/actualizar — esa key nunca se expone al frontend.
