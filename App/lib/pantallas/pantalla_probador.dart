import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../servicios/outfits_servicio.dart';
import '../servicios/perfil_servicio.dart';
import '../servicios/prendas_servicio.dart';
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
  _Datos(this.prendas, this.perfil);

  final List<Prenda> prendas;
  final Perfil? perfil;
}

enum _Modo { puesta, aislada }

class _DatosOutfit {
  _DatosOutfit(this.nombre, this.estilo);

  final String nombre;
  final String estilo;
}

/* Probador al estilo de un editor de avatares: a un lado el armario, al otro tu foto.
   Se abre con las prendas del outfit ya puestas. Al tocar otra prenda se pone al instante
   sobre la foto, y al tocarla otra vez se quita. */
class PantallaProbador extends StatefulWidget {
  const PantallaProbador({super.key, required this.outfit});

  final Outfit outfit;

  @override
  State<PantallaProbador> createState() => _PantallaProbadorState();
}

class _PantallaProbadorState extends State<PantallaProbador> {
  static const _ordenDeDibujo = ['cuerpo_completo', 'inferior', 'calzado', 'superior', 'abrigo', 'accesorios'];
  static const _anchoMinimo = 0.08;
  static const _anchoMaximo = 1.2;

  final _prendasServicio = PrendasServicio();
  final _outfitsServicio = OutfitsServicio();
  late final Future<_Datos> _futuro = _cargar();

  final List<_Capa> _equipadas = [];
  String? _seleccionadaId;
  String? _filtroCategoria;
  double _anchoInicial = 0.5;
  double _anguloInicial = 0;
  bool _sombra = true;
  bool _guardando = false;
  _Modo _modo = _Modo.puesta;
  List<Prenda> _prendasCargadas = [];

  Future<_Datos> _cargar() async {
    final prendas = await _prendasServicio.listar();
    Perfil? perfil;
    try {
      perfil = await PerfilServicio().cargar();
    } catch (_) {
      perfil = null;
    }
    _prendasCargadas = prendas;
    _ponerPrendasDelOutfit();
    return _Datos(prendas, perfil);
  }

  /* Pone sobre la foto las prendas del outfit con el que se abrió el probador */
  void _ponerPrendasDelOutfit() {
    _equipadas.clear();
    _seleccionadaId = null;
    final ids = widget.outfit.prendas.map((p) => p.id).toSet();
    var accesorios = 0;
    for (final p in _prendasCargadas) {
      if (!ids.contains(p.id)) continue;
      _equipadas.add(_nuevaCapa(p, accesorios));
      if (p.categoria == 'accesorios') accesorios++;
    }
  }

  void _restablecer() {
    setState(_ponerPrendasDelOutfit);
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  /* Posición inicial aproximada de cada categoría sobre el cuerpo */
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

  /* Pone o quita una prenda. Solo cabe una prenda por categoría, salvo accesorios,
     y un vestido o prenda de cuerpo completo reemplaza a la camiseta y al pantalón. */
  void _alternar(Prenda p) {
    setState(() {
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
      _aviso('Outfit "${datos.nombre}" guardado. Lo verás en la pestaña Outfits.');
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

  Widget _fondo(Perfil? perfil, double alto) {
    final url = perfil?.urlFoto;
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
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

  Widget _barraInferiorDelLienzo() {
    final seleccionada = _equipadas.where((c) => c.prenda.id == _seleccionadaId).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (seleccionada.isNotEmpty)
          _controlesDeLaPrenda(seleccionada.first)
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Toca una prenda del armario para ponértela. Arrástrala para acomodarla y tócala para ajustarla.',
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Sombra suave'),
            Switch(value: _sombra, onChanged: (v) => setState(() => _sombra = v)),
          ],
        ),
      ],
    );
  }

  Widget _vistaAislada() {
    final fondo = Theme.of(context).colorScheme.surfaceContainerHighest;
    final prendas = _equipadas.map((c) => c.prenda).toList();
    if (prendas.isEmpty) {
      return const Center(child: Text('Toca prendas del armario para verlas aquí.'));
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: prendas.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final p = prendas[i];
          final url = p.urlImagen;
          return Container(
            width: 300,
            decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: url == null
                        ? const Icon(Icons.checkroom, size: 60)
                        : Image.network(
                            url,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 60),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '${categorias[p.categoria] ?? p.categoria}, ${p.colorPrincipal}, ${estilos[p.estilo] ?? p.estilo}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _panelDeRopa(List<Prenda> prendas) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.outfit.nombre),
        actions: [
          TextButton.icon(
            onPressed: _equipadas.isEmpty ? null : _quitarTodo,
            icon: const Icon(Icons.checkroom_outlined),
            label: const Text('Quitar todo'),
          ),
          TextButton.icon(
            onPressed: (_equipadas.isEmpty || _guardando) ? null : _guardarComoOutfit,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar como outfit'),
          ),
          IconButton(
            onPressed: _restablecer,
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Volver al outfit original',
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
              final ancho = c.maxWidth >= 900;
              final lienzo = Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SegmentedButton<_Modo>(
                      segments: const [
                        ButtonSegment(value: _Modo.puesta, label: Text('Puesta'), icon: Icon(Icons.accessibility_new)),
                        ButtonSegment(value: _Modo.aislada, label: Text('Prenda aislada'), icon: Icon(Icons.checkroom)),
                      ],
                      selected: {_modo},
                      onSelectionChanged: (s) => setState(() => _modo = s.first),
                    ),
                  ),
                  if (_modo == _Modo.puesta) ...[
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Center(child: _lienzo(datos.perfil)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: _barraInferiorDelLienzo(),
                    ),
                  ] else
                    Expanded(child: _vistaAislada()),
                ],
              );
              if (ancho) {
                /* Pantalla grande: armario a la izquierda y foto a la derecha */
                return Row(
                  children: [
                    SizedBox(width: 440, child: _panelDeRopa(datos.prendas)),
                    const VerticalDivider(width: 1),
                    Expanded(child: lienzo),
                  ],
                );
              }
              /* Pantalla angosta: foto arriba y armario abajo */
              return Column(
                children: [
                  SizedBox(height: c.maxHeight * 0.55, child: lienzo),
                  const Divider(height: 1),
                  Expanded(child: _panelDeRopa(datos.prendas)),
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
      title: const Text('Guardar como outfit'),
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
