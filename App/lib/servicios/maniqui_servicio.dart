import 'cliente.dart';

/* Maniquí que se dibuja en el editor de outfits cuando la persona no sube su foto */
enum TipoManiqui {
  masculino('masculino', 'Masculino', 0.0),
  femenino('femenino', 'Femenino', 1.0);

  const TipoManiqui(this.clave, this.nombre, this.mezcla);

  /* Texto que se guarda en la base de datos */
  final String clave;

  /* Texto que se muestra en pantalla */
  final String nombre;

  /* 0 es la forma masculina y 1 la femenina */
  final double mezcla;

  static TipoManiqui? deClave(String? clave) {
    for (final tipo in values) {
      if (tipo.clave == clave) return tipo;
    }
    return null;
  }
}

class ManiquiServicio {
  /* Devuelve el maniquí elegido, o null si todavía no se eligió ninguno */
  Future<TipoManiqui?> cargar() async {
    final id = supabase.auth.currentUser?.id;
    if (id == null) return null;
    final fila = await supabase.from('perfiles').select('maniqui').eq('id', id).maybeSingle();
    return TipoManiqui.deClave(fila?['maniqui'] as String?);
  }

  Future<void> guardar(TipoManiqui tipo) async {
    final id = supabase.auth.currentUser?.id;
    if (id == null) throw StateError('No hay una sesión iniciada.');
    final filas = await supabase.from('perfiles').update({'maniqui': tipo.clave}).eq('id', id).select('maniqui');
    /* Si la base de datos no deja modificar la fila, no lanza error pero tampoco devuelve nada */
    if (filas.isEmpty) {
      throw StateError('La base de datos no permitió guardar el maniquí.');
    }
  }
}
