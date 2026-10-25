import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../servicios/prendas_servicio.dart';
import '../servicios/recorte_fondo.dart';

class PantallaNuevaPrenda extends StatefulWidget {
  const PantallaNuevaPrenda({super.key});

  @override
  State<PantallaNuevaPrenda> createState() => _PantallaNuevaPrendaState();
}

class _PantallaNuevaPrendaState extends State<PantallaNuevaPrenda> {
  final _servicio = PrendasServicio();

  /* Foto elegida y su versión sin fondo */
  Uint8List? _original;
  String _extension = 'jpg';
  Uint8List? _recortada;
  bool _quitarFondo = true;
  double _tolerancia = 38;
  bool _procesando = false;
  String? _errorRecorte;

  String? _categoria;
  String? _color;
  String? _estilo;
  bool _guardando = false;
  String? _error;

  bool get _usaRecorte => _quitarFondo && _recortada != null;
  Uint8List? get _bytesFinales => _usaRecorte ? _recortada : _original;
  String get _extensionFinal => _usaRecorte ? 'png' : _extension;

  Future<void> _elegirFoto() async {
    /* maxWidth y imageQuality reducen el peso de la foto antes de procesarla */
    final foto = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      imageQuality: 80,
    );
    if (foto == null) return;

    final bytes = await foto.readAsBytes();
    final nombre = foto.name;
    if (!mounted) return;
    setState(() {
      _original = bytes;
      _extension = nombre.contains('.') ? nombre.split('.').last.toLowerCase() : 'jpg';
      _recortada = null;
      _errorRecorte = null;
      _error = null;
    });
    if (_quitarFondo) {
      await _procesar();
    }
  }

  /* Quita el fondo de la foto elegida y deja un PNG con transparencia */
  Future<void> _procesar() async {
    final original = _original;
    if (original == null) return;
    setState(() {
      _procesando = true;
      _errorRecorte = null;
    });
    try {
      final resultado = await recortarFondoComoPng(original, tolerancia: _tolerancia);
      if (!mounted) return;
      setState(() {
        _recortada = resultado;
        _procesando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _recortada = null;
        _procesando = false;
        _errorRecorte = 'No se pudo quitar el fondo: $e';
      });
    }
  }

  /* Descarta la foto elegida sin salir del formulario */
  void _quitarFoto() {
    setState(() {
      _original = null;
      _recortada = null;
      _extension = 'jpg';
      _errorRecorte = null;
    });
  }

  Future<void> _guardar() async {
    final bytes = _bytesFinales;
    if (bytes == null || _categoria == null || _color == null || _estilo == null) {
      setState(() => _error = 'Elige una foto, la categoría, el color y el estilo.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await _servicio.crear(
        bytes: bytes,
        extension: _extensionFinal,
        categoria: _categoria!,
        color: _color!,
        estilo: _estilo!,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = 'No se pudo guardar: $e';
      });
    }
  }

  Widget _vistaPrevia(Uint8List bytes) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 260,
        color: Colors.grey.shade300,
        child: Image.memory(bytes, fit: BoxFit.contain),
      ),
    );
  }

  Widget _controlesDeFondo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Quitar el fondo al subir'),
          subtitle: const Text('Funciona mejor con fondos lisos y claros. Se guarda la foto sin fondo.'),
          value: _quitarFondo,
          onChanged: (_procesando || _guardando)
              ? null
              : (valor) {
                  setState(() => _quitarFondo = valor);
                  if (valor && _recortada == null) {
                    _procesar();
                  }
                },
        ),
        if (_quitarFondo)
          Row(
            children: [
              const Text('Sensibilidad'),
              Expanded(
                child: Slider(
                  value: _tolerancia,
                  min: 10,
                  max: 90,
                  onChanged: (v) => setState(() => _tolerancia = v),
                  onChangeEnd: (_) => _procesar(),
                ),
              ),
            ],
          ),
        if (_procesando) const LinearProgressIndicator(),
        if (_errorRecorte != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_errorRecorte!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytesFinales;
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva prenda')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (bytes != null) _vistaPrevia(bytes),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_guardando || _procesando) ? null : _elegirFoto,
                      icon: const Icon(Icons.photo_library),
                      label: Text(_original == null ? 'Elegir foto de la galería' : 'Cambiar foto'),
                    ),
                  ),
                  if (_original != null) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: (_guardando || _procesando) ? null : _quitarFoto,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Quitar foto'),
                    ),
                  ],
                ],
              ),
              if (_original != null) ...[
                const SizedBox(height: 8),
                _controlesDeFondo(),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _categoria,
                decoration: const InputDecoration(labelText: 'Categoría *', border: OutlineInputBorder()),
                items: categorias.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _categoria = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _color,
                decoration: const InputDecoration(labelText: 'Color principal *', border: OutlineInputBorder()),
                items: colores.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _color = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _estilo,
                decoration: const InputDecoration(labelText: 'Estilo *', border: OutlineInputBorder()),
                items: estilos.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _estilo = v),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: (_guardando || _procesando) ? null : _guardar,
                child: _guardando
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Guardar prenda'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
