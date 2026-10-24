import 'cliente.dart';
import 'prendas_servicio.dart';

class Recomendacion {
  Recomendacion({
    required this.id,
    required this.nombre,
    required this.estilo,
    required this.remitente,
    required this.prendas,
  });

  final String id;
  final String nombre;
  final String estilo;
  final String remitente;
  final List<Prenda> prendas;
}

class RecomendacionesServicio {
  static const _bucket = 'prendas';
  static const _orden = ['cuerpo_completo', 'abrigo', 'superior', 'inferior', 'calzado', 'accesorios'];

  /* Las fotos están en un bucket privado, así que se muestran con una URL firmada temporal */
  Future<void> _firmar(List<Prenda> prendas) async {
    await Future.wait(prendas.map((p) async {
      try {
        p.urlImagen = await supabase.storage.from(_bucket).createSignedUrl(p.imagenPath, 3600);
      } catch (_) {
        p.urlImagen = null;
      }
    }));
  }

  /* Prendas de un amigo confirmado. Las políticas RLS solo lo permiten si son amigos. */
  Future<List<Prenda>> prendasDe(String usuarioId) async {
    final filas = await supabase
        .from('prendas')
        .select()
        .eq('user_id', usuarioId)
        .order('created_at', ascending: false);
    final prendas = filas.map<Prenda>((f) => Prenda.desdeMapa(f)).toList();
    await _firmar(prendas);
    return prendas;
  }

  /* Crea la recomendación y luego sus prendas. Si falla lo segundo, borra la primera. */
  Future<void> enviar({
    required String amigoId,
    required String nombre,
    required String estilo,
    required List<String> prendaIds,
  }) async {
    final fila = await supabase
        .from('recomendaciones')
        .insert({
          'remitente_id': supabase.auth.currentUser!.id,
          'destinatario_id': amigoId,
          'nombre': nombre,
          'estilo': estilo,
        })
        .select('id')
        .single();
    final id = fila['id'] as String;

    try {
      await supabase.from('recomendacion_prendas').insert(
            prendaIds.map((p) => {'recomendacion_id': id, 'prenda_id': p}).toList(),
          );
    } catch (e) {
      await supabase.from('recomendaciones').delete().eq('id', id);
      rethrow;
    }
  }

  /* Recomendaciones pendientes que le enviaron al usuario actual */
  Future<List<Recomendacion>> recibidas() async {
    final yo = supabase.auth.currentUser!.id;
    final filas = await supabase
        .from('recomendaciones')
        .select(
          'id, nombre, estilo, remitente_id, recomendacion_prendas(prendas(id, imagen_path, categoria, color_principal, estilo))',
        )
        .eq('destinatario_id', yo)
        .eq('estado', 'pendiente')
        .order('created_at', ascending: false);

    /* Nombre de quien envía. Si ya no es amigo, la política RLS no deja verlo. */
    final ids = <String>{for (final f in filas) f['remitente_id'] as String};
    final nombres = <String, String>{};
    if (ids.isNotEmpty) {
      final perfiles = await supabase.from('perfiles').select('id, nombre, email').inFilter('id', ids.toList());
      for (final p in perfiles) {
        final nombre = (p['nombre'] as String?)?.trim();
        nombres[p['id'] as String] = (nombre != null && nombre.isNotEmpty) ? nombre : p['email'] as String;
      }
    }

    final resultado = <Recomendacion>[];
    for (final fila in filas) {
      final prendas = <Prenda>[];
      for (final relacion in (fila['recomendacion_prendas'] as List)) {
        final datos = relacion['prendas'];
        if (datos != null) {
          prendas.add(Prenda.desdeMapa(Map<String, dynamic>.from(datos as Map)));
        }
      }
      prendas.sort((a, b) => _orden.indexOf(a.categoria).compareTo(_orden.indexOf(b.categoria)));
      resultado.add(Recomendacion(
        id: fila['id'] as String,
        nombre: fila['nombre'] as String,
        estilo: fila['estilo'] as String,
        remitente: nombres[fila['remitente_id'] as String] ?? 'Un amigo',
        prendas: prendas,
      ));
    }

    await _firmar(resultado.expand((r) => r.prendas).toList());
    return resultado;
  }

  /* Acepta con la función de la base de datos, que crea el outfit en tu colección */
  Future<void> aceptar(String recomendacionId) async {
    await supabase.rpc('aceptar_recomendacion', params: {'p_id': recomendacionId});
  }

  Future<void> descartar(String recomendacionId) async {
    await supabase.from('recomendaciones').update({'estado': 'descartada'}).eq('id', recomendacionId);
  }
}
