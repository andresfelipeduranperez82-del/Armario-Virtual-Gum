import 'package:flutter/material.dart';

import '../servicios/cliente.dart';
import '../servicios/prendas_servicio.dart';
import 'pantalla_nueva_prenda.dart';

class PantallaCatalogo extends StatefulWidget {
  const PantallaCatalogo({super.key});

  @override
  State<PantallaCatalogo> createState() => _PantallaCatalogoState();
}

class _PantallaCatalogoState extends State<PantallaCatalogo> {
  final _servicio = PrendasServicio();
  late Future<List<Prenda>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _servicio.listar();
  }

  void _recargar() {
    setState(() {
      _futuro = _servicio.listar();
    });
  }

  Future<void> _agregar() async {
    final guardada = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PantallaNuevaPrenda()),
    );
    if (guardada == true) {
      _recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi armario'),
        actions: [
          TextButton(
            onPressed: () => supabase.auth.signOut(),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregar,
        icon: const Icon(Icons.add),
        label: const Text('Agregar prenda'),
      ),
      body: FutureBuilder<List<Prenda>>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar: ${snapshot.error}'));
          }
          final prendas = snapshot.data ?? [];
          if (prendas.isEmpty) {
            return const Center(child: Text('Aún no tienes prendas. Agrega la primera.'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            itemCount: prendas.length,
            itemBuilder: (context, i) => _TarjetaPrenda(prenda: prendas[i]),
          );
        },
      ),
    );
  }
}

class _TarjetaPrenda extends StatelessWidget {
  const _TarjetaPrenda({required this.prenda});

  final Prenda prenda;

  @override
  Widget build(BuildContext context) {
    final url = prenda.urlImagen;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: url == null
                ? const Icon(Icons.checkroom, size: 48)
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              '${categorias[prenda.categoria] ?? prenda.categoria}, ${prenda.colorPrincipal}, ${estilos[prenda.estilo] ?? prenda.estilo}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
