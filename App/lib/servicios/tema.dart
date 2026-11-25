import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/* Guarda y carga el modo de tema elegido: claro, oscuro o el del sistema */
class TemaServicio {
  TemaServicio._();
  static final TemaServicio instancia = TemaServicio._();

  static const _clave = 'modo_tema';

  final ValueNotifier<ThemeMode> modo = ValueNotifier(ThemeMode.system);

  /* Se llama una vez al arrancar, antes de runApp, para que no parpadee el tema equivocado */
  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getString(_clave);
    modo.value = ThemeMode.values.firstWhere(
      (m) => m.name == guardado,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> cambiar(ThemeMode nuevo) async {
    modo.value = nuevo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, nuevo.name);
  }
}
