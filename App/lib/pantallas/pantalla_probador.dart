import 'package:flutter/material.dart';

import '../servicios/outfits_servicio.dart';
import '../servicios/perfil_servicio.dart';
import '../servicios/prendas_servicio.dart';

enum _Modo { puesta, aislada }

/* Una prenda colocada sobre el lienzo. Centro y ancho van como fracción del lienzo. */
class _Capa {
  _Capa({required this.prenda, required this.centro, required this.ancho});

  final Prenda prenda;
  Offset centro;
  double ancho;
}

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

  late final Future<Perfil> _futuroPerfil = PerfilServicio().cargar();
  late List<_Capa> _capas;
  _Modo _modo = _Modo.puesta;
  int? _seleccionada;
  double _anchoInicial = 0.5;

  @override
  void initState() {
    super.initState();
    _capas = _crearCapas();
  }

  /* Posición inicial aproximada de cada categoría sobre el cuerpo */
  List<_Capa> _crearCapas() {
    final prendas = [...widget.outfit.prendas]
      ..sort((a, b) => _ordenDeDibujo.indexOf(a.categoria).compareTo(_ordenDeDibujo.indexOf(b.categoria)));
    var accesorios = 0;
    return prendas.map((p) {
      switch (p.categoria) {
        case 'cuerpo_completo':
          return _Capa(prenda: p, centro: const Offset(0.5, 0.5), ancho: 0.6);
        case 'abrigo':
          return _Capa(prenda: p, centro: const Offset(0.5, 0.33), ancho: 0.6);
        case 'superior':
          return _Capa(prenda: p, centro: const Offset(0.5, 0.31), ancho: 0.5);
        case 'inferior':
          return _Capa(prenda: p, centro: const Offset(0.5, 0.6), ancho: 0.42);
        case 'calzado':
          return _Capa(prenda: p, centro: const Offset(0.5, 0.9), ancho: 0.36);
        default:
          final i = accesorios++;
          return _Capa(prenda: p, centro: Offset(0.82, 0.14 + i * 0.14), ancho: 0.2);
      }
    }).toList();
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

  Widget _capa(int i, double w, double h) {
    final capa = _capas[i];
    final url = capa.prenda.urlImagen;
    if (url == null) return const SizedBox.shrink();
    final color = Theme.of(context).colorScheme.primary;

    return Positioned(
      left: capa.centro.dx * w,
      top: capa.centro.dy * h,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: GestureDetector(
          onTap: () => setState(() => _seleccionada = i),
          onScaleStart: (_) {
            _anchoInicial = capa.ancho;
            setState(() => _seleccionada = i);
          },
          onScaleUpdate: (d) {
            setState(() {
              final dx = (capa.centro.dx + d.focalPointDelta.dx / w).clamp(0.0, 1.0).toDouble();
              final dy = (capa.centro.dy + d.focalPointDelta.dy / h).clamp(0.0, 1.0).toDouble();
              capa.centro = Offset(dx, dy);
              if (d.scale != 1.0) {
                capa.ancho = (_anchoInicial * d.scale).clamp(_anchoMinimo, _anchoMaximo).toDouble();
              }
            });
          },
          child: Container(
            decoration: BoxDecoration(
              border: _seleccionada == i ? Border.all(color: color, width: 2) : null,
            ),
            child: Image.network(
              url,
              width: capa.ancho * w,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 40),
            ),
          ),
        ),
      ),
    );
  }

  Widget _vistaPuesta(Perfil? perfil) {
    final seleccionada = _seleccionada;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
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
                    for (var i = 0; i < _capas.length; i++) _capa(i, w, h),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        if (seleccionada != null)
          Row(
            children: [
              const Text('Tamaño'),
              Expanded(
                child: Slider(
                  value: _capas[seleccionada].ancho.clamp(_anchoMinimo, _anchoMaximo).toDouble(),
                  min: _anchoMinimo,
                  max: _anchoMaximo,
                  onChanged: (v) => setState(() => _capas[seleccionada].ancho = v),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _seleccionada = null),
                child: const Text('Listo'),
              ),
            ],
          )
        else
          const Text(
            'Arrastra cada prenda para acomodarla sobre la foto. Toca una prenda para cambiar su tamaño con el control deslizante.',
            style: TextStyle(fontSize: 13),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => setState(() {
            _capas = _crearCapas();
            _seleccionada = null;
          }),
          icon: const Icon(Icons.restart_alt),
          label: const Text('Restablecer posiciones'),
        ),
        const SizedBox(height: 12),
        const Text(
          'Las prendas conservan el fondo de su foto. El recorte automático de fondos es un paso pendiente.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _vistaAislada() {
    final fondo = Theme.of(context).colorScheme.surfaceContainerHighest;
    final prendas = widget.outfit.prendas;
    return SizedBox(
      height: 420,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.outfit.nombre)),
      body: FutureBuilder<Perfil>(
        future: _futuroPerfil,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          /* Si el perfil no carga, se usa el modelo neutro */
          final perfil = snapshot.data;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SegmentedButton<_Modo>(
                    segments: const [
                      ButtonSegment(value: _Modo.puesta, label: Text('Puesta'), icon: Icon(Icons.accessibility_new)),
                      ButtonSegment(value: _Modo.aislada, label: Text('Prenda aislada'), icon: Icon(Icons.checkroom)),
                    ],
                    selected: {_modo},
                    onSelectionChanged: (s) => setState(() => _modo = s.first),
                  ),
                  const SizedBox(height: 16),
                  if (_modo == _Modo.puesta) _vistaPuesta(perfil) else _vistaAislada(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
