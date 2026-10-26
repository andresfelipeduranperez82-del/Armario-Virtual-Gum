import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../servicios/cliente.dart';
import '../servicios/outfits_servicio.dart';
import '../servicios/perfil_servicio.dart';
import '../servicios/prendas_servicio.dart';
import '../servicios/recomendaciones_servicio.dart';
import '../servicios/reglas_outfit.dart';
import '../widgets/prenda_elegible.dart';

/* Una prenda puesta sobre el lienzo.
   El centro va como fracción del lienzo. El anclaje vertical dice qué punto de la prenda
   queda sobre ese centro: 0 es el borde de arriba, 0.5 el medio y 1 el borde de abajo. */
class _Capa {
  _Capa({
    required this.prenda,
    required this.centro,
    required this.ancho,
    required this.anclaVertical,
  });

  final Prenda prenda;
  Offset centro;
  double ancho;
  final double anclaVertical;
  double angulo = 0;
  bool volteada = false;
}

class _Datos {
  _Datos({
    required this.prendas,
    required this.perfil,
    required this.outfits,
    required this.recomendaciones,
    this.errorOutfits,
    this.errorRecomendaciones,
  });

  final List<Prenda> prendas;
  final Perfil? perfil;
  final List<Outfit> outfits;
  final List<Recomendacion> recomendaciones;
  final String? errorOutfits;
  final String? errorRecomendaciones;
}

class _DatosOutfit {
  _DatosOutfit(this.nombre, this.estilo);

  final String nombre;
  final String estilo;
}

enum _Seccion { armario, outfits }

enum _SubSeccion { mios, recomendados }

/* Pestaña de outfits con diseño de editor de avatares.
   A la izquierda: el armario y los outfits. A la derecha: tu foto o un lienzo sin persona. */
class PantallaOutfits extends StatefulWidget {
  const PantallaOutfits({super.key});

  @override
  State<PantallaOutfits> createState() => _PantallaOutfitsState();
}

class _PantallaOutfitsState extends State<PantallaOutfits> {
  static const _ordenDeDibujo = ['cuerpo_completo', 'inferior', 'calzado', 'superior', 'abrigo', 'accesorios'];
  static const _anchoMinimo = 0.08;
  static const _anchoMaximo = 1.2;

  final _prendasServicio = PrendasServicio();
  final _outfitsServicio = OutfitsServicio();
  final _recomendacionesServicio = RecomendacionesServicio();
  late Future<_Datos> _futuro = _cargar();

  final List<_Capa> _equipadas = [];
  String? _seleccionadaId;
  String? _filtroCategoria;
  String? _mostrando;
  _Seccion _seccion = _Seccion.armario;
  _SubSeccion _subSeccion = _SubSeccion.mios;
  bool _conPerfil = true;
  bool _sombra = true;
  bool _guardando = false;
  double _anchoInicial = 0.5;
  double _anguloInicial = 0;

  Future<_Datos> _cargar() async {
    final prendas = await _prendasServicio.listar();

    Perfil? perfil;
    try {
      perfil = await PerfilServicio().cargar();
    } catch (_) {
      perfil = null;
    }

    var outfits = <Outfit>[];
    String? errorOutfits;
    try {
      outfits = await _outfitsServicio.listar();
    } catch (e) {
      errorOutfits = '$e';
    }

    var recomendaciones = <Recomendacion>[];
    String? errorRecomendaciones;
    try {
      recomendaciones = await _recomendacionesServicio.recibidas();
    } catch (e) {
      errorRecomendaciones = '$e';
    }

    return _Datos(
      prendas: prendas,
      perfil: perfil,
      outfits: outfits,
      recomendaciones: recomendaciones,
      errorOutfits: errorOutfits,
      errorRecomendaciones: errorRecomendaciones,
    );
  }

  void _recargar() {
    setState(() {
      _futuro = _cargar();
    });
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  /* Posición inicial aproximada de cada categoría */
  _Capa _nuevaCapa(Prenda p, int accesoriosPuestos) {
    switch (p.categoria) {
      case 'cuerpo_completo':
        return _Capa(prenda: p, centro: const Offset(0.5, 0.15), ancho: 0.6, anclaVertical: 0);
      case 'abrigo':
        return _Capa(prenda: p, centro: const Offset(0.5, 0.15), ancho: 0.62, anclaVertical: 0);
      case 'superior':
        return _Capa(prenda: p, centro: const Offset(0.5, 0.17), ancho: 0.5, anclaVertical: 0);
      case 'inferior':
        return _Capa(prenda: p, centro: const Offset(0.5, 0.45), ancho: 0.42, anclaVertical: 0);
      case 'calzado':
        return _Capa(prenda: p, centro: const Offset(0.5, 0.97), ancho: 0.34, anclaVertical: 1);
      default:
        return _Capa(
          prenda: p,
          centro: Offset(0.82, 0.14 + accesoriosPuestos * 0.14),
          ancho: 0.2,
          anclaVertical: 0.5,
        );
    }
  }

  /* Pone un conjunto de prendas sobre el lienzo, por ejemplo un outfit guardado o una recomendación */
  void _ponerPrendas(List<Prenda> prendas, String nombre) {
    setState(() {
      _equipadas.clear();
      _seleccionadaId = null;
      var accesorios = 0;
      for (final p in prendas) {
        _equipadas.add(_nuevaCapa(p, accesorios));
        if (p.categoria == 'accesorios') accesorios++;
      }
      _mostrando = nombre;
    });
  }

  /* Pone o quita una prenda. Solo cabe una prenda por categoría, salvo accesorios,
     y una prenda de cuerpo completo reemplaza a la camiseta y al pantalón. */
  void _alternar(Prenda p) {
    setState(() {
      _mostrando = null;
      final indice = _equipadas.indexWhere((c) => c.prenda.id == p.id);
      if (indice >= 0) {
        _equipadas.removeAt(indice);
        if (_seleccionadaId == p.id) _seleccionadaId = null;
        return;
      }
      if (p.categoria != 'accesorios') {
        _equipadas.removeWhere((c) => c.prenda.categoria == p.categoria);
      }
      if (p.categoria == 'cuerpo_completo') {
        _equipadas.removeWhere((c) => c.prenda.categoria == 'superior' || c.prenda.categoria == 'inferior');
      }
      if (p.categoria == 'superior' || p.categoria == 'inferior') {
        _equipadas.removeWhere((c) => c.prenda.categoria == 'cuerpo_completo');
      }
      final accesorios = _equipadas.where((c) => c.prenda.categoria == 'accesorios').length;
      _equipadas.add(_nuevaCapa(p, accesorios));
      _seleccionadaId = null;
    });
  }

  void _quitarTodo() {
    setState(() {
      _equipadas.clear();
      _seleccionadaId = null;
      _mostrando = null;
    });
  }

  Future<void> _guardarComoOutfit() async {
    final prendas = _equipadas.map((c) => c.prenda).toList();
    final problema = revisarReglasOutfit(prendas);
    if (problema != null) {
      _aviso(problema);
      return;
    }

    final datos = await showDialog<_DatosOutfit>(
      context: context,
      builder: (ctx) => const _DialogoOutfit(),
    );
    if (datos == null) return;

    setState(() => _guardando = true);
    try {
      await _outfitsServicio.crear(
        nombre: datos.nombre,
        estilo: datos.estilo,
        prendaIds: prendas.map((p) => p.id).toList(),
      );
      if (!mounted) return;
      _aviso('Outfit "${datos.nombre}" guardado');
      _recargar();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      _aviso(e.message);
    } catch (e) {
      if (!mounted) return;
      _aviso('No se pudo guardar: $e');
    }
    if (!mounted) return;
    setState(() => _guardando = false);
  }

  Future<void> _eliminarOutfit(Outfit outfit) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar outfit'),
        content: Text('¿Seguro que quieres eliminar "${outfit.nombre}"? Tus prendas no se borran.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await _outfitsServicio.eliminar(outfit.id);
      if (!mounted) return;
      _aviso('Outfit eliminado');
    } catch (e) {
      if (!mounted) return;
      _aviso('No se pudo eliminar: $e');
    }
    _recargar();
  }

  Future<void> _aceptar(Recomendacion r) async {
    try {
      await _recomendacionesServicio.aceptar(r.id);
      if (!mounted) return;
      _aviso('"${r.nombre}" se agregó a tus outfits');
    } on PostgrestException catch (e) {
      if (!mounted) return;
      _aviso(e.message);
    } catch (e) {
      if (!mounted) return;
      _aviso('No se pudo aceptar: $e');
    }
    _recargar();
  }

  Future<void> _descartar(Recomendacion r) async {
    try {
      await _recomendacionesServicio.descartar(r.id);
      if (!mounted) return;
      _aviso('Recomendación descartada');
    } catch (e) {
      if (!mounted) return;
      _aviso('No se pudo descartar: $e');
    }
    _recargar();
  }

  /* ---------- Lienzo de la derecha ---------- */

  Widget _fondo(Perfil? perfil, double alto) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    /* Sin perfil: lienzo liso, sin persona */
    if (!_conPerfil) {
      return Container(color: color);
    }
    final url = perfil?.urlFoto;
    if (url == null) {
      return Container(
        color: color,
        child: Center(child: Icon(Icons.accessibility_new, size: alto * 0.8, color: Colors.black26)),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => Container(color: color),
    );
  }

  /* Sombra suave debajo de la prenda: la misma imagen en negro, desenfocada y desplazada */
  Widget _conSombra(Widget imagen) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Transform.translate(
          offset: const Offset(4, 8),
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Opacity(
              opacity: 0.35,
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                child: imagen,
              ),
            ),
          ),
        ),
        imagen,
      ],
    );
  }

  Widget _imagenDeCapa(_Capa capa, double w) {
    Widget imagen = Image.network(
      capa.prenda.urlImagen!,
      width: capa.ancho * w,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 40),
    );
    imagen = Transform.flip(flipX: capa.volteada, child: imagen);

    /* La sombra solo tiene sentido si la prenda no tiene fondo. Con fondo se vería un rectángulo oscuro. */
    final sinFondo = capa.prenda.imagenPath.toLowerCase().endsWith('.png');
    return (_sombra && sinFondo) ? _conSombra(imagen) : imagen;
  }

  Widget _capaPuesta(_Capa capa, double w, double h) {
    if (capa.prenda.urlImagen == null) return const SizedBox.shrink();
    final color = Theme.of(context).colorScheme.primary;
    final seleccionada = _seleccionadaId == capa.prenda.id;

    return Positioned(
      left: capa.centro.dx * w,
      top: capa.centro.dy * h,
      child: FractionalTranslation(
        translation: Offset(-0.5, -capa.anclaVertical),
        child: GestureDetector(
          onTap: () => setState(() => _seleccionadaId = capa.prenda.id),
          onScaleStart: (_) {
            _anchoInicial = capa.ancho;
            _anguloInicial = capa.angulo;
            setState(() => _seleccionadaId = capa.prenda.id);
          },
          onScaleUpdate: (d) {
            setState(() {
              final dx = (capa.centro.dx + d.focalPointDelta.dx / w).clamp(0.0, 1.0).toDouble();
              final dy = (capa.centro.dy + d.focalPointDelta.dy / h).clamp(0.0, 1.0).toDouble();
              capa.centro = Offset(dx, dy);
              if (d.scale != 1.0) {
                capa.ancho = (_anchoInicial * d.scale).clamp(_anchoMinimo, _anchoMaximo).toDouble();
              }
              if (d.rotation != 0.0) {
                capa.angulo = _anguloInicial + d.rotation;
              }
            });
          },
          child: Transform.rotate(
            angle: capa.angulo,
            child: Container(
              decoration: BoxDecoration(
                border: seleccionada ? Border.all(color: color, width: 2) : null,
              ),
              child: _imagenDeCapa(capa, w),
            ),
          ),
        ),
      ),
    );
  }

  Widget _lienzo(Perfil? perfil) {
    final dibujo = [..._equipadas]
      ..sort((a, b) => _ordenDeDibujo.indexOf(a.prenda.categoria).compareTo(_ordenDeDibujo.indexOf(b.prenda.categoria)));
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Positioned.fill(child: _fondo(perfil, h)),
                for (final capa in dibujo) _capaPuesta(capa, w, h),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _controlesDeLaPrenda(_Capa capa) {
    final grados = (capa.angulo * 180 / math.pi).clamp(-45.0, 45.0).toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const SizedBox(width: 56, child: Text('Tamaño')),
            Expanded(
              child: Slider(
                value: capa.ancho.clamp(_anchoMinimo, _anchoMaximo).toDouble(),
                min: _anchoMinimo,
                max: _anchoMaximo,
                onChanged: (v) => setState(() => capa.ancho = v),
              ),
            ),
          ],
        ),
        Row(
          children: [
            const SizedBox(width: 56, child: Text('Giro')),
            Expanded(
              child: Slider(
                value: grados,
                min: -45,
                max: 45,
                onChanged: (v) => setState(() => capa.angulo = v * math.pi / 180),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => capa.volteada = !capa.volteada),
              icon: const Icon(Icons.flip),
              tooltip: 'Voltear',
            ),
            TextButton(
              onPressed: () => setState(() => _seleccionadaId = null),
              child: const Text('Listo'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _ayudaDelLienzo() {
    final seleccionada = _equipadas.where((c) => c.prenda.id == _seleccionadaId).toList();
    if (seleccionada.isNotEmpty) {
      return _controlesDeLaPrenda(seleccionada.first);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Flexible(
          child: Text(
            'Toca una prenda del armario para ponerla. Toca una puesta para ajustarla.',
            style: TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 8),
        const Text('Sombra', style: TextStyle(fontSize: 12)),
        Switch(value: _sombra, onChanged: (v) => setState(() => _sombra = v)),
      ],
    );
  }

  Widget _zonaDerecha(_Datos datos) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Perfil'), icon: Icon(Icons.person)),
              ButtonSegment(value: false, label: Text('Sin perfil'), icon: Icon(Icons.checkroom_outlined)),
            ],
            selected: {_conPerfil},
            onSelectionChanged: (s) => setState(() => _conPerfil = s.first),
          ),
        ),
        if (_mostrando != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Mostrando: $_mostrando', style: const TextStyle(fontSize: 13)),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Center(child: _lienzo(datos.perfil)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: _ayudaDelLienzo(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: _equipadas.isEmpty ? null : _quitarTodo,
                child: const Text('Quitar todo'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: (_equipadas.isEmpty || _guardando) ? null : _guardarComoOutfit,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Guardar outfit'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /* ---------- Panel de la izquierda ---------- */

  Widget _panelArmario(List<Prenda> prendas) {
    final visibles =
        _filtroCategoria == null ? prendas : prendas.where((p) => p.categoria == _filtroCategoria).toList();
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('Todas'),
                  selected: _filtroCategoria == null,
                  onSelected: (_) => setState(() => _filtroCategoria = null),
                ),
              ),
              for (final e in categorias.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: _filtroCategoria == e.key,
                    onSelected: (_) => setState(() => _filtroCategoria = e.key),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: visibles.isEmpty
              ? const Center(child: Text('No hay prendas en esta categoría.'))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 150,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: visibles.length,
                  itemBuilder: (context, i) {
                    final prenda = visibles[i];
                    return PrendaElegible(
                      prenda: prenda,
                      elegida: _equipadas.any((c) => c.prenda.id == prenda.id),
                      alTocar: () => _alternar(prenda),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _miniaturas(List<Prenda> prendas) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final p in prendas)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 56,
              height: 56,
              child: p.urlImagen == null
                  ? const Icon(Icons.checkroom)
                  : Image.network(
                      p.urlImagen!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
                    ),
            ),
          ),
      ],
    );
  }

  Widget _listaMisOutfits(_Datos datos) {
    if (datos.errorOutfits != null) {
      return Center(child: Text('Error al cargar tus outfits: ${datos.errorOutfits}'));
    }
    if (datos.outfits.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Aún no tienes outfits. Arma uno desde el Armario y guárdalo con el botón Guardar outfit.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: datos.outfits.length,
      itemBuilder: (context, i) {
        final outfit = datos.outfits[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => _ponerPrendas(outfit.prendas, outfit.nombre),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          outfit.nombre,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Chip(label: Text(estilos[outfit.estilo] ?? outfit.estilo)),
                      IconButton(
                        onPressed: () => _eliminarOutfit(outfit),
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Eliminar outfit',
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _miniaturas(outfit.prendas),
                  const SizedBox(height: 6),
                  const Text('Toca para verlo sobre el lienzo', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _listaRecomendados(_Datos datos) {
    if (datos.errorRecomendaciones != null) {
      return Center(child: Text('Error al cargar las recomendaciones: ${datos.errorRecomendaciones}'));
    }
    if (datos.recomendaciones.isEmpty) {
      return const Center(child: Text('No tienes outfits recomendados pendientes.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: datos.recomendaciones.length,
      itemBuilder: (context, i) {
        final r = datos.recomendaciones[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => _ponerPrendas(r.prendas, r.nombre),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.nombre,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            Text('De ${r.remitente}', style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      Chip(label: Text(estilos[r.estilo] ?? r.estilo)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _miniaturas(r.prendas),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Toca para probártelo', style: TextStyle(fontSize: 12)),
                      ),
                      TextButton(onPressed: () => _descartar(r), child: const Text('Descartar')),
                      const SizedBox(width: 4),
                      FilledButton(onPressed: () => _aceptar(r), child: const Text('Aceptar')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _panelOutfits(_Datos datos) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: SegmentedButton<_SubSeccion>(
            segments: [
              const ButtonSegment(value: _SubSeccion.mios, label: Text('Mis outfits'), icon: Icon(Icons.style)),
              ButtonSegment(
                value: _SubSeccion.recomendados,
                label: Text('Recomendados (${datos.recomendaciones.length})'),
                icon: const Icon(Icons.inbox),
              ),
            ],
            selected: {_subSeccion},
            onSelectionChanged: (s) => setState(() => _subSeccion = s.first),
          ),
        ),
        Expanded(
          child: _subSeccion == _SubSeccion.mios ? _listaMisOutfits(datos) : _listaRecomendados(datos),
        ),
      ],
    );
  }

  Widget _panelIzquierdo(_Datos datos) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: SegmentedButton<_Seccion>(
            segments: const [
              ButtonSegment(value: _Seccion.armario, label: Text('Armario'), icon: Icon(Icons.checkroom)),
              ButtonSegment(value: _Seccion.outfits, label: Text('Outfits'), icon: Icon(Icons.style)),
            ],
            selected: {_seccion},
            onSelectionChanged: (s) => setState(() => _seccion = s.first),
          ),
        ),
        Expanded(
          child: _seccion == _Seccion.armario ? _panelArmario(datos.prendas) : _panelOutfits(datos),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Outfits'),
        actions: [
          IconButton(onPressed: _recargar, icon: const Icon(Icons.refresh), tooltip: 'Actualizar'),
          TextButton(
            onPressed: () => supabase.auth.signOut(),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
      body: FutureBuilder<_Datos>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar: ${snapshot.error}'));
          }
          final datos = snapshot.data!;
          if (datos.prendas.isEmpty) {
            return const Center(child: Text('Primero agrega prendas en la pestaña Prendas.'));
          }

          return LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth >= 900) {
                /* Pantalla grande: panel a la izquierda y lienzo a la derecha */
                return Row(
                  children: [
                    SizedBox(width: 440, child: _panelIzquierdo(datos)),
                    const VerticalDivider(width: 1),
                    Expanded(child: _zonaDerecha(datos)),
                  ],
                );
              }
              /* Pantalla angosta: lienzo arriba y panel abajo */
              return Column(
                children: [
                  SizedBox(height: c.maxHeight * 0.6, child: _zonaDerecha(datos)),
                  const Divider(height: 1),
                  Expanded(child: _panelIzquierdo(datos)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _DialogoOutfit extends StatefulWidget {
  const _DialogoOutfit();

  @override
  State<_DialogoOutfit> createState() => _DialogoOutfitState();
}

class _DialogoOutfitState extends State<_DialogoOutfit> {
  final _nombre = TextEditingController();
  String? _estilo;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Guardar outfit'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nombre,
              decoration: const InputDecoration(labelText: 'Nombre del outfit *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _estilo,
              decoration: const InputDecoration(labelText: 'Estilo *', border: OutlineInputBorder()),
              items: estilos.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (v) => setState(() => _estilo = v),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final nombre = _nombre.text.trim();
            if (nombre.isEmpty || _estilo == null) {
              setState(() => _error = 'Escribe un nombre y elige un estilo.');
              return;
            }
            Navigator.pop(context, _DatosOutfit(nombre, _estilo!));
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
