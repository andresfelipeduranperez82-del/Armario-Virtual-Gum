import 'package:flutter/material.dart';

import '../servicios/cliente.dart';
import '../servicios/prendas_servicio.dart';
import 'pantalla_editar_prenda.dart';
import 'pantalla_nueva_prenda.dart';

class PantallaCatalogo extends StatefulWidget {
  const PantallaCatalogo({super.key});

  @override
  State<PantallaCatalogo> createState() => _PantallaCatalogoState();
}

class _PantallaCatalogoState extends State<PantallaCatalogo> {
  final _servicio = PrendasServicio();
  late Future<List<Prenda>> _futuro;

  /* Filtros activos. Si valen null, ese filtro no se aplica */
  String? _filtroCategoria;
  String? _filtroEstilo;
  String? _filtroColor;

  @override
  void initState() {
    super.initState();
    _futuro = _servicio.listar();
  }

  void _recargar() {
    setState(() {
      _futuro = _servicio.listar();
    });
  }

  Future<void> _agregar() async {
    final guardada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PantallaNuevaPrenda()),
    );
    if (guardada == true) {
      _recargar();
    }
  }

  Future<void> _editar(Prenda prenda) async {
    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PantallaEditarPrenda(prenda: prenda)),
    );
    if (cambio == true) {
      _recargar();
    }
  }

  bool get _hayFiltros => _filtroCategoria != null || _filtroEstilo != null || _filtroColor != null;

  void _limpiarFiltros() {
    setState(() {
      _filtroCategoria = null;
      _filtroEstilo = null;
      _filtroColor = null;
    });
  }

  List<Prenda> _filtrar(List<Prenda> todas) {
    return todas.where((p) {
      final coincideCategoria = _filtroCategoria == null || p.categoria == _filtroCategoria;
      final coincideEstilo = _filtroEstilo == null || p.estilo == _filtroEstilo;
      final coincideColor = _filtroColor == null || p.colorPrincipal == _filtroColor;
      return coincideCategoria && coincideEstilo && coincideColor;
    }).toList();
  }

  Widget _filtro({
    required String titulo,
    required String etiquetaTodos,
    required String? valor,
    required Map<String, String> opciones,
    required ValueChanged<String?> alCambiar,
  }) {
    return SizedBox(
      width: 200,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: titulo,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            isDense: true,
            isExpanded: true,
            value: valor,
            items: [
              DropdownMenuItem<String?>(value: null, child: Text(etiquetaTodos)),
              ...opciones.entries.map(
                (e) => DropdownMenuItem<String?>(value: e.key, child: Text(e.value)),
              ),
            ],
            onChanged: alCambiar,
          ),
        ),
      ),
    );
  }

  Widget _barraDeFiltros() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _filtro(
            titulo: 'Categoría',
            etiquetaTodos: 'Todas',
            valor: _filtroCategoria,
            opciones: categorias,
            alCambiar: (v) => setState(() => _filtroCategoria = v),
          ),
          _filtro(
            titulo: 'Estilo',
            etiquetaTodos: 'Todos',
            valor: _filtroEstilo,
            opciones: estilos,
            alCambiar: (v) => setState(() => _filtroEstilo = v),
          ),
          _filtro(
            titulo: 'Color',
            etiquetaTodos: 'Todos',
            valor: _filtroColor,
            opciones: {for (final c in colores) c: c},
            alCambiar: (v) => setState(() => _filtroColor = v),
          ),
          if (_hayFiltros)
            TextButton.icon(
              onPressed: _limpiarFiltros,
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Limpiar filtros'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi armario'),
        actions: [
          TextButton(
            onPressed: () => supabase.auth.signOut(),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregar,
        icon: const Icon(Icons.add),
        label: const Text('Agregar prenda'),
      ),
      body: FutureBuilder<List<Prenda>>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar: ${snapshot.error}'));
          }
          final todas = snapshot.data ?? [];
          if (todas.isEmpty) {
            return const Center(child: Text('Aún no tienes prendas. Agrega la primera.'));
          }

          final visibles = _filtrar(todas);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _barraDeFiltros(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text('Mostrando ${visibles.length} de ${todas.length} prendas'),
              ),
              Expanded(
                child: visibles.isEmpty
                    ? const Center(child: Text('Ninguna prenda coincide con los filtros.'))
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: visibles.length,
                        itemBuilder: (context, i) => _TarjetaPrenda(
                          prenda: visibles[i],
                          alTocar: () => _editar(visibles[i]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TarjetaPrenda extends StatelessWidget {
  const _TarjetaPrenda({required this.prenda, required this.alTocar});

  final Prenda prenda;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final url = prenda.urlImagen;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alTocar,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: url == null
                ? const Icon(Icons.checkroom, size: 48)
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 48),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              '${categorias[prenda.categoria] ?? prenda.categoria}, ${prenda.colorPrincipal}, ${estilos[prenda.estilo] ?? prenda.estilo}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
        ),
      ),
    );
  }
}