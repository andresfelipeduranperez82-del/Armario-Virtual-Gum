import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../servicios/prendas_servicio.dart';

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
  Uint8List? _nuevaFoto;
  String _extension = 'jpg';
  bool _ocupado = false;
  String? _error;

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
      _nuevaFoto = bytes;
      _extension = nombre.contains('.') ? nombre.split('.').last.toLowerCase() : 'jpg';
      _error = null;
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
        nuevaFoto: _nuevaFoto,
        extension: _extension,
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
    final url = widget.prenda.urlImagen;
    Widget imagen;
    if (_nuevaFoto != null) {
      imagen = Image.memory(_nuevaFoto!, height: 260, fit: BoxFit.cover);
    } else if (url != null) {
      imagen = Image.network(
        url,
        height: 260,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox(height: 260, child: Icon(Icons.broken_image, size: 48)),
      );
    } else {
      imagen = const SizedBox(height: 260, child: Icon(Icons.checkroom, size: 48));
    }
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: imagen);
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
              OutlinedButton.icon(
                onPressed: _ocupado ? null : _cambiarFoto,
                icon: const Icon(Icons.photo_library),
                label: const Text('Reemplazar foto'),
              ),
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
                onPressed: _ocupado ? null : _guardar,
                child: _ocupado
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Guardar cambios'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _ocupado ? null : _eliminar,
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
