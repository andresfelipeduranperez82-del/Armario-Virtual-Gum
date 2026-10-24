import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../servicios/cliente.dart';
import '../servicios/prendas_servicio.dart';
import '../servicios/recomendaciones_servicio.dart';

/* Bandeja de recomendaciones que te enviaron tus amigos */
class PantallaRecomendaciones extends StatefulWidget {
  const PantallaRecomendaciones({super.key});

  @override
  State<PantallaRecomendaciones> createState() => _PantallaRecomendacionesState();
}

class _PantallaRecomendacionesState extends State<PantallaRecomendaciones> {
  final _servicio = RecomendacionesServicio();
  late Future<List<Recomendacion>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _servicio.recibidas();
  }

  void _recargar() {
    setState(() {
      _futuro = _servicio.recibidas();
    });
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _aceptar(Recomendacion r) async {
    try {
      await _servicio.aceptar(r.id);
      if (!mounted) return;
      _aviso('"${r.nombre}" se agregó a tus outfits');
    } on PostgrestException catch (e) {
      if (!mounted) return;
      _aviso(e.message);
    } catch (e) {
      if (!mounted) return;
      _aviso('No se pudo aceptar: $e');
    }
    _recargar();
  }

  Future<void> _descartar(Recomendacion r) async {
    try {
      await _servicio.descartar(r.id);
      if (!mounted) return;
      _aviso('Recomendación descartada');
    } catch (e) {
      if (!mounted) return;
      _aviso('No se pudo descartar: $e');
    }
    _recargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recomendaciones'),
        actions: [
          IconButton(onPressed: _recargar, icon: const Icon(Icons.refresh), tooltip: 'Actualizar'),
          TextButton(
            onPressed: () => supabase.auth.signOut(),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
      body: FutureBuilder<List<Recomendacion>>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar: ${snapshot.error}'));
          }
          final recomendaciones = snapshot.data ?? [];
          if (recomendaciones.isEmpty) {
            return const Center(child: Text('No tienes recomendaciones pendientes.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: recomendaciones.length,
            itemBuilder: (context, i) => _TarjetaRecomendacion(
              recomendacion: recomendaciones[i],
              alAceptar: () => _aceptar(recomendaciones[i]),
              alDescartar: () => _descartar(recomendaciones[i]),
            ),
          );
        },
      ),
    );
  }
}

class _TarjetaRecomendacion extends StatelessWidget {
  const _TarjetaRecomendacion({
    required this.recomendacion,
    required this.alAceptar,
    required this.alDescartar,
  });

  final Recomendacion recomendacion;
  final VoidCallback alAceptar;
  final VoidCallback alDescartar;

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recomendacion.nombre,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      Text('De ${recomendacion.remitente}', style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                Chip(label: Text(estilos[recomendacion.estilo] ?? recomendacion.estilo)),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recomendacion.prendas.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final url = recomendacion.prendas[i].urlImagen;
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
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: alDescartar, child: const Text('Descartar')),
                const SizedBox(width: 8),
                FilledButton(onPressed: alAceptar, child: const Text('Aceptar')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
