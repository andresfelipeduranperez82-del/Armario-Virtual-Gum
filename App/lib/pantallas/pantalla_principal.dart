import 'package:flutter/material.dart';

import 'pantalla_catalogo.dart';
import 'pantalla_outfits.dart';

/* Pantalla con la barra inferior para moverse entre prendas y outfits */
class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _indice == 0 ? const PantallaCatalogo() : const PantallaOutfits(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.checkroom), label: 'Prendas'),
          NavigationDestination(icon: Icon(Icons.style), label: 'Outfits'),
        ],
      ),
    );
  }
}
