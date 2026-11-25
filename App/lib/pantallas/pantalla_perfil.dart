import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../servicios/cliente.dart';
import '../servicios/maniqui_servicio.dart';
import '../servicios/perfil_servicio.dart';
import '../servicios/sincronizacion.dart';
import '../servicios/tema.dart';
import '../widgets/maniqui.dart';

class PantallaPerfil extends StatefulWidget {
  const PantallaPerfil({super.key});

  @override
  State<PantallaPerfil> createState() => _PantallaPerfilState();
}

class _PantallaPerfilState extends State<PantallaPerfil> {
  final _servicio = PerfilServicio();
  final _servicioManiqui = ManiquiServicio();

  Perfil? _perfil;
  TipoManiqui? _maniqui;
  bool _cargando = true;
  bool _ocupado = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
    Sincronizacion.instancia.tema('perfil').addListener(_alCambiarDatos);
  }

  @override
  void dispose() {
    Sincronizacion.instancia.tema('perfil').removeListener(_alCambiarDatos);
    super.dispose();
  }

  /* Tu perfil cambió en otro dispositivo: se recarga sin mostrar el indicador de carga */
  void _alCambiarDatos() {
    if (mounted) _cargar(silencioso: true);
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    try {
      final perfil = await _servicio.cargar();
      /* Si no se puede leer el maniquí, se sigue mostrando el perfil con uno neutro */
      TipoManiqui? maniqui;
      try {
        maniqui = await _servicioManiqui.cargar();
      } catch (_) {
        maniqui = null;
      }
      if (!mounted) return;
      setState(() {
        _perfil = perfil;
        _maniqui = maniqui;
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

  /* Guarda el maniquí elegido. Si falla, vuelve al anterior y avisa */
  Future<void> _elegirManiqui(TipoManiqui tipo) async {
    final anterior = _maniqui;
    setState(() {
      _maniqui = tipo;
      _error = null;
    });
    try {
      await _servicioManiqui.guardar(tipo);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _maniqui = anterior;
        _error = 'No se pudo guardar el maniquí: $e';
      });
    }
  }

  Widget _selectorManiqui() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tu maniquí', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(
              'Se dibuja en el editor de outfits cuando no tienes una foto personal.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<TipoManiqui>(
                emptySelectionAllowed: true,
                segments: [
                  for (final tipo in TipoManiqui.values)
                    ButtonSegment(
                      value: tipo,
                      label: Text(tipo.nombre),
                      icon: Icon(tipo == TipoManiqui.masculino ? Icons.male : Icons.female),
                    ),
                ],
                selected: {if (_maniqui != null) _maniqui!},
                onSelectionChanged: (elegido) {
                  if (elegido.isNotEmpty) _elegirManiqui(elegido.first);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _foto(Perfil perfil) {
    final url = perfil.urlFoto;
    final fondo = Theme.of(context).colorScheme.surfaceContainerHighest;
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: url == null
            ? Container(color: fondo, child: Maniqui(tipo: _maniqui))
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

  /* Selector de tema: claro, oscuro o el que use el sistema */
  Widget _apariencia() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Apariencia', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: TemaServicio.instancia.modo,
              builder: (context, modo, _) => SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, label: Text('Claro'), icon: Icon(Icons.light_mode)),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Oscuro'), icon: Icon(Icons.dark_mode)),
                    ButtonSegment(value: ThemeMode.system, label: Text('Sistema'), icon: Icon(Icons.brightness_auto)),
                  ],
                  selected: {modo},
                  onSelectionChanged: (s) => TemaServicio.instancia.cambiar(s.first),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final perfil = _perfil;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
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
                              ? 'Sin foto personal: el editor de outfits usará tu maniquí.'
                              : 'Esta foto la ven solo tus amigos confirmados.',
                          style: const TextStyle(fontSize: 13),
                        ),
                        if (perfil.urlFoto == null) ...[
                          const SizedBox(height: 12),
                          _selectorManiqui(),
                        ],
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
                        const SizedBox(height: 12),
                        _apariencia(),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => supabase.auth.signOut(),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.logout),
                            label: const Text('Cerrar sesión'),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
    );
  }
}
