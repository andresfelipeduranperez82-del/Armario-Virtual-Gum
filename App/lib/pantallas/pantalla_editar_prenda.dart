import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../servicios/cliente.dart';
import '../servicios/prendas_servicio.dart';
import '../servicios/recorte_fondo.dart';

class PantallaEditarPrenda extends StatefulWidget {
  const PantallaEditarPrenda({super.key, required this.prenda});

  final Prenda prenda;

  @override
  State<PantallaEditarPrenda> createState() => _PantallaEditarPrendaState();
}

class _PantallaEditarPrendaState extends State<PantallaEditarPrenda> {
  final _servicio = PrendasServicio();

  late String _categoria = widget.prenda.categoria;
  late String _color = widget.prenda.colorPrincipal;
  late String _estilo = widget.prenda.estilo;

  /* Foto nueva (elegida o tomada de la actual) y su versión sin fondo */
  Uint8List? _nuevaOriginal;
  String _extension = 'jpg';
  Uint8List? _nuevaRecortada;
  bool _quitarFondo = true;
  double _tolerancia = 38;
  bool _procesando = false;
  String? _errorRecorte;

  bool _ocupado = false;
  String? _error;

  bool get _usaRecorte => _quitarFondo && _nuevaRecortada != null;
  Uint8List? get _bytesNuevos => _usaRecorte ? _nuevaRecortada : _nuevaOriginal;
  String get _extensionFinal => _usaRecorte ? 'png' : _extension;
  bool get _bloqueado => _ocupado || _procesando;

  Future<void> _cambiarFoto() async {
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
      _nuevaOriginal = bytes;
      _extension = nombre.contains('.') ? nombre.split('.').last.toLowerCase() : 'jpg';
      _nuevaRecortada = null;
      _quitarFondo = true;
      _errorRecorte = null;
      _error = null;
    });
    await _procesar();
  }

  /* Toma la foto que ya está guardada, le quita el fondo y la deja lista para reemplazarla */
  Future<void> _quitarFondoDeLaFotoActual() async {
    setState(() {
      _procesando = true;
      _errorRecorte = null;
      _error = null;
    });
    try {
      final ruta = widget.prenda.imagenPath;
      final bytes = await supabase.storage.from('prendas').download(ruta);
      final extension = ruta.contains('.') ? ruta.split('.').last.toLowerCase() : 'jpg';
      if (!mounted) return;
      setState(() {
        _nuevaOriginal = bytes;
        _extension = extension;
        _nuevaRecortada = null;
        _quitarFondo = true;
      });
      await _procesar();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _procesando = false;
        _errorRecorte = 'No se pudo descargar la foto actual: $e';
      });
    }
  }

  Future<void> _procesar() async {
    final original = _nuevaOriginal;
    if (original == null) return;
    setState(() {
      _procesando = true;
      _errorRecorte = null;
    });
    try {
      final resultado = await recortarFondoComoPng(original, tolerancia: _tolerancia);
      if (!mounted) return;
      setState(() {
        _nuevaRecortada = resultado;
        _procesando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _nuevaRecortada = null;
        _procesando = false;
        _errorRecorte = 'No se pudo quitar el fondo: $e';
      });
    }
  }

  void _descartarCambioDeFoto() {
    setState(() {
      _nuevaOriginal = null;
      _nuevaRecortada = null;
      _errorRecorte = null;
    });
  }

  Future<void> _guardar() async {
    setState(() {
      _ocupado = true;
      _error = null;
    });

    try {
      /* Cambiar la categoría de una prenda que está en outfits podría romper las reglas del outfit */
      if (_categoria != widget.prenda.categoria) {
        final enOutfits = await _servicio.contarOutfits(widget.prenda.id);
        if (enOutfits > 0) {
          if (!mounted) return;
          setState(() {
            _ocupado = false;
            _error = 'No puedes cambiar la categoría de una prenda que está en outfits.';
          });
          return;
        }
      }

      await _servicio.actualizar(
        prenda: widget.prenda,
        categoria: _categoria,
        color: _color,
        estilo: _estilo,
        nuevaFoto: _bytesNuevos,
        extension: _extensionFinal,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _error = 'No se pudo guardar: $e';
      });
    }
  }

  Future<void> _eliminar() async {
    setState(() {
      _ocupado = true;
      _error = null;
    });

    try {
      final cantidad = await _servicio.contarOutfits(widget.prenda.id);
      if (!mounted) return;
      setState(() => _ocupado = false);

      final mensaje = cantidad == 0
          ? '¿Seguro que quieres eliminar esta prenda?'
          : cantidad == 1
              ? 'Esta prenda está en 1 outfit, que también se eliminará. ¿Deseas continuar?'
              : 'Esta prenda está en $cantidad outfits, que también se eliminarán. ¿Deseas continuar?';

      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Eliminar prenda'),
          content: Text(mensaje),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
          ],
        ),
      );
      if (confirmar != true || !mounted) return;

      setState(() => _ocupado = true);
      await _servicio.eliminar(widget.prenda);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _error = 'No se pudo eliminar: $e';
      });
    }
  }

  Widget _vistaPrevia() {
    final nuevos = _bytesNuevos;
    final url = widget.prenda.urlImagen;
    Widget imagen;
    if (nuevos != null) {
      imagen = Image.memory(nuevos, height: 260, fit: BoxFit.contain);
    } else if (url != null) {
      imagen = Image.network(
        url,
        height: 260,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const SizedBox(height: 260, child: Icon(Icons.broken_image, size: 48)),
      );
    } else {
      imagen = const SizedBox(height: 260, child: Icon(Icons.checkroom, size: 48));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 260,
        width: double.infinity,
        color: Colors.grey.shade300,
        child: Center(child: imagen),
      ),
    );
  }

  Widget _controlesDeFondo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Quitar el fondo'),
          subtitle: const Text('Funciona mejor con fondos lisos y claros. Al guardar, reemplaza la foto actual.'),
          value: _quitarFondo,
          onChanged: _bloqueado
              ? null
              : (valor) {
                  setState(() => _quitarFondo = valor);
                  if (valor && _nuevaRecortada == null) {
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
    return Scaffold(
      appBar: AppBar(title: const Text('Editar prenda')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _vistaPrevia(),
              const SizedBox(height: 12),
              if (_nuevaOriginal == null) ...[
                OutlinedButton.icon(
                  onPressed: _bloqueado ? null : _cambiarFoto,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Reemplazar foto'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _bloqueado ? null : _quitarFondoDeLaFotoActual,
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Quitar el fondo de la foto actual'),
                ),
                if (_procesando) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
                if (_errorRecorte != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_errorRecorte!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _bloqueado ? null : _cambiarFoto,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Elegir otra foto'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _bloqueado ? null : _descartarCambioDeFoto,
                      child: const Text('Descartar cambio'),
                    ),
                  ],
                ),
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
                onChanged: (v) => setState(() => _categoria = v ?? _categoria),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _color,
                decoration: const InputDecoration(labelText: 'Color principal *', border: OutlineInputBorder()),
                items: colores.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _color = v ?? _color),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _estilo,
                decoration: const InputDecoration(labelText: 'Estilo *', border: OutlineInputBorder()),
                items: estilos.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _estilo = v ?? _estilo),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _bloqueado ? null : _guardar,
                child: _ocupado
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Guardar cambios'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _bloqueado ? null : _eliminar,
                style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Eliminar prenda'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
