-- ═══════════════════════════════════════════════════════════════════
--  Agregar el rol 'produccion' a la tabla profiles
-- ═══════════════════════════════════════════════════════════════════

-- 1) Si no sabes el nombre exacto de la restricción actual, revísalo con:
--    select conname from pg_constraint
--    where conrelid = 'profiles'::regclass and contype = 'c';

alter table profiles drop constraint if exists profiles_rol_check;

alter table profiles
  add constraint profiles_rol_check
  check (rol in ('admin', 'vendedor', 'bodega', 'produccion'));

-- 2) Crear el usuario en Authentication → Users → Add user (como siempre),
--    y luego asignarle el rol acá con su correo real:

insert into profiles (id, email, rol)
select id, email, 'produccion' from auth.users where email = 'CORREO_DE_LA_PERSONA@polchile.cl';
