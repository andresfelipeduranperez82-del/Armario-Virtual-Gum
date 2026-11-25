/*
  Gum Armario Virtual
  Pruebas de seguridad con dos cuentas

  Como usarlo:
  1. Averigua los identificadores de tus dos cuentas, ejecutando esta consulta aparte:
       select id, email from auth.users;
  2. Reemplaza los dos textos entre comillas, PEGA_AQUI_EL_ID_DE_LA_CUENTA_A y
     PEGA_AQUI_EL_ID_DE_LA_CUENTA_B, por los identificadores. La cuenta A debe tener
     prendas y ser amiga confirmada de la cuenta B.
  3. Pega todo en el SQL Editor y pulsa Run. Al final aparece una lista de pruebas, cada
     una con el resultado PASA o FALLA.

  Cómo funciona: la base de datos simula a cada usuario, con su rol y su identificador,
  y comprueba que lo que debería estar bloqueado realmente lo esté.
  Las pruebas que cambian datos se deshacen solas al terminar. No queda nada modificado.

  Qué no se puede probar aquí: el tamaño y el tipo de los archivos subidos los controla
  Storage, no la base de datos. Se prueba a mano subiendo un archivo que no sea imagen.
*/

create temp table if not exists resultados (
  prueba integer,
  descripcion text,
  esperado text,
  obtenido text,
  ok boolean
);
truncate resultados;

do $$
declare
  a uuid := 'PEGA_AQUI_EL_ID_DE_LA_CUENTA_A';
  b uuid := 'PEGA_AQUI_EL_ID_DE_LA_CUENTA_B';
  claims_a text;
  claims_b text;
  correo_b text;
  ids uuid[];
  n integer;
  mensaje text;
begin
  if not exists (select 1 from public.perfiles where id = a)
     or not exists (select 1 from public.perfiles where id = b) then
    raise exception 'Alguno de los dos identificadores no corresponde a un perfil existente';
  end if;

  claims_a := json_build_object('sub', a, 'role', 'authenticated')::text;
  claims_b := json_build_object('sub', b, 'role', 'authenticated')::text;
  select email into correo_b from public.perfiles where id = b;

  /* 1. Sin iniciar sesión no se ve ninguna prenda */
  begin
    set local role anon;
    select count(*) into n from public.prendas;
    reset role;
    insert into resultados values (1, 'Sin iniciar sesión no se ve ninguna prenda', '0 filas', n || ' filas', n = 0);
  exception when others then
    reset role;
    insert into resultados values (1, 'Sin iniciar sesión no se ve ninguna prenda', '0 filas o acceso denegado', 'acceso denegado', true);
  end;

  /* 2. Sin iniciar sesión no se ven los perfiles ni los correos */
  begin
    set local role anon;
    select count(*) into n from public.perfiles;
    reset role;
    insert into resultados values (2, 'Sin iniciar sesión no se ven perfiles ni correos', '0 filas', n || ' filas', n = 0);
  exception when others then
    reset role;
    insert into resultados values (2, 'Sin iniciar sesión no se ven perfiles ni correos', '0 filas o acceso denegado', 'acceso denegado', true);
  end;

  /* 3. Sin iniciar sesión no se puede crear un outfit */
  begin
    set local role anon;
    perform public.crear_outfit('prueba', 'casual', array[]::uuid[]);
    reset role;
    insert into resultados values (3, 'Sin iniciar sesión no se puede ejecutar crear_outfit', 'acceso denegado', 'se ejecutó', false);
  exception when others then
    reset role;
    insert into resultados values (3, 'Sin iniciar sesión no se puede ejecutar crear_outfit', 'acceso denegado', left(sqlerrm, 60), sqlerrm ilike '%permission denied%');
  end;

  /* 4. Nadie puede llamar desde la API a la función que crea perfiles */
  begin
    set local role anon;
    perform public.handle_new_user();
    reset role;
    insert into resultados values (4, 'La función que crea perfiles no se puede llamar desde la API', 'acceso denegado', 'se ejecutó', false);
  exception when others then
    reset role;
    insert into resultados values (4, 'La función que crea perfiles no se puede llamar desde la API', 'acceso denegado', left(sqlerrm, 60), sqlerrm ilike '%permission denied%');
  end;

  /* 5. Un amigo confirmado SÍ ve las prendas (decisión de diseño documentada) */
  begin
    perform set_config('request.jwt.claims', claims_b, true);
    set local role authenticated;
    select count(*) into n from public.prendas where user_id = a;
    reset role;
    insert into resultados values (5, 'Un amigo confirmado ve las prendas de la cuenta A (decisión de diseño)', 'más de 0 filas', n || ' filas', n > 0);
  exception when others then
    reset role;
    insert into resultados values (5, 'Un amigo confirmado ve las prendas de la cuenta A (decisión de diseño)', 'más de 0 filas', left(sqlerrm, 60), false);
  end;

  /* 6. Sin amistad no se ven las prendas de otra persona (se deshace al terminar) */
  begin
    delete from public.amistades
    where (solicitante_id = a and destinatario_id = b) or (solicitante_id = b and destinatario_id = a);
    perform set_config('request.jwt.claims', claims_b, true);
    set local role authenticated;
    select count(*) into n from public.prendas where user_id = a;
    reset role;
    raise exception 'deshacer';
  exception when others then
    reset role;
    insert into resultados values (6, 'Sin amistad no se ven las prendas de otra persona', '0 filas', n || ' filas', n = 0 and sqlerrm = 'deshacer');
  end;

  /* 7. Si A bloquea a B, B pierde el acceso al armario de A (se deshace al terminar) */
  begin
    perform set_config('request.jwt.claims', claims_a, true);
    set local role authenticated;
    perform public.bloquear_usuario(b);
    reset role;
    perform set_config('request.jwt.claims', claims_b, true);
    set local role authenticated;
    select count(*) into n from public.prendas where user_id = a;
    reset role;
    raise exception 'deshacer';
  exception when others then
    reset role;
    insert into resultados values (7, 'Si A bloquea a B, B deja de ver las prendas de A', '0 filas', n || ' filas', n = 0 and sqlerrm = 'deshacer');
  end;

  /* 8. Un amigo no puede modificar las prendas de otra persona */
  begin
    perform set_config('request.jwt.claims', claims_b, true);
    set local role authenticated;
    update public.prendas set color_principal = 'Hackeado' where user_id = a;
    get diagnostics n = row_count;
    reset role;
    raise exception 'deshacer';
  exception when others then
    reset role;
    insert into resultados values (8, 'Un amigo no puede modificar prendas ajenas', '0 filas modificadas', coalesce(n, -1) || ' filas modificadas', n = 0 and sqlerrm = 'deshacer');
  end;

  /* 9. Un amigo no puede borrar las prendas de otra persona */
  begin
    perform set_config('request.jwt.claims', claims_b, true);
    set local role authenticated;
    delete from public.prendas where user_id = a;
    get diagnostics n = row_count;
    reset role;
    raise exception 'deshacer';
  exception when others then
    reset role;
    insert into resultados values (9, 'Un amigo no puede borrar prendas ajenas', '0 filas borradas', coalesce(n, -1) || ' filas borradas', n = 0 and sqlerrm = 'deshacer');
  end;

  /* 10. Nadie puede crear una prenda a nombre de otra persona */
  begin
    perform set_config('request.jwt.claims', claims_b, true);
    set local role authenticated;
    insert into public.prendas (user_id, imagen_path, categoria, color_principal, estilo)
    values (a, 'x/falsa.png', 'superior', 'Negro', 'casual');
    reset role;
    raise exception 'se permitió';
  exception when others then
    reset role;
    insert into resultados values (10, 'Nadie puede crear una prenda a nombre de otra persona', 'bloqueado', left(sqlerrm, 60), sqlerrm ilike '%row-level security%' or sqlerrm ilike '%permission denied%');
  end;

  /* 11. Nadie puede cambiar su correo en el perfil */
  begin
    perform set_config('request.jwt.claims', claims_b, true);
    set local role authenticated;
    update public.perfiles set email = 'robado@ejemplo.com' where id = b;
    reset role;
    raise exception 'se permitió';
  exception when others then
    reset role;
    insert into resultados values (11, 'Nadie puede cambiar el correo de su perfil', 'acceso denegado', left(sqlerrm, 60), sqlerrm ilike '%permission denied%');
  end;

  /* 12. Un amigo no puede cambiar el nombre del perfil de otra persona */
  begin
    perform set_config('request.jwt.claims', claims_b, true);
    set local role authenticated;
    update public.perfiles set nombre = 'Hackeado' where id = a;
    get diagnostics n = row_count;
    reset role;
    raise exception 'deshacer';
  exception when others then
    reset role;
    insert into resultados values (12, 'Un amigo no puede cambiar el perfil de otra persona', '0 filas modificadas', coalesce(n, -1) || ' filas modificadas', n = 0 and sqlerrm = 'deshacer');
  end;

  /* 13. No se puede insertar un outfit saltándose la función de validación */
  begin
    perform set_config('request.jwt.claims', claims_b, true);
    set local role authenticated;
    insert into public.outfits (user_id, nombre, estilo) values (b, 'sin validar', 'casual');
    reset role;
    raise exception 'se permitió';
  exception when others then
    reset role;
    insert into resultados values (13, 'No se puede crear un outfit sin pasar por la función de validación', 'bloqueado', left(sqlerrm, 60), sqlerrm ilike '%row-level security%' or sqlerrm ilike '%permission denied%');
  end;

  /* 14. No se puede armar un outfit con prendas de otra persona */
  begin
    perform set_config('request.jwt.claims', claims_b, true);
    set local role authenticated;
    select array_agg(id) into ids from public.prendas where user_id = a;
    perform public.crear_outfit('robo', 'casual', ids);
    reset role;
    raise exception 'se permitió';
  exception when others then
    reset role;
    insert into resultados values (14, 'No se puede armar un outfit con prendas de otra persona', 'rechazado por la función', left(sqlerrm, 60), sqlerrm ilike '%ser tuyas%');
  end;

  /* 15. Nadie puede enviarse una solicitud de amistad a sí mismo */
  begin
    perform set_config('request.jwt.claims', claims_b, true);
    set local role authenticated;
    select public.enviar_solicitud(correo_b) into mensaje;
    reset role;
    raise exception 'deshacer';
  exception when others then
    reset role;
    insert into resultados values (15, 'Nadie puede enviarse una solicitud a sí mismo', 'No puedes agregarte a ti mismo', left(coalesce(mensaje, sqlerrm), 60), mensaje ilike '%agregarte a ti mismo%');
  end;

  /* 16. Nadie puede leer el registro de intentos de solicitudes */
  begin
    perform set_config('request.jwt.claims', claims_b, true);
    set local role authenticated;
    select count(*) into n from public.intentos_solicitud;
    reset role;
    raise exception 'se permitió';
  exception when others then
    reset role;
    insert into resultados values (16, 'Nadie puede leer el registro de intentos de solicitudes', 'acceso denegado', left(sqlerrm, 60), sqlerrm ilike '%permission denied%');
  end;

  /* 17. Nadie puede cambiar quiénes participan en una amistad */
  begin
    perform set_config('request.jwt.claims', claims_b, true);
    set local role authenticated;
    update public.amistades set solicitante_id = b where destinatario_id = b;
    reset role;
    raise exception 'se permitió';
  exception when others then
    reset role;
    insert into resultados values (17, 'Nadie puede cambiar quiénes participan en una amistad', 'acceso denegado', left(sqlerrm, 60), sqlerrm ilike '%permission denied%');
  end;

  /* 18. Se limitan los intentos de solicitudes por correo, incluidos los fallidos (se deshace al terminar) */
  begin
    perform set_config('request.jwt.claims', claims_b, true);
    set local role authenticated;
    for i in 1..22 loop
      select public.enviar_solicitud('no.existe.' || i || '@ejemplo.com') into mensaje;
    end loop;
    reset role;
    raise exception 'deshacer';
  exception when others then
    reset role;
    insert into resultados values (18, 'Después de 20 intentos en una hora se bloquean las solicitudes por correo', 'Demasiados intentos', left(coalesce(mensaje, sqlerrm), 60), mensaje ilike 'Demasiados intentos%');
  end;

  /* 19. Cada usuario tiene un máximo de 300 prendas (se deshace al terminar) */
  begin
    insert into public.prendas (user_id, imagen_path, categoria, color_principal, estilo)
    select a, 'prueba/' || g, 'superior', 'Negro', 'casual'
    from generate_series(1, greatest(300 - (select count(*) from public.prendas where user_id = a), 0)::integer) g;
    perform set_config('request.jwt.claims', claims_a, true);
    set local role authenticated;
    insert into public.prendas (user_id, imagen_path, categoria, color_principal, estilo)
    values (a, 'prueba/una_mas', 'superior', 'Negro', 'casual');
    reset role;
    raise exception 'se permitió';
  exception when others then
    reset role;
    insert into resultados values (19, 'Una cuenta no puede pasar de 300 prendas', 'máximo de 300 prendas', left(sqlerrm, 60), sqlerrm ilike '%máximo de 300 prendas%');
  end;
end
$$;

select
  prueba,
  descripcion,
  esperado,
  obtenido,
  case when ok then 'PASA' else 'FALLA' end as resultado
from resultados
order by prueba;
