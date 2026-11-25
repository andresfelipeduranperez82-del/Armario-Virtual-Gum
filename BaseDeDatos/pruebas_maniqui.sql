-- Pruebas de seguridad del maniquí con dos cuentas.
-- Reemplaza ID_CUENTA_A e ID_CUENTA_B por los identificadores de tus dos cuentas de prueba
-- (están en Authentication, Users, columna User UID). Se reemplazan en dos lugares cada uno.
-- Al final siempre sale un error con los resultados: es a propósito, para que no se guarde nada.

do $$
declare
  a uuid := 'ID_CUENTA_A';
  b uuid := 'ID_CUENTA_B';
  filas int;
  resultados text := '';
begin
  -- Desde aquí se actúa como la cuenta A
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', a::text, true);
  set local role authenticated;

  -- Prueba 1: la persona puede elegir su propio maniquí
  update public.perfiles set maniqui = 'femenino' where id = a;
  get diagnostics filas = row_count;
  resultados := resultados || E'\nPrueba 1, elegir el propio maniqui: ' || case when filas = 1 then 'PASA' else 'FALLA' end;

  -- Prueba 2: un valor que no existe se rechaza
  begin
    update public.perfiles set maniqui = 'robot' where id = a;
    resultados := resultados || E'\nPrueba 2, rechazar un valor invalido: FALLA';
  exception when check_violation then
    resultados := resultados || E'\nPrueba 2, rechazar un valor invalido: PASA';
  end;

  -- Prueba 3: no se puede cambiar el maniquí de otra cuenta
  update public.perfiles set maniqui = 'masculino' where id = b;
  get diagnostics filas = row_count;
  resultados := resultados || E'\nPrueba 3, no cambiar el maniqui de otra cuenta: ' || case when filas = 0 then 'PASA' else 'FALLA' end;

  -- Prueba 4: no se pueden modificar otras columnas del perfil
  begin
    update public.perfiles set email = 'otro@example.com' where id = a;
    resultados := resultados || E'\nPrueba 4, no cambiar otras columnas: FALLA';
  exception
    when insufficient_privilege then
      resultados := resultados || E'\nPrueba 4, no cambiar otras columnas: PASA';
    when undefined_column then
      resultados := resultados || E'\nPrueba 4, no cambiar otras columnas: OMITIDA, la tabla no tiene columna email';
  end;

  reset role;
  raise exception E'Resultados de las pruebas del maniqui:%\n\nSe deshizo todo a proposito.', resultados;
end $$;
