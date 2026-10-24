import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../servicios/prendas_servicio.dart';
import '../servicios/recomendaciones_servicio.dart';
import '../servicios/reglas_outfit.dart';
import '../widgets/prenda_elegible.dart';

/* Pantalla para armarle un outfit a un amigo usando las prendas de su armario */
class PantallaRecomendar extends StatefulWidget {
  const PantallaRecomendar({super.key, required this.amigoId, required this.amigoNombre});

  final String amigoId;
  final String amigoNombre;

  @override
  State<PantallaRecomendar> createState() => _PantallaRecomendarState();
}

class _PantallaRecomendarState extends State<PantallaRecomendar> {
  final _servicio = RecomendacionesServicio();
  final _nombre = TextEditingController();

  late final Future<List<Prenda>> _futuro = _servicio.prendasDe(widget.amigoId);
  List<Prenda> _prendas = [];
  final Set<String> _seleccion = {};
  String? _estilo;
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  List<Prenda> get _elegidas => _prendas.where((p) => _seleccion.contains(p.id)).toList();

  Future<void> _enviar() async {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty || _estilo == null) {
      setState(() => _error = 'Escribe un nombre y elige un estilo para la recomendación.');
      return;
    }
    final problema = revisarReglasOutfit(_elegidas);
    if (problema != null) {
      setState(() => _error = problema);
      return;
    }

    setState(() {
      _enviando = true;
      _error = null;
    });

    try {
      await _servicio.enviar(
        amigoId: widget.amigoId,
        nombre: nombre,
        estilo: _estilo!,
        prendaIds: _seleccion.toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _error = 'No se pudo enviar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Armar outfit para ${widget.amigoNombre}')),
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
            return Center(child: Text('${widget.amigoNombre} todavía no tiene prendas en su armario.'));
          }

          final sugerencia = revisarReglasOutfit(_elegidas);
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
                    return PrendaElegible(
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
                      onPressed: _enviando ? null : _enviar,
                      child: _enviando
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Enviar recomendación'),
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
