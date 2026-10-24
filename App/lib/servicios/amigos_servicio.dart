import 'cliente.dart';

class Amistad {
  Amistad({
    required this.id,
    required this.estado,
    required this.soySolicitante,
    required this.otroId,
    required this.otroEmail,
    this.otroNombre,
  });

  final String id;
  final String estado;
  final bool soySolicitante;
  final String otroId;
  final String otroEmail;
  final String? otroNombre;

  String get nombreVisible => (otroNombre != null && otroNombre!.trim().isNotEmpty) ? otroNombre! : otroEmail;

  factory Amistad.desdeMapa(Map<String, dynamic> m) {
    return Amistad(
      id: m['id'] as String,
      estado: m['estado'] as String,
      soySolicitante: m['soy_solicitante'] as bool,
      otroId: m['otro_id'] as String,
      otroEmail: m['otro_email'] as String,
      otroNombre: m['otro_nombre'] as String?,
    );
  }
}

class Bloqueado {
  Bloqueado({required this.id, required this.email, this.nombre});

  final String id;
  final String email;
  final String? nombre;

  String get nombreVisible => (nombre != null && nombre!.trim().isNotEmpty) ? nombre! : email;

  factory Bloqueado.desdeMapa(Map<String, dynamic> m) {
    return Bloqueado(
      id: m['bloqueado_id'] as String,
      email: m['email'] as String,
      nombre: m['nombre'] as String?,
    );
  }
}

class AmigosServicio {
  Future<List<Amistad>> listar() async {
    final filas = await supabase.rpc('mis_amistades') as List;
    return filas.map((f) => Amistad.desdeMapa(Map<String, dynamic>.from(f as Map))).toList();
  }

  Future<List<Bloqueado>> bloqueados() async {
    final filas = await supabase.rpc('mis_bloqueos') as List;
    return filas.map((f) => Bloqueado.desdeMapa(Map<String, dynamic>.from(f as Map))).toList();
  }

  /* La función de la base de datos valida: correo existente, no auto agregarse, sin duplicados ni bloqueos */
  Future<void> enviarSolicitud(String email) async {
    await supabase.rpc('enviar_solicitud', params: {'p_email': email});
  }

  Future<void> aceptar(String amistadId) async {
    await supabase.from('amistades').update({'estado': 'aceptada'}).eq('id', amistadId);
  }

  /* Sirve para rechazar una solicitud, cancelar una enviada o eliminar a un amigo.
     Al borrar la fila, el acceso a las prendas y a la foto se corta de inmediato. */
  Future<void> eliminar(String amistadId) async {
    await supabase.from('amistades').delete().eq('id', amistadId);
  }

  Future<void> bloquear(String usuarioId) async {
    await supabase.rpc('bloquear_usuario', params: {'p_id': usuarioId});
  }

  Future<void> desbloquear(String usuarioId) async {
    await supabase.from('bloqueos').delete().eq('bloqueado_id', usuarioId);
  }
}
