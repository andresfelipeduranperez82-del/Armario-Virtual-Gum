import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pantallas/pantalla_catalogo.dart';
import 'pantallas/pantalla_login.dart';
import 'servicios/cliente.dart';

/* Las claves llegan desde env.json con --dart-define-from-file, nunca escritas aquí */
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);  runApp(const GumApp());
}

class GumApp extends StatelessWidget {
  const GumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gum Armario Virtual',
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      home: const PuertaDeEntrada(),
    );
  }
}

/* Muestra el login o el catálogo según haya sesión iniciada */
class PuertaDeEntrada extends StatelessWidget {
  const PuertaDeEntrada({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final sesion = supabase.auth.currentSession;
        return sesion == null ? const PantallaLogin() : const PantallaCatalogo();
      },
    );
  }
}
