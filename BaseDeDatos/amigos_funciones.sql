/*
  Gum Armario Virtual
  Funciones del módulo de amigos

  Como ejecutarlo: Supabase, SQL Editor, New query, pegar todo y pulsar Run.
  Se puede ejecutar más de una vez sin problema.

  Por que hacen falta: las políticas RLS solo dejan ver el perfil de los amigos
  ya confirmados. Una solicitud pendiente todavía no es amistad, así que estas
  funciones leen el nombre y el correo de la otra persona de forma controlada,
  mostrando únicamente a quienes están relacionados contigo.
*/

/* Amistades del usuario actual (pendientes y aceptadas) con los datos de la otra persona */
create or replace function mis_amistades()
returns table (
  id uuid,
  estado estado_amistad,
  soy_solicitante boolean,
  otro_id uuid,
  otro_email text,
  otro_nombre text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    a.id,
    a.estado,
    (a.solicitante_id = auth.uid()) as soy_solicitante,
    p.id as otro_id,
    p.email as otro_email,
    p.nombre as otro_nombre
  from amistades a
  join perfiles p
    on p.id = case when a.solicitante_id = auth.uid() then a.destinatario_id else a.solicitante_id end
  where (a.solicitante_id = auth.uid() or a.destinatario_id = auth.uid())
    and a.estado <> 'rechazada'
  order by a.created_at desc;
$$;

/* Usuarios que el usuario actual ha bloqueado */
create or replace function mis_bloqueos()
returns table (
  bloqueado_id uuid,
  email text,
  nombre text
)
language sql
stable
security definer
set search_path = public
as $$
  select b.bloqueado_id, p.email, p.nombre
  from bloqueos b
  join perfiles p on p.id = b.bloqueado_id
  where b.bloqueador_id = auth.uid()
  order by b.created_at desc;
$$;

/* Solo usuarios autenticados pueden ejecutarlas */
revoke execute on function mis_amistades() from public, anon;
revoke execute on function mis_bloqueos() from public, anon;
grant execute on function mis_amistades() to authenticated;
grant execute on function mis_bloqueos() to authenticated;
