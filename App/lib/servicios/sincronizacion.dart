import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cliente.dart';

/* Escucha los cambios de la base de datos en tiempo real y avisa a las pantallas.

   Cada tema (prendas, outfits, amistades, recomendaciones, perfil) tiene un contador.
   Cuando llega un cambio de la base de datos, el contador sube y las pantallas que lo
   escuchan vuelven a pedir sus datos. Así no hace falta interpretar cada evento, y las
   consultas de siempre siguen aplicando la seguridad (RLS). */
class Sincronizacion {
  Sincronizacion._();

  static final Sincronizacion instancia = Sincronizacion._();

  static const temas = ['prendas', 'outfits', 'amistades', 'recomendaciones', 'perfil'];

  final Map<String, ValueNotifier<int>> _contadores = {};
  final Map<String, Timer> _esperas = {};
  RealtimeChannel? _canal;
  bool _activo = false;
  bool _huboCorte = false;

  /* Indica si la conexión en tiempo real está activa. Las pantallas muestran un aviso si no lo está. */
  final ValueNotifier<bool> conectado = ValueNotifier<bool>(true);

  ValueNotifier<int> tema(String nombre) {
    return _contadores.putIfAbsent(nombre, () => ValueNotifier<int>(0));
  }

  /* Espera un momento antes de avisar, porque un solo cambio suele traer varios eventos seguidos */
  void _avisar(String nombre) {
    _esperas[nombre]?.cancel();
    _esperas[nombre] = Timer(const Duration(milliseconds: 400), () {
      final contador = tema(nombre);
      contador.value = contador.value + 1;
    });
  }

  void iniciar() {
    final usuario = supabase.auth.currentUser?.id;
    if (usuario == null || _canal != null) return;

    final canal = supabase.channel('gum-sincronizacion');

    void escuchar(
      String tabla,
      String nombreTema,
      PostgresChangeEvent evento,
      PostgresChangeFilter? filtro,
    ) {
      canal.onPostgresChanges(
        event: evento,
        schema: 'public',
        table: tabla,
        filter: filtro,
        callback: (_) => _avisar(nombreTema),
      );
    }

    /* Con columnaUsuario solo se escuchan los cambios de filas propias al insertar o modificar.
       Los borrados no se pueden filtrar por columna, así que se escuchan todos. */
    void escucharTabla(String tabla, String nombreTema, {String? columnaUsuario}) {
      if (columnaUsuario == null) {
        escuchar(tabla, nombreTema, PostgresChangeEvent.all, null);
        return;
      }
      final filtro = PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: columnaUsuario,
        value: usuario,
      );
      escuchar(tabla, nombreTema, PostgresChangeEvent.insert, filtro);
      escuchar(tabla, nombreTema, PostgresChangeEvent.update, filtro);
      escuchar(tabla, nombreTema, PostgresChangeEvent.delete, null);
    }

    escucharTabla('prendas', 'prendas', columnaUsuario: 'user_id');
    escucharTabla('outfits', 'outfits', columnaUsuario: 'user_id');
    escucharTabla('outfit_prendas', 'outfits');
    escucharTabla('amistades', 'amistades');
    escucharTabla('bloqueos', 'amistades');
    escucharTabla('recomendaciones', 'recomendaciones');
    escucharTabla('recomendacion_prendas', 'recomendaciones');
    escucharTabla('perfiles', 'perfil', columnaUsuario: 'id');

    _activo = true;
    canal.subscribe((estado, error) {
      if (!_activo) return;
      if (estado == RealtimeSubscribeStatus.subscribed) {
        conectado.value = true;
        /* Si hubo un corte, se pueden haber perdido eventos: se recarga todo */
        if (_huboCorte) {
          _huboCorte = false;
          for (final nombre in temas) {
            _avisar(nombre);
          }
        }
      } else {
        _huboCorte = true;
        conectado.value = false;
      }
    });
    _canal = canal;
  }

  Future<void> detener() async {
    _activo = false;
    final canal = _canal;
    _canal = null;
    for (final espera in _esperas.values) {
      espera.cancel();
    }
    _esperas.clear();
    _huboCorte = false;
    conectado.value = true;
    if (canal != null) {
      await supabase.removeChannel(canal);
    }
  }
}
