import 'package:flutter/material.dart';

import 'pantalla_amigos.dart';
import 'pantalla_catalogo.dart';
import 'pantalla_outfits.dart';

/* Pantalla con la barra inferior para moverse entre prendas, outfits y amigos */
class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _indice = 0;

  Widget _pantalla() {
    switch (_indice) {
      case 0:
        return const PantallaCatalogo();
      case 1:
        return const PantallaOutfits();
      default:
        return const PantallaAmigos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pantalla(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.checkroom), label: 'Prendas'),
          NavigationDestination(icon: Icon(Icons.style), label: 'Outfits'),
          NavigationDestination(icon: Icon(Icons.group), label: 'Amigos'),
        ],
      ),
    );
  }
}
