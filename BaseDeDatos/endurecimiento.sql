/*
  Gum Armario Virtual
  Endurecimiento de seguridad

  Como ejecutarlo: Supabase, SQL Editor, New query, pegar todo y pulsar Run.
  Se puede ejecutar más de una vez sin problema.

  Que corrige:
  1. Cierra el acceso desde la API a las funciones que solo deben dispararse solas.
  2. Pone límites de cantidad por usuario, para que nadie llene la base de datos.
  3. Pone largos máximos a los textos y a las rutas de las imágenes.
  4. Limita el tamaño y el tipo de los archivos que se pueden subir.
  5. Limita los intentos de enviar solicitudes de amistad por correo, que permitían
     averiguar qué correos están registrados.
  6. Mueve la función es_amigo a un esquema que la API no expone.
*/

/* ========== 1. Funciones de disparador: no deben poder llamarse desde la API ========== */

/* Los disparadores siguen funcionando, porque el permiso de ejecución solo se revisa al crearlos */
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.eliminar_outfits_de_prenda() from public, anon, authenticated;

/* ========== 2. Límites de cantidad por usuario ========== */

create or replace function limitar_prendas()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (select count(*) from prendas where user_id = new.user_id) >= 300 then
    raise exception 'Llegaste al máximo de 300 prendas';
  end if;
  return new;
end;
$$;

create or replace function limitar_outfits()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (select count(*) from outfits where user_id = new.user_id) >= 200 then
    raise exception 'Llegaste al máximo de 200 outfits';
  end if;
  return new;
end;
$$;

create or replace function limitar_amistades()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (
    select count(*) from amistades
    where solicitante_id = new.solicitante_id or destinatario_id = new.solicitante_id
  ) >= 100 then
    raise exception 'Llegaste al máximo de 100 amigos y solicitudes';
  end if;
  return new;
end;
$$;

create or replace function limitar_recomendaciones()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (
    select count(*) from recomendaciones
    where remitente_id = new.remitente_id
      and destinatario_id = new.destinatario_id
      and estado = 'pendiente'
  ) >= 30 then
    raise exception 'Esta persona ya tiene 30 recomendaciones tuyas sin responder';
  end if;
  return new;
end;
$$;

revoke execute on function limitar_prendas() from public, anon, authenticated;
revoke execute on function limitar_outfits() from public, anon, authenticated;
revoke execute on function limitar_amistades() from public, anon, authenticated;
revoke execute on function limitar_recomendaciones() from public, anon, authenticated;

drop trigger if exists prendas_limite on prendas;
create trigger prendas_limite before insert on prendas
  for each row execute function limitar_prendas();

drop trigger if exists outfits_limite on outfits;
create trigger outfits_limite before insert on outfits
  for each row execute function limitar_outfits();

drop trigger if exists amistades_limite on amistades;
create trigger amistades_limite before insert on amistades
  for each row execute function limitar_amistades();

drop trigger if exists recomendaciones_limite on recomendaciones;
create trigger recomendaciones_limite before insert on recomendaciones
  for each row execute function limitar_recomendaciones();

/* ========== 3. Largos máximos de textos y rutas ========== */

alter table outfits drop constraint if exists outfits_nombre_largo;
alter table outfits add constraint outfits_nombre_largo check (char_length(nombre) <= 60);

alter table recomendaciones drop constraint if exists recomendaciones_nombre_largo;
alter table recomendaciones add constraint recomendaciones_nombre_largo check (char_length(nombre) <= 60);

alter table perfiles drop constraint if exists perfiles_nombre_largo;
alter table perfiles add constraint perfiles_nombre_largo check (char_length(nombre) <= 100);

alter table perfiles drop constraint if exists perfiles_foto_ruta_larga;
alter table perfiles add constraint perfiles_foto_ruta_larga check (char_length(foto_personal_path) <= 300);

alter table prendas drop constraint if exists prendas_color_largo;
alter table prendas add constraint prendas_color_largo check (char_length(color_principal) <= 30);

alter table prendas drop constraint if exists prendas_ruta_larga;
alter table prendas add constraint prendas_ruta_larga check (char_length(imagen_path) <= 300);

/* ========== 4. Tamaño y tipo de los archivos que se pueden subir ========== */

update storage.buckets
set file_size_limit = 5242880,
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
where id in ('prendas', 'fotos_perfil');

/* ========== 5. Límite de intentos de solicitudes de amistad por correo ========== */

create table if not exists intentos_solicitud (
  user_id uuid not null references perfiles (id) on delete cascade,
  created_at timestamptz not null default now()
);
create index if not exists intentos_solicitud_idx on intentos_solicitud (user_id, created_at);

/* Sin políticas y sin permisos: solo la función de abajo puede escribir aquí */
alter table intentos_solicitud enable row level security;
revoke all on intentos_solicitud from anon, authenticated;

/* Esta función ahora devuelve 'ok' o el mensaje de error, en lugar de lanzar una excepción.
   Si lanzara una excepción, se desharía también el registro del intento y el límite
   no contaría los intentos fallidos, que son justo los que interesa limitar. */
drop function if exists public.enviar_solicitud(text);

create function public.enviar_solicitud(p_email text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_dest uuid;
begin
  if auth.uid() is null then
    return 'Debes iniciar sesión';
  end if;

  /* Máximo 20 intentos por hora y por usuario, hayan salido bien o mal.
     Sin este límite, se podría probar correos en masa para saber quién usa la app. */
  delete from intentos_solicitud where created_at < now() - interval '1 day';
  if (
    select count(*) from intentos_solicitud
    where user_id = auth.uid() and created_at > now() - interval '1 hour'
  ) >= 20 then
    return 'Demasiados intentos. Espera un rato antes de enviar más solicitudes';
  end if;
  insert into intentos_solicitud (user_id) values (auth.uid());

  select id into v_dest from perfiles where lower(email) = lower(trim(p_email));
  if v_dest is null then
    return 'Ese correo no está registrado';
  end if;
  if v_dest = auth.uid() then
    return 'No puedes agregarte a ti mismo';
  end if;
  if exists (
    select 1 from bloqueos
    where (bloqueador_id = v_dest and bloqueado_id = auth.uid())
       or (bloqueador_id = auth.uid() and bloqueado_id = v_dest)
  ) then
    return 'No es posible enviar la solicitud a este usuario';
  end if;
  if exists (
    select 1 from amistades
    where (solicitante_id = auth.uid() and destinatario_id = v_dest)
       or (solicitante_id = v_dest and destinatario_id = auth.uid())
  ) then
    return 'Ya existe una solicitud o amistad con este usuario';
  end if;

  insert into amistades (solicitante_id, destinatario_id)
  values (auth.uid(), v_dest);

  return 'ok';
end;
$$;

revoke execute on function public.enviar_solicitud(text) from public, anon;
grant execute on function public.enviar_solicitud(text) to authenticated;

/* ========== 6. es_amigo a un esquema que la API no expone ========== */

/* Solo la usan las políticas de seguridad, no hace falta que sea llamable desde la API.
   Las políticas la encuentran igual, porque guardan una referencia a la función y no su nombre.
   Para deshacer este paso: alter function private.es_amigo(uuid) set schema public; */
create schema if not exists private;
grant usage on schema private to authenticated;
do $$
begin
  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'es_amigo'
  ) then
    alter function public.es_amigo(uuid) set schema private;
  end if;
end
$$;
