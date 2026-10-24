import 'package:flutter/material.dart';

import '../servicios/prendas_servicio.dart';

/* Tarjeta de prenda que se puede marcar o desmarcar al tocarla */
class PrendaElegible extends StatelessWidget {
  const PrendaElegible({
    super.key,
    required this.prenda,
    required this.elegida,
    required this.alTocar,
  });

  final Prenda prenda;
  final bool elegida;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final url = prenda.urlImagen;
    final color = Theme.of(context).colorScheme.primary;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: elegida ? color : Colors.transparent, width: 3),
      ),
      child: InkWell(
        onTap: alTocar,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: url == null
                      ? const Icon(Icons.checkroom, size: 40)
                      : Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 40),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    '${categorias[prenda.categoria] ?? prenda.categoria}, ${prenda.colorPrincipal}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            if (elegida)
              Positioned(
                top: 6,
                right: 6,
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: color,
                  child: const Icon(Icons.check, size: 16, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
