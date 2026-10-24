import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../servicios/cliente.dart';

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
    return Scaffold(
      body: Center(
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
      ),
    );
  }
}
