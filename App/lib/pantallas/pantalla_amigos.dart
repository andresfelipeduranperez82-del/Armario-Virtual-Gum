import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../servicios/amigos_servicio.dart';
import '../servicios/cliente.dart';
import 'pantalla_recomendar.dart';

class PantallaAmigos extends StatefulWidget {
  const PantallaAmigos({super.key});

  @override
  State<PantallaAmigos> createState() => _PantallaAmigosState();
}

class _PantallaAmigosState extends State<PantallaAmigos> {
  final _servicio = AmigosServicio();
  final _correo = TextEditingController();

  List<Amistad> _amistades = [];
  List<Bloqueado> _bloqueados = [];
  bool _cargando = true;
  bool _enviando = false;
  String? _errorCarga;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _correo.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final amistades = await _servicio.listar();
      final bloqueados = await _servicio.bloqueados();
      if (!mounted) return;
      setState(() {
        _amistades = amistades;
        _bloqueados = bloqueados;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCarga = '$e';
        _cargando = false;
      });
    }
  }

  String _mensaje(Object e) => e is PostgrestException ? e.message : '$e';

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<bool> _confirmar(String titulo, String mensaje, String botonOk) async {
    final respuesta = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(botonOk)),
        ],
      ),
    );
    return respuesta == true;
  }

  /* Ejecuta una acción, avisa del resultado y recarga las listas */
  Future<void> _ejecutar(Future<void> Function() accion, {String? exito}) async {
    try {
      await accion();
      if (!mounted) return;
      if (exito != null) _aviso(exito);
    } catch (e) {
      if (!mounted) return;
      _aviso(_mensaje(e));
    }
    await _cargar();
  }

  Future<void> _enviarSolicitud() async {
    final correo = _correo.text.trim();
    if (correo.isEmpty) {
      _aviso('Escribe el correo de Gmail de tu amigo.');
      return;
    }
    setState(() => _enviando = true);
    try {
      await _servicio.enviarSolicitud(correo);
      _correo.clear();
      if (!mounted) return;
      _aviso('Solicitud enviada a $correo');
    } catch (e) {
      if (!mounted) return;
      _aviso(_mensaje(e));
    }
    if (!mounted) return;
    setState(() => _enviando = false);
    await _cargar();
  }

  Future<void> _recomendar(Amistad a) async {
    final enviada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PantallaRecomendar(amigoId: a.otroId, amigoNombre: a.nombreVisible),
      ),
    );
    if (enviada == true && mounted) {
      _aviso('Recomendación enviada a ${a.nombreVisible}');
    }
  }

  Future<void> _eliminarAmigo(Amistad a) async {
    final ok = await _confirmar(
      'Eliminar amigo',
      '${a.nombreVisible} dejará de ver tus prendas, tus outfits y tu foto. ¿Deseas continuar?',
      'Eliminar',
    );
    if (ok) {
      await _ejecutar(() => _servicio.eliminar(a.id), exito: 'Amigo eliminado');
    }
  }

  Future<void> _bloquear(Amistad a) async {
    final ok = await _confirmar(
      'Bloquear usuario',
      '${a.nombreVisible} perderá el acceso a tu armario y no podrá enviarte solicitudes. ¿Deseas continuar?',
      'Bloquear',
    );
    if (ok) {
      await _ejecutar(() => _servicio.bloquear(a.otroId), exito: 'Usuario bloqueado');
    }
  }

  Widget _titulo(String texto) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(texto, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }

  Widget _fila({required String nombre, required String correo, required Widget acciones}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (nombre != correo) Text(correo, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
            acciones,
          ],
        ),
      ),
    );
  }

  Widget _formularioSolicitud() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _correo,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo de Gmail de tu amigo',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _enviarSolicitud(),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: _enviando ? null : _enviarSolicitud,
              child: _enviando
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Enviar solicitud'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recibidas = _amistades.where((a) => a.estado == 'pendiente' && !a.soySolicitante).toList();
    final enviadas = _amistades.where((a) => a.estado == 'pendiente' && a.soySolicitante).toList();
    final amigos = _amistades.where((a) => a.estado == 'aceptada').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Amigos'),
        actions: [
          IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh), tooltip: 'Actualizar'),
          TextButton(
            onPressed: () => supabase.auth.signOut(),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _errorCarga != null
                  ? Center(child: Text('Error al cargar: $_errorCarga'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _formularioSolicitud(),
                        if (recibidas.isNotEmpty) ...[
                          _titulo('Solicitudes recibidas'),
                          ...recibidas.map(
                            (a) => _fila(
                              nombre: a.nombreVisible,
                              correo: a.otroEmail,
                              acciones: Wrap(
                                spacing: 8,
                                children: [
                                  TextButton(
                                    onPressed: () => _ejecutar(() => _servicio.eliminar(a.id)),
                                    child: const Text('Rechazar'),
                                  ),
                                  FilledButton(
                                    onPressed: () => _ejecutar(
                                      () => _servicio.aceptar(a.id),
                                      exito: 'Ahora eres amigo de ${a.nombreVisible}',
                                    ),
                                    child: const Text('Aceptar'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (enviadas.isNotEmpty) ...[
                          _titulo('Solicitudes enviadas'),
                          ...enviadas.map(
                            (a) => _fila(
                              nombre: a.nombreVisible,
                              correo: a.otroEmail,
                              acciones: TextButton(
                                onPressed: () => _ejecutar(() => _servicio.eliminar(a.id), exito: 'Solicitud cancelada'),
                                child: const Text('Cancelar'),
                              ),
                            ),
                          ),
                        ],
                        _titulo('Mis amigos (${amigos.length})'),
                        if (amigos.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text('Aún no tienes amigos. Envía una solicitud con su correo de Gmail.'),
                          ),
                        ...amigos.map(
                          (a) => _fila(
                            nombre: a.nombreVisible,
                            correo: a.otroEmail,
                            acciones: PopupMenuButton<String>(
                              onSelected: (valor) {
                                if (valor == 'recomendar') {
                                  _recomendar(a);
                                } else if (valor == 'eliminar') {
                                  _eliminarAmigo(a);
                                } else {
                                  _bloquear(a);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(value: 'recomendar', child: Text('Armar un outfit para esta persona')),
                                PopupMenuItem(value: 'eliminar', child: Text('Eliminar amigo')),
                                PopupMenuItem(value: 'bloquear', child: Text('Bloquear')),
                              ],
                            ),
                          ),
                        ),
                        if (_bloqueados.isNotEmpty) ...[
                          _titulo('Bloqueados'),
                          ...(_bloqueados.map(
                            (b) => _fila(
                              nombre: b.nombreVisible,
                              correo: b.email,
                              acciones: TextButton(
                                onPressed: () => _ejecutar(
                                  () => _servicio.desbloquear(b.id),
                                  exito: 'Usuario desbloqueado',
                                ),
                                child: const Text('Desbloquear'),
                              ),
                            ),
                          )),
                        ],
                      ],
                    ),
        ),
      ),
    );
  }
}
