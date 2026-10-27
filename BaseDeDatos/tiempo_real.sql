/*
  Gum Armario Virtual
  Sincronización en tiempo real

  Como ejecutarlo: Supabase, SQL Editor, New query, pegar todo y pulsar Run.
  Se puede ejecutar más de una vez sin problema.

  Supabase Realtime solo avisa de los cambios de las tablas que estén dentro de la
  publicación supabase_realtime. Este script agrega las tablas de Gum.

  La seguridad no cambia: para los inserts y los updates, Realtime aplica las mismas
  políticas RLS de cada tabla, así que cada usuario solo recibe avisos de filas que
  puede ver. Limitación documentada de Supabase: los avisos de borrado no pasan por
  RLS, así que cualquier usuario conectado recibe el identificador (uuid) de las filas
  que alguien borró en estas tablas, pero ningún otro dato.
*/

do $$
declare
  tabla text;
begin
  foreach tabla in array array[
    'prendas',
    'outfits',
    'outfit_prendas',
    'amistades',
    'bloqueos',
    'recomendaciones',
    'recomendacion_prendas',
    'perfiles'
  ]
  loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = tabla
    ) then
      execute format('alter publication supabase_realtime add table public.%I', tabla);
    end if;
  end loop;
end
$$;
