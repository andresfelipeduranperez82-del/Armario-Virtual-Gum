import 'package:flutter/material.dart';

import '../servicios/maniqui_servicio.dart';
import 'maniqui_imagenes.dart';

/* Maniquí blanco de estudio, con la proporción de 3 de ancho por 4 de alto del lienzo del editor.
   Es una imagen con fondo transparente y su propia sombra en el suelo, y tiene una versión para
   el modo claro y otra para el oscuro. Ocupa todo el espacio disponible.
   Si no se indica el tipo, se muestra el neutro */
class Maniqui extends StatelessWidget {
  const Maniqui({super.key, this.tipo});

  final TipoManiqui? tipo;

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    return Image.memory(
      imagenDelManiqui(tipo, oscuro: oscuro),
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
    );
  }
}
