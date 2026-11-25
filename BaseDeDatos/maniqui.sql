-- Maniquí que se dibuja en el editor de outfits cuando la persona no sube su foto.
-- Se ejecuta en el SQL Editor de Supabase, después de endurecimiento.sql.
-- Se puede ejecutar más de una vez sin problema.

-- 1. Columna nueva. Vale null mientras la persona no elige, y entonces la app dibuja un maniquí neutro
alter table public.perfiles
  add column if not exists maniqui text;

alter table public.perfiles
  drop constraint if exists perfiles_maniqui_valido;

alter table public.perfiles
  add constraint perfiles_maniqui_valido
  check (maniqui is null or maniqui in ('masculino', 'femenino'));

-- 2. Permiso de modificación solo para esta columna. No se da permiso sobre el resto de la tabla
grant update (maniqui) on public.perfiles to authenticated;

-- 3. Cada persona solo puede modificar su propia fila
drop policy if exists perfiles_actualizar_maniqui on public.perfiles;

create policy perfiles_actualizar_maniqui on public.perfiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- Comprobación opcional: debe aparecer maniqui y las columnas que ya tenías permitidas, nada más
-- select column_name
-- from information_schema.column_privileges
-- where table_schema = 'public' and table_name = 'perfiles'
--   and grantee = 'authenticated' and privilege_type = 'UPDATE';
