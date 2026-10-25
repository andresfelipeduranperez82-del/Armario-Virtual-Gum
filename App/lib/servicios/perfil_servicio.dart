import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'cliente.dart';

class Perfil {
  Perfil({required this.email, this.nombre, this.fotoPath, this.urlFoto});

  final String email;
  final String? nombre;
  final String? fotoPath;
  final String? urlFoto;
}

class PerfilServicio {
  static const _bucket = 'fotos_perfil';

  Future<Perfil> cargar() async {
    final userId = supabase.auth.currentUser!.id;
    final fila = await supabase
        .from('perfiles')
        .select('nombre, email, foto_personal_path')
        .eq('id', userId)
        .single();

    final ruta = fila['foto_personal_path'] as String?;
    String? url;
    if (ruta != null) {
      try {
        url = await supabase.storage.from(_bucket).createSignedUrl(ruta, 3600);
      } catch (_) {
        url = null;
      }
    }

    return Perfil(
      email: fila['email'] as String,
      nombre: fila['nombre'] as String?,
      fotoPath: ruta,
      urlFoto: url,
    );
  }

  /* Sube la foto nueva, la guarda en el perfil y borra la anterior si existía */
  Future<void> subirFoto({
    required Uint8List bytes,
    required String extension,
    String? rutaAnterior,
  }) async {
    final userId = supabase.auth.currentUser!.id;
    final ruta = '$userId/${DateTime.now().microsecondsSinceEpoch}.$extension';

    await supabase.storage.from(_bucket).uploadBinary(
          ruta,
          bytes,
          fileOptions: FileOptions(contentType: _tipoContenido(extension)),
        );

    try {
      await supabase.from('perfiles').update({'foto_personal_path': ruta}).eq('id', userId);
    } catch (e) {
      await supabase.storage.from(_bucket).remove([ruta]);
      rethrow;
    }

    if (rutaAnterior != null) {
      try {
        await supabase.storage.from(_bucket).remove([rutaAnterior]);
      } catch (_) {}
    }
  }

  /* Quita la foto del perfil. Sin foto, la app usa el modelo neutro. */
  Future<void> quitarFoto(String ruta) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('perfiles').update({'foto_personal_path': null}).eq('id', userId);
    try {
      await supabase.storage.from(_bucket).remove([ruta]);
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
