import 'package:flutter/material.dart';

import '../servicios/cliente.dart';
import '../servicios/perfil_servicio.dart';
import '../servicios/sincronizacion.dart';

/* Círculo con la foto del usuario y una flecha. Al tocarlo se abre un menú con Mi perfil y Cerrar sesión */
class AvatarUsuario extends StatefulWidget {
  const AvatarUsuario({super.key, required this.alIrAlPerfil});

  final VoidCallback alIrAlPerfil;

  @override
  State<AvatarUsuario> createState() => _AvatarUsuarioState();
}

class _AvatarUsuarioState extends State<AvatarUsuario> {
  final _servicio = PerfilServicio();
  Perfil? _perfil;

  @override
  void initState() {
    super.initState();
    _cargar();
    Sincronizacion.instancia.tema('perfil').addListener(_cargar);
  }

  @override
  void dispose() {
    Sincronizacion.instancia.tema('perfil').removeListener(_cargar);
    super.dispose();
  }

  /* Si algo falla se queda el icono de persona, el encabezado no depende de la foto */
  Future<void> _cargar() async {
    try {
      final perfil = await _servicio.cargar();
      if (!mounted) return;
      setState(() => _perfil = perfil);
    } catch (_) {}
  }

  Widget _foto(double diametro) {
    final url = _perfil?.urlFoto;
    const icono = Icon(Icons.person, color: Colors.white);
    return Container(
      width: diametro,
      height: diametro,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF3C5287),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: url == null
          ? icono
          /* La foto es de cuerpo completo: se acerca hacia arriba para que se vea la cara */
          : Transform.scale(
              scale: 2.0,
              alignment: Alignment.topCenter,
              child: Image.network(
                url,
                width: diametro,
                height: diametro,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, _, _) => icono,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombre = _perfil?.nombre;
    return PopupMenuButton<String>(
      tooltip: (nombre != null && nombre.trim().isNotEmpty) ? nombre : 'Mi cuenta',
      offset: const Offset(0, 52),
      borderRadius: BorderRadius.circular(30),
      onSelected: (valor) {
        if (valor == 'perfil') {
          widget.alIrAlPerfil();
        } else {
          supabase.auth.signOut();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'perfil',
          child: Row(
            children: [
              Icon(Icons.person, size: 20),
              SizedBox(width: 12),
              Text('Mi perfil'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'salir',
          child: Row(
            children: [
              Icon(Icons.logout, size: 20, color: Colors.red.shade400),
              const SizedBox(width: 12),
              Text('Cerrar sesión', style: TextStyle(color: Colors.red.shade400)),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _foto(38),
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }
}
