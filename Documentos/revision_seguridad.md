# Revisión de seguridad

Este documento resume la revisión de seguridad de la base de datos de Gum Armario Virtual: qué se revisó, qué se encontró, qué se corrigió y qué riesgos se aceptan, con su justificación.

## Alcance y método

1. Revisión con el Security Advisor de Supabase, que usa el analizador Splinter.
2. Relectura de los scripts propios en busca de huecos que una herramienta automática no detecta.
3. Pruebas de ataque con dos cuentas, simulando a cada usuario en la base de datos. Están en `BaseDeDatos/pruebas_seguridad.sql`.

## Resultado del Security Advisor

El análisis dio **0 errores y 12 advertencias**. Se clasifican así:

1. **Funciones de disparador accesibles desde la API (4 avisos).** `handle_new_user` y `eliminar_outfits_de_prenda` podían ser llamadas por usuarios sin sesión y por usuarios con sesión. No necesitan serlo, porque las dispara la propia base de datos. **Corregido:** se les quitó el permiso de ejecución. Los disparadores siguen funcionando, porque ese permiso solo se revisa al crearlos.
2. **Función auxiliar de las políticas (1 aviso).** `es_amigo` solo la usan las políticas de seguridad. **Corregido:** se movió a un esquema privado que la API no expone.
3. **Funciones que la aplicación llama a propósito (6 avisos).** `crear_outfit`, `enviar_solicitud`, `bloquear_usuario`, `aceptar_recomendacion`, `mis_amistades` y `mis_bloqueos`. **Riesgo aceptado**, con la justificación de más abajo.
4. **Protección contra contraseñas filtradas desactivada (1 aviso).** No aplica, porque la aplicación solo permite iniciar sesión con Google y no maneja contraseñas.

## Hallazgos propios y correcciones

1. **Los archivos subidos no tenían límite de tamaño ni de tipo.** Se limitó cada bucket a 5 MB y a imágenes JPEG, PNG o WebP.
2. **No había cupos por usuario.** Se agregaron límites validados en la base de datos: 300 prendas, 200 outfits, 100 amigos y solicitudes, y 30 recomendaciones pendientes hacia una misma persona.
3. **Los textos no tenían largo máximo.** Se limitaron los nombres de outfits, recomendaciones y perfiles, el color de las prendas y las rutas de las imágenes.
4. **Se podían probar correos en masa.** La función que envía solicitudes de amistad informa si un correo está registrado, como pide el documento de objetivos, y eso permite averiguar quién usa la aplicación. **Mitigado:** máximo de 20 intentos por hora y por usuario.
5. **Un error de diseño propio al limitar esos intentos.** La primera idea registraba cada intento y luego lanzaba una excepción si algo fallaba. Pero una excepción deshace también el registro, así que los intentos fallidos, que son justo los que interesa limitar, no se habrían contado. **Corregido:** la función ahora devuelve el mensaje de error como texto en lugar de lanzar una excepción.
6. **Un hueco anterior en la tabla de perfiles.** La política permitía modificar cualquier columna de la propia fila, incluido el correo, que es único y sirve para buscar amigos. **Corregido antes:** solo se pueden modificar el nombre y la ruta de la foto.

## Riesgos aceptados

1. **Funciones con permisos elevados que el usuario con sesión puede llamar.** Son necesarias: crean outfits, envían solicitudes y aceptan recomendaciones validando las reglas dentro de la base de datos, algo que las políticas de las tablas solas no pueden hacer. Cada una exige sesión, usa un `search_path` fijo, solo opera sobre datos del usuario que la llama y está cubierta por pruebas.
2. **Los avisos de borrado de Supabase Realtime no pasan por RLS.** Cualquier usuario conectado recibe el identificador (uuid) de las filas que alguien borra en las tablas publicadas, sin ningún otro dato. Una alternativa más estricta son los canales privados de difusión con autorización.
3. **Los amigos confirmados ven las prendas y la foto de cuerpo completo.** Es una decisión de diseño: sin eso no se pueden armar recomendaciones. Se corta al eliminar o bloquear al amigo.
4. **Un usuario puede saber si un correo está registrado** dentro del límite de intentos, por el requisito de validar la existencia del correo al agregar amigos.

## Pendiente antes de publicar la aplicación

1. Desactivar en Supabase el proveedor de correo y contraseña, y los inicios de sesión anónimos, para que solo se pueda entrar con Google.
2. Cambiar la dirección `localhost` de la configuración de Authentication por la del sitio real.
3. Sacar la pantalla de consentimiento de Google del modo de prueba, lo que exige verificación de Google.
4. Probar a mano que Storage rechaza archivos que no son imágenes o que pesan más de 5 MB.

## Pruebas de ataque

El script `BaseDeDatos/pruebas_seguridad.sql` ejecuta 19 pruebas con dos cuentas. Las que modifican datos se deshacen solas al terminar. Comprueban, entre otras cosas:

* Que sin iniciar sesión no se vean prendas ni correos, ni se pueda crear un outfit.
* Que un amigo confirmado vea las prendas, pero no pueda modificarlas ni borrarlas, ni crear prendas a nombre de otra persona.
* Que sin amistad, o tras un bloqueo, no se vean las prendas de otra persona.
* Que nadie pueda cambiar su correo, ni el perfil de otra persona, ni los participantes de una amistad.
* Que no se pueda crear un outfit saltándose la función de validación, ni con prendas ajenas.
* Que nadie pueda enviarse una solicitud a sí mismo, ni leer el registro de intentos.
* Que se bloqueen las solicitudes después de 20 intentos en una hora, y que no se pase de 300 prendas.

**Resultado en una base de PostgreSQL 16 de prueba, con las piezas de Supabase simuladas:** las 19 pruebas pasan. Además, se comprobó que las pruebas detectan fallas reales: al quitar a propósito tres protecciones, las tres pruebas correspondientes fallaron.

**Resultado en el proyecto real de Supabase:** pendiente de completar con la ejecución del script.

## Cómo repetir la revisión

1. Ejecutar los scripts de `BaseDeDatos` en orden: `schema.sql`, `amigos_funciones.sql`, `perfil_foto.sql`, `tiempo_real.sql` y `endurecimiento.sql`.
2. Ejecutar `pruebas_seguridad.sql` con los identificadores de dos cuentas.
3. Volver a ejecutar el Security Advisor y comparar con este documento.
