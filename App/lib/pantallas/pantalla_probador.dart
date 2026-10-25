import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../servicios/cliente.dart';
import '../servicios/outfits_servicio.dart';
import '../servicios/perfil_servicio.dart';
import '../servicios/prendas_servicio.dart';
import '../servicios/recorte_fondo.dart';

enum _Modo { puesta, aislada }

/* Una prenda colocada sobre el lienzo.
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
  double _anguloInicial = 0;
  bool _sombra = true;

  /* Recorte de fondo para las prendas que todavía tienen su fondo original */
  final Map<String, Uint8List> _originales = {};
  Map<String, ui.Image> _recortes = {};
  bool _sinFondo = false;
  double _tolerancia = 38;
  bool _procesando = false;
  String? _errorRecorte;

  @override
  void initState() {
    super.initState();
    _capas = _crearCapas();
  }

  @override
  void dispose() {
    for (final imagen in _recortes.values) {
      imagen.dispose();
    }
    super.dispose();
  }

  /* Posición inicial aproximada de cada categoría sobre el cuerpo.
     Se ancla por el borde de arriba (hombros y cintura) o de abajo (pies), no por el centro,
     para que la prenda caiga en su sitio sin importar qué tan alta sea su foto. */
  List<_Capa> _crearCapas() {
    final prendas = [...widget.outfit.prendas]
      ..sort((a, b) => _ordenDeDibujo.indexOf(a.categoria).compareTo(_ordenDeDibujo.indexOf(b.categoria)));
    var accesorios = 0;
    return prendas.map((p) {
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
          final i = accesorios++;
          return _Capa(prenda: p, centro: Offset(0.82, 0.14 + i * 0.14), ancho: 0.2, anclaVertical: 0.5);
      }
    }).toList();
  }

  /* Descarga cada foto original una sola vez y les quita el fondo */
  Future<void> _procesar() async {
    setState(() {
      _procesando = true;
      _errorRecorte = null;
    });
    try {
      final nuevos = <String, ui.Image>{};
      for (final capa in _capas) {
        final id = capa.prenda.id;
        final original =
            _originales[id] ?? await supabase.storage.from('prendas').download(capa.prenda.imagenPath);
        _originales[id] = original;
        nuevos[id] = await recortarFondo(original, tolerancia: _tolerancia);
      }
      if (!mounted) {
        for (final imagen in nuevos.values) {
          imagen.dispose();
        }
        return;
      }
      final viejos = _recortes.values.toList();
      setState(() {
        _recortes = nuevos;
        _procesando = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final imagen in viejos) {
          imagen.dispose();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _procesando = false;
        _sinFondo = false;
        _errorRecorte = 'No se pudo quitar el fondo: $e';
      });
    }
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

  /* Muestra la prenda con el fondo quitado si ya lo tiene o si el recorte está activo y listo */
  Widget _imagenDeCapa(_Capa capa, double w) {
    final recorte = _sinFondo ? _recortes[capa.prenda.id] : null;
    final yaTransparente = capa.prenda.imagenPath.toLowerCase().endsWith('.png');
    Widget imagen;
    if (recorte != null) {
      imagen = RawImage(image: recorte, width: capa.ancho * w, fit: BoxFit.contain);
    } else {
      imagen = Image.network(
        capa.prenda.urlImagen!,
        width: capa.ancho * w,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 40),
      );
    }
    imagen = Transform.flip(flipX: capa.volteada, child: imagen);

    /* La sombra solo tiene sentido si la prenda no tiene fondo. Con fondo se vería un rectángulo oscuro. */
    final sinFondo = recorte != null || yaTransparente;
    return (_sombra && sinFondo) ? _conSombra(imagen) : imagen;
  }

  Widget _capa(int i, double w, double h) {
    final capa = _capas[i];
    if (capa.prenda.urlImagen == null) return const SizedBox.shrink();
    final color = Theme.of(context).colorScheme.primary;

    return Positioned(
      left: capa.centro.dx * w,
      top: capa.centro.dy * h,
      child: FractionalTranslation(
        translation: Offset(-0.5, -capa.anclaVertical),
        child: GestureDetector(
          onTap: () => setState(() => _seleccionada = i),
          onScaleStart: (_) {
            _anchoInicial = capa.ancho;
            _anguloInicial = capa.angulo;
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
              if (d.rotation != 0.0) {
                capa.angulo = _anguloInicial + d.rotation;
              }
            });
          },
          child: Transform.rotate(
            angle: capa.angulo,
            child: Container(
              decoration: BoxDecoration(
                border: _seleccionada == i ? Border.all(color: color, width: 2) : null,
              ),
              child: _imagenDeCapa(capa, w),
            ),
          ),
        ),
      ),
    );
  }

  Widget _controlesDeLaPrenda(_Capa capa) {
    final grados = (capa.angulo * 180 / math.pi).clamp(-45.0, 45.0).toDouble();
    return Column(
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
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () => setState(() => capa.volteada = !capa.volteada),
              icon: const Icon(Icons.flip),
              label: const Text('Voltear'),
            ),
            TextButton(
              onPressed: () => setState(() => _seleccionada = null),
              child: const Text('Listo'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _controlesDeRecorte() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Sombra suave'),
          subtitle: const Text('Se aplica a las prendas que ya no tienen fondo.'),
          value: _sombra,
          onChanged: (valor) => setState(() => _sombra = valor),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Quitar fondo claro de las prendas'),
          subtitle: const Text('Para prendas subidas antes con su fondo. Funciona mejor con fondos lisos y claros.'),
          value: _sinFondo,
          onChanged: _procesando
              ? null
              : (valor) {
                  setState(() => _sinFondo = valor);
                  if (valor && _recortes.isEmpty) {
                    _procesar();
                  }
                },
        ),
        if (_sinFondo)
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
          _controlesDeLaPrenda(_capas[seleccionada])
        else
          const Text(
            'Arrastra cada prenda para acomodarla sobre la foto. Toca una prenda para cambiar su tamaño, girarla o voltearla.',
            style: TextStyle(fontSize: 13),
          ),
        const SizedBox(height: 8),
        _controlesDeRecorte(),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => setState(() {
            _capas = _crearCapas();
            _seleccionada = null;
          }),
          icon: const Icon(Icons.restart_alt),
          label: const Text('Restablecer posiciones'),
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
