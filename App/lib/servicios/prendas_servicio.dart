import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'cliente.dart';

/* Valores permitidos, iguales a los tipos enumerados de la base de datos */
const categorias = {
  'superior': 'Superior',
  'inferior': 'Inferior',
  'calzado': 'Calzado',
  'cuerpo_completo': 'Cuerpo completo',
  'abrigo': 'Abrigo',
  'accesorios': 'Accesorios',
};

const estilos = {
  'casual': 'Casual',
  'formal': 'Formal',
  'deportivo': 'Deportivo',
  'fiesta': 'Fiesta',
};

const colores = [
  'Negro',
  'Blanco',
  'Gris',
  'Azul',
  'Rojo',
  'Verde',
  'Amarillo',
  'Naranja',
  'Rosado',
  'Morado',
  'Beige',
  'Marrón',
];

class Prenda {
  Prenda({
    required this.id,
    required this.imagenPath,
    required this.categoria,
    required this.colorPrincipal,
    required this.estilo,
    this.urlImagen,
  });

  final String id;
  final String imagenPath;
  final String categoria;
  final String colorPrincipal;
  final String estilo;
  String? urlImagen;

  factory Prenda.desdeMapa(Map<String, dynamic> m) {
    return Prenda(
      id: m['id'] as String,
      imagenPath: m['imagen_path'] as String,
      categoria: m['categoria'] as String,
      colorPrincipal: m['color_principal'] as String,
      estilo: m['estilo'] as String,
    );
  }
}

class PrendasServicio {
  static const _bucket = 'prendas';

  /* Lista solo las prendas del usuario actual.
     El filtro por user_id es necesario porque las políticas RLS también
     dejan ver las prendas de los amigos confirmados. */
  Future<List<Prenda>> listar() async {
    final userId = supabase.auth.currentUser!.id;
    final filas = await supabase
        .from('prendas')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final prendas = filas.map<Prenda>((f) => Prenda.desdeMapa(f)).toList();

    /* El bucket es privado, así que cada foto se muestra con una URL firmada temporal */
    await Future.wait(prendas.map((p) async {
      try {
        p.urlImagen = await supabase.storage.from(_bucket).createSignedUrl(p.imagenPath, 3600);
      } catch (_) {
        p.urlImagen = null;
      }
    }));

    return prendas;
  }

  /* Sube la foto a la carpeta del usuario y crea la fila en la tabla prendas */
  Future<void> crear({
    required Uint8List bytes,
    required String extension,
    required String categoria,
    required String color,
    required String estilo,
  }) async {
    final userId = supabase.auth.currentUser!.id;
    final ruta = '$userId/${DateTime.now().microsecondsSinceEpoch}.$extension';

    await supabase.storage.from(_bucket).uploadBinary(
          ruta,
          bytes,
          fileOptions: FileOptions(contentType: _tipoContenido(extension)),
        );

    try {
      await supabase.from('prendas').insert({
        'user_id': userId,
        'imagen_path': ruta,
        'categoria': categoria,
        'color_principal': color,
        'estilo': estilo,
      });
    } catch (e) {
      /* Si falla el registro, se borra la foto para no dejar archivos huérfanos */
      await supabase.storage.from(_bucket).remove([ruta]);
      rethrow;
    }
  }

  /* Cuenta en cuántos outfits está una prenda, usando la función de la base de datos */
  Future<int> contarOutfits(String prendaId) async {
    final resultado = await supabase.rpc(
      'contar_outfits_de_prenda',
      params: {'p_prenda': prendaId},
    );
    return (resultado as num).toInt();
  }

  /* Modifica los datos de la prenda. Si hay foto nueva, reemplaza la anterior en Storage */
  Future<void> actualizar({
    required Prenda prenda,
    required String categoria,
    required String color,
    required String estilo,
    Uint8List? nuevaFoto,
    String extension = 'jpg',
  }) async {
    final userId = supabase.auth.currentUser!.id;
    String? rutaNueva;

    if (nuevaFoto != null) {
      rutaNueva = '$userId/${DateTime.now().microsecondsSinceEpoch}.$extension';
      await supabase.storage.from(_bucket).uploadBinary(
            rutaNueva,
            nuevaFoto,
            fileOptions: FileOptions(contentType: _tipoContenido(extension)),
          );
    }

    try {
      await supabase.from('prendas').update({
        'categoria': categoria,
        'color_principal': color,
        'estilo': estilo,
        if (rutaNueva != null) 'imagen_path': rutaNueva,
      }).eq('id', prenda.id);
    } catch (e) {
      if (rutaNueva != null) {
        await supabase.storage.from(_bucket).remove([rutaNueva]);
      }
      rethrow;
    }

    /* La foto anterior ya no se usa, se borra para no dejar archivos huérfanos */
    if (rutaNueva != null) {
      try {
        await supabase.storage.from(_bucket).remove([prenda.imagenPath]);
      } catch (_) {}
    }
  }

  /* Elimina la prenda. El trigger de la base de datos borra también sus outfits */
  Future<void> eliminar(Prenda prenda) async {
    await supabase.from('prendas').delete().eq('id', prenda.id);
    try {
      await supabase.storage.from(_bucket).remove([prenda.imagenPath]);
    } catch (_) {}
  }

  String _tipoContenido(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
