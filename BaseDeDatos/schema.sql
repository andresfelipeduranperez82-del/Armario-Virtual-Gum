/*
  Gum Armario Virtual
  Modelo de datos para Supabase (PostgreSQL)

*/

/* ========== TIPOS ========== */

create type categoria_prenda as enum
  ('superior', 'inferior', 'calzado', 'cuerpo_completo', 'abrigo', 'accesorios');

create type estilo_prenda as enum
  ('casual', 'formal', 'deportivo', 'fiesta');

create type estado_amistad as enum
  ('pendiente', 'aceptada', 'rechazada');

create type estado_recomendacion as enum
  ('pendiente', 'aceptada', 'descartada');

/* ========== TABLAS ========== */

create table perfiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null unique,
  nombre text,
  foto_personal_path text,  /* si es null se usa el modelo neutro */
  created_at timestamptz not null default now()
);

create table prendas (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references perfiles (id) on delete cascade,
  imagen_path text not null,
  categoria categoria_prenda not null,
  color_principal text not null check (length(trim(color_principal)) > 0),
  estilo estilo_prenda not null,
  created_at timestamptz not null default now()
);
create index prendas_user_categoria_idx on prendas (user_id, categoria);

create table outfits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references perfiles (id) on delete cascade,
  nombre text not null check (length(trim(nombre)) > 0),
  estilo estilo_prenda not null,
  created_at timestamptz not null default now()
);
create index outfits_user_idx on outfits (user_id);

create table outfit_prendas (
  outfit_id uuid not null references outfits (id) on delete cascade,
  prenda_id uuid not null references prendas (id) on delete cascade,
  primary key (outfit_id, prenda_id)
);
create index outfit_prendas_prenda_idx on outfit_prendas (prenda_id);

create table amistades (
  id uuid primary key default gen_random_uuid(),
  solicitante_id uuid not null references perfiles (id) on delete cascade,
  destinatario_id uuid not null references perfiles (id) on delete cascade,
  estado estado_amistad not null default 'pendiente',
  created_at timestamptz not null default now(),
  check (solicitante_id <> destinatario_id)
);
/* evita solicitudes duplicadas en cualquier direccion */
create unique index amistades_par_unico on amistades (
  least(solicitante_id, destinatario_id),
  greatest(solicitante_id, destinatario_id)
);

create table bloqueos (
  bloqueador_id uuid not null references perfiles (id) on delete cascade,
  bloqueado_id uuid not null references perfiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (bloqueador_id, bloqueado_id),
  check (bloqueador_id <> bloqueado_id)
);

create table recomendaciones (
  id uuid primary key default gen_random_uuid(),
  remitente_id uuid not null references perfiles (id) on delete cascade,
  destinatario_id uuid not null references perfiles (id) on delete cascade,
  nombre text not null check (length(trim(nombre)) > 0),
  estilo estilo_prenda not null,
  estado estado_recomendacion not null default 'pendiente',
  created_at timestamptz not null default now(),
  check (remitente_id <> destinatario_id)
);
create index recomendaciones_destinatario_idx on recomendaciones (destinatario_id, estado);

create table recomendacion_prendas (
  recomendacion_id uuid not null references recomendaciones (id) on delete cascade,
  prenda_id uuid not null references prendas (id) on delete cascade,
  primary key (recomendacion_id, prenda_id)
);

/* ========== FUNCIONES AUXILIARES ========== */

/* Devuelve true si el usuario actual y p_otro son amigos confirmados y no hay bloqueo */
create or replace function es_amigo(p_otro uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from amistades a
    where a.estado = 'aceptada'
      and ((a.solicitante_id = auth.uid() and a.destinatario_id = p_otro)
        or (a.solicitante_id = p_otro and a.destinatario_id = auth.uid()))
  )
  and not exists (
    select 1 from bloqueos b
    where (b.bloqueador_id = auth.uid() and b.bloqueado_id = p_otro)
       or (b.bloqueador_id = p_otro and b.bloqueado_id = auth.uid())
  );
$$;

/* Crea el perfil automaticamente cuando alguien inicia sesion por primera vez */
create or replace function handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into perfiles (id, email, nombre)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1))
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

/* Regla RN: al eliminar una prenda se eliminan los outfits que la contienen */
create or replace function eliminar_outfits_de_prenda()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from outfits
  where id in (select outfit_id from outfit_prendas where prenda_id = old.id);
  return old;
end;
$$;

create trigger prendas_eliminar_outfits
  before delete on prendas
  for each row execute function eliminar_outfits_de_prenda();

/* Para mostrar: "Esta prenda esta en X outfits, que tambien se eliminaran" */
create or replace function contar_outfits_de_prenda(p_prenda uuid)
returns integer
language sql
stable
set search_path = public
as $$
  select count(distinct op.outfit_id)::integer
  from outfit_prendas op
  join outfits o on o.id = op.outfit_id
  where op.prenda_id = p_prenda and o.user_id = auth.uid();
$$;

/* ========== FUNCIONES DE NEGOCIO (se llaman con supabase.rpc) ========== */

/* Crea un outfit validando las reglas de combinacion */
create or replace function crear_outfit(
  p_nombre text,
  p_estilo estilo_prenda,
  p_prendas uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ids uuid[];
  v_propias integer;
  v_sup integer;
  v_inf integer;
  v_cuerpo integer;
  v_outfit uuid;
begin
  if auth.uid() is null then
    raise exception 'Debes iniciar sesion';
  end if;
  if p_nombre is null or length(trim(p_nombre)) = 0 then
    raise exception 'El outfit debe tener un nombre';
  end if;

  select array(select distinct unnest(p_prendas)) into v_ids;

  select count(*),
         count(*) filter (where categoria = 'superior'),
         count(*) filter (where categoria = 'inferior'),
         count(*) filter (where categoria = 'cuerpo_completo')
    into v_propias, v_sup, v_inf, v_cuerpo
  from prendas
  where id = any (v_ids) and user_id = auth.uid();

  if v_propias = 0 or v_propias <> cardinality(v_ids) then
    raise exception 'Todas las prendas deben existir y ser tuyas';
  end if;

  if not ((v_sup >= 1 and v_inf >= 1) or v_cuerpo >= 1) then
    raise exception 'Combinacion invalida: se requiere superior e inferior, o cuerpo completo';
  end if;

  if exists (
    select 1 from prendas
    where id = any (v_ids)
    group by categoria
    having categoria <> 'accesorios' and count(*) > 1
  ) then
    raise exception 'Solo se permite una prenda por categoria, excepto accesorios';
  end if;

  insert into outfits (user_id, nombre, estilo)
  values (auth.uid(), trim(p_nombre), p_estilo)
  returning id into v_outfit;

  insert into outfit_prendas (outfit_id, prenda_id)
  select v_outfit, unnest(v_ids);

  return v_outfit;
end;
$$;

/* Envia una solicitud de amistad por correo, con las validaciones del documento */
create or replace function enviar_solicitud(p_email text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_dest uuid;
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Debes iniciar sesion';
  end if;

  select id into v_dest from perfiles where lower(email) = lower(trim(p_email));
  if v_dest is null then
    raise exception 'Ese correo no esta registrado';
  end if;
  if v_dest = auth.uid() then
    raise exception 'No puedes agregarte a ti mismo';
  end if;
  if exists (
    select 1 from bloqueos
    where (bloqueador_id = v_dest and bloqueado_id = auth.uid())
       or (bloqueador_id = auth.uid() and bloqueado_id = v_dest)
  ) then
    raise exception 'No es posible enviar la solicitud a este usuario';
  end if;
  if exists (
    select 1 from amistades
    where (solicitante_id = auth.uid() and destinatario_id = v_dest)
       or (solicitante_id = v_dest and destinatario_id = auth.uid())
  ) then
    raise exception 'Ya existe una solicitud o amistad con este usuario';
  end if;

  insert into amistades (solicitante_id, destinatario_id)
  values (auth.uid(), v_dest)
  returning id into v_id;

  return v_id;
end;
$$;

/* Bloquea a un usuario y elimina la amistad si existia */
create or replace function bloquear_usuario(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Debes iniciar sesion';
  end if;
  if p_id = auth.uid() then
    raise exception 'No puedes bloquearte a ti mismo';
  end if;

  insert into bloqueos (bloqueador_id, bloqueado_id)
  values (auth.uid(), p_id)
  on conflict do nothing;

  delete from amistades
  where (solicitante_id = auth.uid() and destinatario_id = p_id)
     or (solicitante_id = p_id and destinatario_id = auth.uid());
end;
$$;

/* Acepta una recomendacion: crea el outfit en la coleccion del usuario */
create or replace function aceptar_recomendacion(p_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  r recomendaciones;
  v_ids uuid[];
  v_outfit uuid;
begin
  select * into r
  from recomendaciones
  where id = p_id and destinatario_id = auth.uid() and estado = 'pendiente';

  if not found then
    raise exception 'Recomendacion no encontrada o ya resuelta';
  end if;

  select array_agg(prenda_id) into v_ids
  from recomendacion_prendas
  where recomendacion_id = p_id;

  v_outfit := crear_outfit(r.nombre, r.estilo, v_ids);

  update recomendaciones set estado = 'aceptada' where id = p_id;

  return v_outfit;
end;
$$;

/* Solo usuarios autenticados pueden ejecutar las funciones de negocio */
revoke execute on function crear_outfit(text, estilo_prenda, uuid[]) from public, anon;
revoke execute on function enviar_solicitud(text) from public, anon;
revoke execute on function bloquear_usuario(uuid) from public, anon;
revoke execute on function aceptar_recomendacion(uuid) from public, anon;
revoke execute on function es_amigo(uuid) from public, anon;
revoke execute on function contar_outfits_de_prenda(uuid) from public, anon;
grant execute on function crear_outfit(text, estilo_prenda, uuid[]) to authenticated;
grant execute on function enviar_solicitud(text) to authenticated;
grant execute on function bloquear_usuario(uuid) to authenticated;
grant execute on function aceptar_recomendacion(uuid) to authenticated;
grant execute on function es_amigo(uuid) to authenticated;
grant execute on function contar_outfits_de_prenda(uuid) to authenticated;

/* ========== ROW LEVEL SECURITY ========== */

alter table perfiles enable row level security;
alter table prendas enable row level security;
alter table outfits enable row level security;
alter table outfit_prendas enable row level security;
alter table amistades enable row level security;
alter table bloqueos enable row level security;
alter table recomendaciones enable row level security;
alter table recomendacion_prendas enable row level security;

/* perfiles */
create policy perfiles_select on perfiles for select to authenticated
  using (id = auth.uid() or es_amigo(id));
create policy perfiles_update on perfiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

/* prendas */
create policy prendas_select_propias on prendas for select to authenticated
  using (user_id = auth.uid());

/* Opcion A (activa): los amigos confirmados pueden ver las prendas */
create policy prendas_select_amigos on prendas for select to authenticated
  using (es_amigo(user_id));

/*
  Opcion B: reemplaza la politica anterior por esta si quieres que un amigo
  solo vea las prendas que forman parte de outfits del usuario.

  drop policy prendas_select_amigos on prendas;
  create policy prendas_select_amigos on prendas for select to authenticated
    using (
      es_amigo(user_id)
      and exists (select 1 from outfit_prendas op where op.prenda_id = prendas.id)
    );
*/

create policy prendas_insert on prendas for insert to authenticated
  with check (user_id = auth.uid());
create policy prendas_update on prendas for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy prendas_delete on prendas for delete to authenticated
  using (user_id = auth.uid());

/* outfits: se crean solo con crear_outfit, por eso no hay politica de insert */
create policy outfits_select on outfits for select to authenticated
  using (user_id = auth.uid() or es_amigo(user_id));
create policy outfits_update on outfits for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy outfits_delete on outfits for delete to authenticated
  using (user_id = auth.uid());

create policy outfit_prendas_select on outfit_prendas for select to authenticated
  using (exists (
    select 1 from outfits o
    where o.id = outfit_id and (o.user_id = auth.uid() or es_amigo(o.user_id))
  ));

/* amistades: se crean con enviar_solicitud */
create policy amistades_select on amistades for select to authenticated
  using (solicitante_id = auth.uid() or destinatario_id = auth.uid());
create policy amistades_update on amistades for update to authenticated
  using (destinatario_id = auth.uid() and estado = 'pendiente')
  with check (destinatario_id = auth.uid() and estado in ('aceptada', 'rechazada'));
create policy amistades_delete on amistades for delete to authenticated
  using (solicitante_id = auth.uid() or destinatario_id = auth.uid());

/* solo se puede cambiar el estado, nunca los usuarios de la solicitud */
revoke update on amistades from authenticated;
grant update (estado) on amistades to authenticated;

/* bloqueos: se crean con bloquear_usuario */
create policy bloqueos_select on bloqueos for select to authenticated
  using (bloqueador_id = auth.uid());
create policy bloqueos_delete on bloqueos for delete to authenticated
  using (bloqueador_id = auth.uid());

/* recomendaciones */
create policy recomendaciones_select on recomendaciones for select to authenticated
  using (remitente_id = auth.uid() or destinatario_id = auth.uid());
create policy recomendaciones_insert on recomendaciones for insert to authenticated
  with check (remitente_id = auth.uid() and es_amigo(destinatario_id));
create policy recomendaciones_descartar on recomendaciones for update to authenticated
  using (destinatario_id = auth.uid() and estado = 'pendiente')
  with check (destinatario_id = auth.uid() and estado = 'descartada');
create policy recomendaciones_delete on recomendaciones for delete to authenticated
  using (remitente_id = auth.uid() and estado = 'pendiente');

revoke update on recomendaciones from authenticated;
grant update (estado) on recomendaciones to authenticated;

create policy recomendacion_prendas_select on recomendacion_prendas for select to authenticated
  using (exists (
    select 1 from recomendaciones r
    where r.id = recomendacion_id
      and (r.remitente_id = auth.uid() or r.destinatario_id = auth.uid())
  ));
create policy recomendacion_prendas_insert on recomendacion_prendas for insert to authenticated
  with check (exists (
    select 1
    from recomendaciones r
    join prendas p on p.id = prenda_id
    where r.id = recomendacion_id
      and r.remitente_id = auth.uid()
      and r.estado = 'pendiente'
      and p.user_id = r.destinatario_id
  ));

/* ========== STORAGE ========== */

insert into storage.buckets (id, name, public)
values ('prendas', 'prendas', false), ('fotos_perfil', 'fotos_perfil', false)
on conflict (id) do nothing;

/* cada usuario administra solo su carpeta */
create policy storage_propio on storage.objects for all to authenticated
  using (
    bucket_id in ('prendas', 'fotos_perfil')
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id in ('prendas', 'fotos_perfil')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

/* los amigos confirmados pueden leer las imagenes */
create policy storage_amigos_lectura on storage.objects for select to authenticated
  using (
    bucket_id in ('prendas', 'fotos_perfil')
    and es_amigo(((storage.foldername(name))[1])::uuid)
  );
Abre schema.sql con VS Code, selecciona todo (Ctrl + A), cópialo, pégalo en el editor de Supabase y pulsa Run.Abre schema.sql con VS Code, selecciona todo (Ctrl + A), cópialo, pégalo en el editor de Supabase y pulsa Run.Abre schema.sql con VS Code, selecciona todo (Ctrl + A), cópialo, pégalo en el editor de Supabase y pulsa Run.Abre schema.sql con VS Code, selecciona todo (Ctrl + A), cópialo, pégalo en el editor de Supabase y pulsa Run.Abre schema.sql con VS Code, selecciona todo (Ctrl + A), cópialo, pégalo en el editor de Supabase y pulsa Run.