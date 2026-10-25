import 'package:flutter/material.dart';

import '../servicios/cliente.dart';
import '../servicios/outfits_servicio.dart';
import '../servicios/prendas_servicio.dart';
import 'pantalla_nuevo_outfit.dart';
import 'pantalla_probador.dart';

class PantallaOutfits extends StatefulWidget {
  const PantallaOutfits({super.key});

  @override
  State<PantallaOutfits> createState() => _PantallaOutfitsState();
}

class _PantallaOutfitsState extends State<PantallaOutfits> {
  final _servicio = OutfitsServicio();
  late Future<List<Outfit>> _futuro;

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

  Future<void> _nuevo() async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PantallaNuevoOutfit()),
    );
    if (guardado == true) {
      _recargar();
    }
  }

  void _probar(Outfit outfit) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PantallaProbador(outfit: outfit)),
    );
  }

  Future<void> _eliminar(Outfit outfit) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar outfit'),
        content: Text('¿Seguro que quieres eliminar "${outfit.nombre}"? Tus prendas no se borran.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await _servicio.eliminar(outfit.id);
      _recargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis outfits'),
        actions: [
          TextButton(
            onPressed: () => supabase.auth.signOut(),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevo,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo outfit'),
      ),
      body: FutureBuilder<List<Outfit>>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar: ${snapshot.error}'));
          }
          final outfits = snapshot.data ?? [];
          if (outfits.isEmpty) {
            return const Center(child: Text('Aún no tienes outfits. Arma el primero.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: outfits.length,
            itemBuilder: (context, i) => _TarjetaOutfit(
              outfit: outfits[i],
              alProbar: () => _probar(outfits[i]),
              alEliminar: () => _eliminar(outfits[i]),
            ),
          );
        },
      ),
    );
  }
}

class _TarjetaOutfit extends StatelessWidget {
  const _TarjetaOutfit({required this.outfit, required this.alProbar, required this.alEliminar});

  final Outfit outfit;
  final VoidCallback alProbar;
  final VoidCallback alEliminar;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    outfit.nombre,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                Chip(label: Text(estilos[outfit.estilo] ?? outfit.estilo)),
                IconButton(
                  onPressed: alProbar,
                  icon: const Icon(Icons.accessibility_new),
                  tooltip: 'Probar sobre mi foto',
                ),
                IconButton(
                  onPressed: alEliminar,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Eliminar outfit',
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: outfit.prendas.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final url = outfit.prendas[i].urlImagen;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 96,
                      child: url == null
                          ? const Icon(Icons.checkroom, size: 40)
                          : Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 40),
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
