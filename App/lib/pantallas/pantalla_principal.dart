import 'package:flutter/material.dart';

import 'pantalla_amigos.dart';
import 'pantalla_catalogo.dart';
import 'pantalla_outfits.dart';
import 'pantalla_perfil.dart';
import 'pantalla_recomendaciones.dart';
import '../servicios/sincronizacion.dart';

/* Pantalla con la barra inferior para moverse entre las secciones de la app */
class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _indice = 0;

  @override
  void initState() {
    super.initState();
    Sincronizacion.instancia.iniciar();
  }

  @override
  void dispose() {
    Sincronizacion.instancia.detener();
    super.dispose();
  }

  Widget _pantalla() {
    switch (_indice) {
      case 0:
        return const PantallaCatalogo();
      case 1:
        return const PantallaOutfits();
      case 2:
        return const PantallaAmigos();
      case 3:
        return const PantallaRecomendaciones();
      default:
        return const PantallaPerfil();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          /* Aviso que solo aparece cuando se pierde la conexión en tiempo real */
          ValueListenableBuilder<bool>(
            valueListenable: Sincronizacion.instancia.conectado,
            builder: (context, conectado, _) {
              if (conectado) return const SizedBox.shrink();
              final colores = Theme.of(context).colorScheme;
              return Container(
                width: double.infinity,
                color: colores.errorContainer,
                padding: const EdgeInsets.all(6),
                child: Text(
                  'Sin conexión. Reconectando...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: colores.onErrorContainer),
                ),
              );
            },
          ),
          Expanded(child: _pantalla()),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.checkroom), label: 'Prendas'),
          NavigationDestination(icon: Icon(Icons.style), label: 'Outfits'),
          NavigationDestination(icon: Icon(Icons.group), label: 'Amigos'),
          NavigationDestination(icon: Icon(Icons.inbox), label: 'Recomendaciones'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
