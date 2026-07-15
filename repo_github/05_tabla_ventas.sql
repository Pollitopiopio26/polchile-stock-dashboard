-- ═══════════════════════════════════════════════════════════════════
--  Tabla de ventas (desde la hoja "Stock Vendido") + acceso solo Admin
-- ═══════════════════════════════════════════════════════════════════

create table if not exists ventas (
  nota_de_venta  integer not null,
  bodega_id      text default '',
  bodega_nombre  text default '',
  codigo         text not null,
  descripcion    text default '',
  unidmed        text default '',
  cantidad       numeric default 0,
  valor_total    numeric default 0,
  fecha          date,
  actualizado    timestamptz default now(),
  primary key (nota_de_venta, codigo, bodega_id)
);

create index if not exists ventas_codigo_idx on ventas (codigo);
create index if not exists ventas_fecha_idx on ventas (fecha);

alter table ventas enable row level security;

-- Solo usuarios con rol 'admin' pueden leer esta tabla — vendedor y
-- producción no la ven ni aunque intenten consultarla directo desde el
-- navegador (queda bloqueado a nivel de base de datos, no solo de UI).
create policy "ventas_solo_admin"
  on ventas for select
  to authenticated
  using (
    exists (
      select 1 from profiles p
      where p.id = auth.uid() and p.rol = 'admin'
    )
  );
