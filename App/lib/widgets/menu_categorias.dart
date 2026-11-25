import 'dart:async';

import 'package:flutter/material.dart';

const _violeta = Color(0xFF7C3AED);

/* Botón "Categorías" con un menú flotante. Se abre al pasar el mouse o al hacer clic o tocar,
   y se cierra al elegir una opción, al sacar el mouse o al tocar fuera */
class MenuCategorias extends StatefulWidget {
  const MenuCategorias({
    super.key,
    required this.opciones,
    required this.seleccion,
    required this.alElegir,
  });

  /* Clave y nombre de cada categoría */
  final Map<String, String> opciones;
  final String? seleccion;

  /* Recibe la clave elegida, o null si se eligen todas */
  final ValueChanged<String?> alElegir;

  @override
  State<MenuCategorias> createState() => _MenuCategoriasState();
}

class _MenuCategoriasState extends State<MenuCategorias> {
  final _enlace = LayerLink();
  final _portal = OverlayPortalController();
  final _grupo = Object();
  Timer? _temporizador;
  bool _abierto = false;

  /* Abierto con clic o toque: no se cierra al sacar el mouse */
  bool _fijo = false;

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  void _abrir() {
    _temporizador?.cancel();
    if (_abierto) return;
    _portal.show();
    setState(() => _abierto = true);
  }

  void _cerrar() {
    _temporizador?.cancel();
    if (!_abierto) return;
    _portal.hide();
    setState(() {
      _abierto = false;
      _fijo = false;
    });
  }

  /* Pequeña espera para poder cruzar del botón al menú sin que se cierre */
  void _programarCierre() {
    if (_fijo) return;
    _temporizador?.cancel();
    _temporizador = Timer(const Duration(milliseconds: 180), _cerrar);
  }

  void _alTocarBoton() {
    if (_abierto && _fijo) {
      _cerrar();
      return;
    }
    _fijo = true;
    _abrir();
  }

  void _elegir(String? clave) {
    widget.alElegir(clave);
    _cerrar();
  }

  Widget _boton(String etiqueta, bool conSeleccion) {
    return Material(
      color: conSeleccion ? _violeta : Colors.white.withValues(alpha: 0.12),
      shape: StadiumBorder(
        side: BorderSide(color: conSeleccion ? _violeta : Colors.white54, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _alTocarBoton,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 9, 12, 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                etiqueta,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _abierto ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tarjeta() {
    final entradas = <(String?, String)>[
      (null, 'Todas las categorías'),
      for (final e in widget.opciones.entries) (e.key, e.value),
    ];
    return Material(
      color: const Color(0xFF1B1B2F),
      elevation: 8,
      shadowColor: Colors.black45,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 240, maxWidth: 280),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (clave, texto) in entradas)
                _Opcion(
                  texto: texto,
                  elegida: clave == widget.seleccion,
                  alTocar: () => _elegir(clave),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirMenu(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: CompositedTransformFollower(
        link: _enlace,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 6),
        child: TapRegion(
          groupId: _grupo,
          onTapOutside: (_) => _cerrar(),
          child: MouseRegion(
            onEnter: (_) => _temporizador?.cancel(),
            onExit: (_) => _programarCierre(),
            child: _tarjeta(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seleccion = widget.seleccion;
    final etiqueta = seleccion == null ? 'Categorías' : (widget.opciones[seleccion] ?? 'Categorías');
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _construirMenu,
      child: CompositedTransformTarget(
        link: _enlace,
        child: TapRegion(
          groupId: _grupo,
          child: MouseRegion(
            onEnter: (_) => _abrir(),
            onExit: (_) => _programarCierre(),
            child: _boton(etiqueta, seleccion != null),
          ),
        ),
      ),
    );
  }
}

/* Una opción del menú: se resalta al pasar el mouse y queda marcada si es la elegida */
class _Opcion extends StatelessWidget {
  const _Opcion({required this.texto, required this.elegida, required this.alTocar});

  final String texto;
  final bool elegida;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Ink(
      color: elegida ? _violeta.withValues(alpha: 0.28) : Colors.transparent,
      child: InkWell(
        onTap: alTocar,
        hoverColor: _violeta.withValues(alpha: 0.4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  texto,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: elegida ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (elegida) const Icon(Icons.check, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
