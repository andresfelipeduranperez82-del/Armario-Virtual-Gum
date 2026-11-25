import 'package:flutter/material.dart';

import 'avatar_usuario.dart';
import 'logo_gum.dart';

const _marino = Color(0xFF1E305C);

/* Por debajo de este ancho los destinos pasan al menú de hamburguesa */
const _anchoMovil = 700.0;

/* Desde este ancho se muestra también el nombre junto al logo */
const _anchoConNombre = 900.0;

/* Barra superior de toda la app: logo y nombre a la izquierda, y a la derecha las secciones y la foto del usuario.
   Reemplaza a la barra de navegación de abajo. El índice es la pestaña activa:
   0 Prendas, 1 Outfits, 2 Amigos, 3 Recomendaciones, 4 Perfil */
class EncabezadoGum extends StatelessWidget {
  const EncabezadoGum({super.key, required this.indice, required this.alIrA});

  final int indice;
  final ValueChanged<int> alIrA;

  static const _destinos = <(IconData, String)>[
    (Icons.checkroom, 'Prendas'),
    (Icons.style, 'Outfits'),
    (Icons.group, 'Amigos'),
    (Icons.inbox, 'Recomendaciones'),
  ];

  Widget _menuHamburguesa() {
    return PopupMenuButton<int>(
      tooltip: 'Menú',
      icon: const Icon(Icons.menu, color: Colors.white),
      onSelected: alIrA,
      itemBuilder: (context) => [
        for (var i = 0; i < _destinos.length; i++)
          PopupMenuItem(
            value: i,
            child: Row(
              children: [
                Icon(_destinos[i].$1, size: 20),
                const SizedBox(width: 12),
                Text(
                  _destinos[i].$2,
                  style: TextStyle(fontWeight: indice == i ? FontWeight.w700 : FontWeight.w400),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final movil = ancho < _anchoMovil;
    final conNombre = ancho >= _anchoConNombre;

    return Material(
      color: _marino,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              /* El logo con el nombre lleva a Prendas, como en casi todas las páginas */
              InkWell(
                onTap: () => alIrA(0),
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LogoGum(tamano: 80),
                    if (conNombre) ...[
                      const SizedBox(width: 12),
                      const Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gum',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              height: 1.0,
                            ),
                          ),
                          Text(
                            'Armario Virtual',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              if (movil)
                _menuHamburguesa()
              else ...[
                for (var i = 0; i < _destinos.length; i++) ...[
                  _Acceso(
                    icono: _destinos[i].$1,
                    texto: _destinos[i].$2,
                    activo: indice == i,
                    alTocar: () => alIrA(i),
                  ),
                  const SizedBox(width: 4),
                ],
                const SizedBox(width: 6),
              ],
              AvatarUsuario(alIrAlPerfil: () => alIrA(4)),
            ],
          ),
        ),
      ),
    );
  }
}

/* Acceso a una sección: icono con texto, y la sección actual queda resaltada */
class _Acceso extends StatelessWidget {
  const _Acceso({
    required this.icono,
    required this.texto,
    required this.activo,
    required this.alTocar,
  });

  final IconData icono;
  final String texto;
  final bool activo;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: alTocar,
      icon: Icon(icono, size: 20),
      label: Text(texto),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: activo ? Colors.white.withValues(alpha: 0.18) : null,
        textStyle: TextStyle(fontSize: 14, fontWeight: activo ? FontWeight.w800 : FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
