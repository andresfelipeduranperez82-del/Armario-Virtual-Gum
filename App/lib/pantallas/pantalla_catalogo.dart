import 'package:flutter/material.dart';

import '../servicios/prendas_servicio.dart';
import '../servicios/sincronizacion.dart';
import '../widgets/barra_filtros_gum.dart';
import 'pantalla_editar_prenda.dart';
import 'pantalla_nueva_prenda.dart';

class PantallaCatalogo extends StatefulWidget {
  const PantallaCatalogo({super.key, this.alIrA});

  /* Cambia de pestaña en la pantalla principal: 1 Outfits, 2 Amigos, 3 Recomendaciones, 4 Perfil */
  final ValueChanged<int>? alIrA;

  @override
  State<PantallaCatalogo> createState() => _PantallaCatalogoState();
}

class _PantallaCatalogoState extends State<PantallaCatalogo> {
  final _servicio = PrendasServicio();
  late Future<List<Prenda>> _futuro;
  List<Prenda>? _ultimas;

  /* Filtros activos. Si valen null, ese filtro no se aplica */
  String? _filtroCategoria;
  String? _filtroEstilo;
  String? _filtroColor;

  @override
  void initState() {
    super.initState();
    _futuro = _servicio.listar();
    Sincronizacion.instancia.tema('prendas').addListener(_alCambiarDatos);
  }

  @override
  void dispose() {
    Sincronizacion.instancia.tema('prendas').removeListener(_alCambiarDatos);
    super.dispose();
  }

  /* Otro dispositivo cambió tus prendas: se recarga el catálogo */
  void _alCambiarDatos() {
    if (mounted) _recargar();
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

  /* Las prendas se acomodan en filas centradas. Si una fila se llena, la siguiente prenda baja */
  Widget _rejilla(List<Prenda> visibles) {
    return LayoutBuilder(
      builder: (context, restricciones) {
        /* En pantallas angostas caben dos por fila, en las anchas cada tarjeta mide 180 */
        final ancho = restricciones.maxWidth < 420 ? (restricciones.maxWidth - 32 - 12) / 2 : 180.0;
        final alto = ancho / 0.8;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final p in visibles)
                    _Aparece(
                      key: ValueKey(p.id),
                      child: SizedBox(
                        width: ancho,
                        height: alto,
                        child: _TarjetaPrenda(prenda: p, alTocar: () => _editar(p)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregar,
        icon: const Icon(Icons.add),
        label: const Text('Agregar prenda'),
      ),
      body: Column(
        children: [
          BarraFiltrosGum(
            opcionesCategoria: categorias,
            categoriaElegida: _filtroCategoria,
            alElegirCategoria: (clave) => setState(() => _filtroCategoria = clave),
            opcionesEstilo: estilos,
            estiloElegido: _filtroEstilo,
            alElegirEstilo: (clave) => setState(() => _filtroEstilo = clave),
            opcionesColor: {for (final c in colores) c: c},
            colorElegido: _filtroColor,
            alElegirColor: (clave) => setState(() => _filtroColor = clave),
            sinFiltros: !_hayFiltros,
            alMostrarTodas: _limpiarFiltros,
            alIrA: widget.alIrA ?? (_) {},
          ),
          Expanded(
            child: FutureBuilder<List<Prenda>>(
              future: _futuro,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error al cargar: ${snapshot.error}'));
                }
                /* Mientras se recarga se siguen mostrando los datos anteriores, para que no parpadee */
                final recibidas = snapshot.data ?? _ultimas;
                if (recibidas == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                _ultimas = recibidas;
                final todas = recibidas;
                if (todas.isEmpty) {
                  return const Center(child: Text('Aún no tienes prendas. Agrega la primera.'));
                }

                final visibles = _filtrar(todas);
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Center(child: Text('Mostrando ${visibles.length} de ${todas.length} prendas')),
                    ),
                    Expanded(
                      child: visibles.isEmpty
                          ? const Center(child: Text('Ninguna prenda coincide con los filtros.'))
                          : _rejilla(visibles),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/* Animación de entrada: la prenda aparece con un fundido y un leve acercamiento.
   Como cada una tiene su llave, solo se anima la que entra, no las que ya estaban */
class _Aparece extends StatelessWidget {
  const _Aparece({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, t, hijo) {
        return Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.9 + 0.1 * t, child: hijo),
        );
      },
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
      margin: EdgeInsets.zero,
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
