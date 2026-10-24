import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../servicios/outfits_servicio.dart';
import '../servicios/prendas_servicio.dart';

class PantallaNuevoOutfit extends StatefulWidget {
  const PantallaNuevoOutfit({super.key});

  @override
  State<PantallaNuevoOutfit> createState() => _PantallaNuevoOutfitState();
}

class _PantallaNuevoOutfitState extends State<PantallaNuevoOutfit> {
  final _prendasServicio = PrendasServicio();
  final _outfitsServicio = OutfitsServicio();
  final _nombre = TextEditingController();

  late final Future<List<Prenda>> _futuro = _prendasServicio.listar();
  List<Prenda> _prendas = [];
  final Set<String> _seleccion = {};
  String? _estilo;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  List<Prenda> get _elegidas => _prendas.where((p) => _seleccion.contains(p.id)).toList();

  /* Misma regla que valida la base de datos, para avisar antes de guardar */
  String? _revisarReglas(List<Prenda> elegidas) {
    if (elegidas.isEmpty) {
      return 'Selecciona las prendas del outfit.';
    }
    final conteo = <String, int>{};
    for (final p in elegidas) {
      conteo[p.categoria] = (conteo[p.categoria] ?? 0) + 1;
    }
    for (final e in conteo.entries) {
      if (e.key != 'accesorios' && e.value > 1) {
        return 'Solo se permite una prenda por categoría, excepto accesorios. Revisa: ${categorias[e.key]}.';
      }
    }
    final conSuperiorEInferior = (conteo['superior'] ?? 0) >= 1 && (conteo['inferior'] ?? 0) >= 1;
    final conCuerpoCompleto = (conteo['cuerpo_completo'] ?? 0) >= 1;
    if (!conSuperiorEInferior && !conCuerpoCompleto) {
      return 'Elige una prenda superior y una inferior, o una de cuerpo completo.';
    }
    return null;
  }

  Future<void> _guardar() async {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty || _estilo == null) {
      setState(() => _error = 'Escribe un nombre y elige un estilo para el outfit.');
      return;
    }
    final problema = _revisarReglas(_elegidas);
    if (problema != null) {
      setState(() => _error = problema);
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await _outfitsServicio.crear(
        nombre: nombre,
        estilo: _estilo!,
        prendaIds: _seleccion.toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = 'No se pudo guardar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo outfit')),
      body: FutureBuilder<List<Prenda>>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar: ${snapshot.error}'));
          }
          _prendas = snapshot.data ?? [];
          if (_prendas.isEmpty) {
            return const Center(child: Text('Primero agrega prendas en la pestaña Prendas.'));
          }

          final sugerencia = _revisarReglas(_elegidas);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _nombre,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del outfit *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<String>(
                        initialValue: _estilo,
                        decoration: const InputDecoration(
                          labelText: 'Estilo *',
                          border: OutlineInputBorder(),
                        ),
                        items: estilos.entries
                            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                            .toList(),
                        onChanged: (v) => setState(() => _estilo = v),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    sugerencia ?? 'Combinación válida (${_seleccion.length} prendas).',
                    style: TextStyle(
                      color: sugerencia == null ? Colors.green.shade700 : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _prendas.length,
                  itemBuilder: (context, i) {
                    final prenda = _prendas[i];
                    final elegida = _seleccion.contains(prenda.id);
                    return _PrendaElegible(
                      prenda: prenda,
                      elegida: elegida,
                      alTocar: () => setState(() {
                        if (elegida) {
                          _seleccion.remove(prenda.id);
                        } else {
                          _seleccion.add(prenda.id);
                        }
                        _error = null;
                      }),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      const SizedBox(height: 8),
                    ],
                    FilledButton(
                      onPressed: _guardando ? null : _guardar,
                      child: _guardando
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Guardar outfit'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PrendaElegible extends StatelessWidget {
  const _PrendaElegible({required this.prenda, required this.elegida, required this.alTocar});

  final Prenda prenda;
  final bool elegida;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final url = prenda.urlImagen;
    final color = Theme.of(context).colorScheme.primary;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: elegida ? color : Colors.transparent, width: 3),
      ),
      child: InkWell(
        onTap: alTocar,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: url == null
                      ? const Icon(Icons.checkroom, size: 40)
                      : Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 40),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    '${categorias[prenda.categoria] ?? prenda.categoria}, ${prenda.colorPrincipal}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            if (elegida)
              Positioned(
                top: 6,
                right: 6,
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: color,
                  child: const Icon(Icons.check, size: 16, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
