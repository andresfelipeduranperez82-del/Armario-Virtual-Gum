import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../servicios/cliente.dart';
import '../servicios/perfil_servicio.dart';

class PantallaPerfil extends StatefulWidget {
  const PantallaPerfil({super.key});

  @override
  State<PantallaPerfil> createState() => _PantallaPerfilState();
}

class _PantallaPerfilState extends State<PantallaPerfil> {
  final _servicio = PerfilServicio();

  Perfil? _perfil;
  bool _cargando = true;
  bool _ocupado = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final perfil = await _servicio.cargar();
      if (!mounted) return;
      setState(() {
        _perfil = perfil;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al cargar el perfil: $e';
        _cargando = false;
      });
    }
  }

  Future<void> _elegirFoto() async {
    final foto = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (foto == null) return;

    final bytes = await foto.readAsBytes();
    final nombre = foto.name;
    final extension = nombre.contains('.') ? nombre.split('.').last.toLowerCase() : 'jpg';

    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await _servicio.subirFoto(
        bytes: bytes,
        extension: extension,
        rutaAnterior: _perfil?.fotoPath,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo subir la foto: $e');
    }
    if (!mounted) return;
    setState(() => _ocupado = false);
    await _cargar();
  }

  Future<void> _quitarFoto() async {
    final ruta = _perfil?.fotoPath;
    if (ruta == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar foto'),
        content: const Text('Se usará un modelo neutro en el probador. ¿Deseas continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Quitar')),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await _servicio.quitarFoto(ruta);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo quitar la foto: $e');
    }
    if (!mounted) return;
    setState(() => _ocupado = false);
    await _cargar();
  }

  Widget _foto(Perfil perfil) {
    final url = perfil.urlFoto;
    final fondo = Theme.of(context).colorScheme.surfaceContainerHighest;
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: url == null
            ? Container(
                color: fondo,
                child: const Icon(Icons.accessibility_new, size: 160),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: fondo,
                  child: const Icon(Icons.broken_image, size: 80),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final perfil = _perfil;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        actions: [
          TextButton(
            onPressed: () => supabase.auth.signOut(),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : perfil == null
              ? Center(child: Text(_error ?? 'No se encontró el perfil.'))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          (perfil.nombre != null && perfil.nombre!.trim().isNotEmpty) ? perfil.nombre! : perfil.email,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                        Text(perfil.email),
                        const SizedBox(height: 16),
                        _foto(perfil),
                        const SizedBox(height: 8),
                        Text(
                          perfil.urlFoto == null
                              ? 'Sin foto personal: el probador usará un modelo neutro.'
                              : 'Esta foto la ven solo tus amigos confirmados.',
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _ocupado ? null : _elegirFoto,
                          icon: const Icon(Icons.photo_library),
                          label: Text(perfil.urlFoto == null ? 'Subir foto de cuerpo completo' : 'Reemplazar foto'),
                        ),
                        if (perfil.fotoPath != null) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _ocupado ? null : _quitarFoto,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Quitar foto'),
                          ),
                        ],
                        if (_ocupado) ...[
                          const SizedBox(height: 16),
                          const Center(child: CircularProgressIndicator()),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        ],
                        const SizedBox(height: 12),
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cómo tomar la foto para el probador',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                SizedBox(height: 8),
                                Text('• De pie, de frente, con la espalda recta y los brazos un poco separados del cuerpo.'),
                                Text('• Cuerpo completo: que se vea desde la cabeza hasta los pies.'),
                                Text('• Foto vertical, con la persona centrada y sin cortar los pies.'),
                                Text('• Fondo liso y claro, y buena luz de frente.'),
                                Text('• Ropa ajustada y de color neutro, para que las prendas se vean mejor encima.'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
