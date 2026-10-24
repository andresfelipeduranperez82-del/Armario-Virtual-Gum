import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/* Las claves llegan desde env.json con --dart-define-from-file, nunca escritas aquí */
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const GumApp());
}

final supabase = Supabase.instance.client;

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

/* Decide qué pantalla mostrar según haya o no sesión iniciada.
   Incluye una línea de depuración temporal para ver qué está pasando. */
class PuertaDeEntrada extends StatefulWidget {
  const PuertaDeEntrada({super.key});

  @override
  State<PuertaDeEntrada> createState() => _PuertaDeEntradaState();
}

class _PuertaDeEntradaState extends State<PuertaDeEntrada> {
  String _ultimoEvento = 'ninguno';
  String _errorStream = '';
  late final StreamSubscription<AuthState> _suscripcion;

  @override
  void initState() {
    super.initState();
    _suscripcion = supabase.auth.onAuthStateChange.listen(
      (datos) => setState(() => _ultimoEvento = datos.event.name),
      onError: (Object e) => setState(() => _errorStream = e.toString()),
    );
  }

  @override
  void dispose() {
    _suscripcion.cancel();
    super.dispose();
  }

  /* Busca un mensaje de error que Supabase haya dejado en la dirección */
  String _errorDeLaUrl() {
    final parametros = <String, String>{...Uri.base.queryParameters};
    if (Uri.base.fragment.contains('=')) {
      try {
        parametros.addAll(Uri.splitQueryString(Uri.base.fragment));
      } catch (_) {}
    }
    return parametros['error_description'] ?? parametros['error'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final sesion = supabase.auth.currentSession;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: sesion == null
                ? const PantallaLogin()
                : PantallaInicio(userId: sesion.user.id, email: sesion.user.email ?? ''),
          ),
          Container(
            width: double.infinity,
            color: Colors.black12,
            padding: const EdgeInsets.all(8),
            child: Text(
              'Depuración: evento=$_ultimoEvento, sesión=${sesion != null}, '
              'errorUrl=${_errorDeLaUrl()}, errorStream=$_errorStream',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class PantallaLogin extends StatelessWidget {
  const PantallaLogin({super.key});

  Future<void> _entrarConGoogle() async {
    await supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      /* En web vuelve a la misma página. En Android se configura un deep link más adelante */
      redirectTo: kIsWeb ? null : 'io.supabase.flutter://callback',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Gum Armario Virtual', style: TextStyle(fontSize: 28)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _entrarConGoogle,
            icon: const Icon(Icons.login),
            label: const Text('Iniciar sesión con Google'),
          ),
        ],
      ),
    );
  }
}

class PantallaInicio extends StatelessWidget {
  const PantallaInicio({super.key, required this.userId, required this.email});

  final String userId;
  final String email;

  /* Lee el perfil que creó automáticamente el trigger de la base de datos */
  Future<String> _cargarPerfil() async {
    final perfil = await supabase.from('perfiles').select().eq('id', userId).maybeSingle();
    if (perfil == null) {
      return 'No se encontró el perfil en la base de datos';
    }
    return 'Perfil encontrado: ${perfil['nombre']}';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Sesión iniciada como $email'),
          const SizedBox(height: 12),
          FutureBuilder<String>(
            future: _cargarPerfil(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              return Text(snapshot.data ?? 'Cargando perfil...');
            },
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => supabase.auth.signOut(),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}
