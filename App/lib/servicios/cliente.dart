import 'package:supabase_flutter/supabase_flutter.dart';

/* Acceso corto al cliente de Supabase desde cualquier archivo */
SupabaseClient get supabase => Supabase.instance.client;
