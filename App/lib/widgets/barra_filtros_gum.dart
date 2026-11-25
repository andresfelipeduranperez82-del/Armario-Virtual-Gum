import 'package:flutter/material.dart';

import 'menu_filtro.dart';

const _marino = Color(0xFF1E305C);
const _marinoClaro = Color(0xFF2A4172);

/* Por debajo de este ancho se ocultan las píldoras de la derecha */
const _anchoMovil = 700.0;

/* Barra de filtros de la pantalla Prendas: menús de categorías, estilos y colores, y enlaces rápidos.
   Los números de alIrA son las pestañas: 1 Outfits, 2 Amigos, 3 Recomendaciones, 4 Perfil */
class BarraFiltrosGum extends StatelessWidget {
  const BarraFiltrosGum({
    super.key,
    required this.opcionesCategoria,
    required this.categoriaElegida,
    required this.alElegirCategoria,
    required this.opcionesEstilo,
    required this.estiloElegido,
    required this.alElegirEstilo,
    required this.opcionesColor,
    required this.colorElegido,
    required this.alElegirColor,
    required this.sinFiltros,
    required this.alMostrarTodas,
    required this.alIrA,
  });

  final Map<String, String> opcionesCategoria;
  final String? categoriaElegida;
  final ValueChanged<String?> alElegirCategoria;
  final Map<String, String> opcionesEstilo;
  final String? estiloElegido;
  final ValueChanged<String?> alElegirEstilo;
  final Map<String, String> opcionesColor;
  final String? colorElegido;
  final ValueChanged<String?> alElegirColor;
  final bool sinFiltros;
  final VoidCallback alMostrarTodas;
  final ValueChanged<int> alIrA;

  @override
  Widget build(BuildContext context) {
    final movil = MediaQuery.sizeOf(context).width < _anchoMovil;

    final menus = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MenuFiltro(
          titulo: 'Categorías',
          tituloSingular: 'Categoría',
          textoTodos: 'Todas las categorías',
          opciones: opcionesCategoria,
          seleccion: categoriaElegida,
          alElegir: alElegirCategoria,
        ),
        const SizedBox(width: 8),
        MenuFiltro(
          titulo: 'Estilos',
          tituloSingular: 'Estilo',
          textoTodos: 'Todos los estilos',
          opciones: opcionesEstilo,
          seleccion: estiloElegido,
          alElegir: alElegirEstilo,
        ),
        const SizedBox(width: 8),
        MenuFiltro(
          titulo: 'Colores',
          tituloSingular: 'Color',
          textoTodos: 'Todos los colores',
          opciones: opcionesColor,
          seleccion: colorElegido,
          alElegir: alElegirColor,
        ),
      ],
    );

    return Container(
      color: _marinoClaro,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          /* Si no caben los tres botones, la fila se desliza hacia los lados */
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: menus,
            ),
          ),
          if (!movil) ...[
            const SizedBox(width: 16),
            _Pildora(texto: 'Todas las prendas', activa: sinFiltros, alTocar: alMostrarTodas),
            const SizedBox(width: 8),
            _Pildora(texto: 'Combinaciones', activa: false, alTocar: () => alIrA(1)),
          ] else if (!sinFiltros)
            IconButton(
              onPressed: alMostrarTodas,
              tooltip: 'Quitar filtros',
              icon: const Icon(Icons.filter_alt_off, color: Colors.white),
            ),
        ],
      ),
    );
  }
}

/* Enlace rápido en forma de píldora */
class _Pildora extends StatelessWidget {
  const _Pildora({required this.texto, required this.activa, required this.alTocar});

  final String texto;
  final bool activa;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: activa ? Colors.white : Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: activa ? Colors.white : Colors.white54, width: 1.5)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alTocar,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            texto,
            style: TextStyle(
              color: activa ? _marino : Colors.white,
              fontSize: 14,
              fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
