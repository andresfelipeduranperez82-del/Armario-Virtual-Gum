import 'cliente.dart';
import 'prendas_servicio.dart';

class Outfit {
  Outfit({
    required this.id,
    required this.nombre,
    required this.estilo,
    required this.prendas,
  });

  final String id;
  final String nombre;
  final String estilo;
  final List<Prenda> prendas;
}

class OutfitsServicio {
  static const _bucket = 'prendas';

  /* Orden en que se muestran las prendas dentro de un outfit */
  static const _orden = ['cuerpo_completo', 'abrigo', 'superior', 'inferior', 'calzado', 'accesorios'];

  /* Lista los outfits del usuario con sus prendas.
     El filtro por user_id es necesario porque las políticas RLS también
     dejan ver los outfits de los amigos confirmados. */
  Future<List<Outfit>> listar() async {
    final userId = supabase.auth.currentUser!.id;
    final filas = await supabase
        .from('outfits')
        .select(
          'id, nombre, estilo, outfit_prendas(prendas(id, imagen_path, categoria, color_principal, estilo))',
        )
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final outfits = <Outfit>[];
    for (final fila in filas) {
      final prendas = <Prenda>[];
      for (final relacion in (fila['outfit_prendas'] as List)) {
        final datos = relacion['prendas'];
        if (datos != null) {
          prendas.add(Prenda.desdeMapa(Map<String, dynamic>.from(datos as Map)));
        }
      }
      prendas.sort((a, b) => _orden.indexOf(a.categoria).compareTo(_orden.indexOf(b.categoria)));
      outfits.add(Outfit(
        id: fila['id'] as String,
        nombre: fila['nombre'] as String,
        estilo: fila['estilo'] as String,
        prendas: prendas,
      ));
    }

    /* El bucket es privado, así que cada foto se muestra con una URL firmada temporal */
    final todas = outfits.expand((o) => o.prendas).toList();
    await Future.wait(todas.map((p) async {
      try {
        p.urlImagen = await supabase.storage.from(_bucket).createSignedUrl(p.imagenPath, 3600);
      } catch (_) {
        p.urlImagen = null;
      }
    }));

    return outfits;
  }

  /* Crea el outfit con la función de la base de datos, que valida las reglas */
  Future<void> crear({
    required String nombre,
    required String estilo,
    required List<String> prendaIds,
  }) async {
    await supabase.rpc('crear_outfit', params: {
      'p_nombre': nombre,
      'p_estilo': estilo,
      'p_prendas': prendaIds,
    });
  }

  Future<void> eliminar(String outfitId) async {
    await supabase.from('outfits').delete().eq('id', outfitId);
  }
}
