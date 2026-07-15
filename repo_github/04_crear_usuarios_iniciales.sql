-- ═══════════════════════════════════════════════════════════════════
--  Asignar nombre y rol a los usuarios nuevos
--  PRE-REQUISITO: cada correo ya debe existir en Authentication → Users
--  (créalos ahí primero, con su contraseña). Si un correo no existe
--  todavía, esa fila simplemente no se inserta — sin error.
-- ═══════════════════════════════════════════════════════════════════

insert into profiles (id, email, nombre, rol)
select id, email, 'Alexis Urquiza', 'produccion' from auth.users where email = 'aurquiza@polchile.cl'
union all
select id, email, 'Melysa Jiménez', 'vendedor' from auth.users where email = 'mjimenez@polchile.cl'
union all
select id, email, 'Óscar Paredes', 'vendedor' from auth.users where email = 'oparedes@polchile.cl'
union all
select id, email, 'Orlando Armas', 'vendedor' from auth.users where email = 'oarmas@polchile.cl'
union all
select id, email, 'Hernán Paulsen', 'vendedor' from auth.users where email = 'hpaulsen@polchile.cl'
on conflict (id) do update
  set nombre = excluded.nombre,
      rol    = excluded.rol;

-- Verificación: revisa que los 5 hayan quedado con su rol correcto
select email, nombre, rol from profiles order by rol, nombre;
