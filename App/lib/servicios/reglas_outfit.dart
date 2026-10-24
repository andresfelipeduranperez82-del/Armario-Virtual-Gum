import 'prendas_servicio.dart';

/* Reglas de combinación válida, iguales a las que valida la base de datos.
   Devuelve un mensaje si la combinación no cumple, o null si es válida. */
String? revisarReglasOutfit(List<Prenda> elegidas) {
  if (elegidas.isEmpty) {
    return 'Selecciona las prendas del outfit.';
  }
  final conteo = <String, int>{};
  for (final p in elegidas) {
    conteo[p.categoria] = (conteo[p.categoria] ?? 0) + 1;
  }
  for (final e in conteo.entries) {
    if (e.key != 'accesorios' && e.value > 1) {
      return 'Solo se permite una prenda por categoría, excepto accesorios. Revisa: ${categorias[e.key]}.';
    }
  }
  final conSuperiorEInferior = (conteo['superior'] ?? 0) >= 1 && (conteo['inferior'] ?? 0) >= 1;
  final conCuerpoCompleto = (conteo['cuerpo_completo'] ?? 0) >= 1;
  if (!conSuperiorEInferior && !conCuerpoCompleto) {
    return 'Elige una prenda superior y una inferior, o una de cuerpo completo.';
  }
  return null;
}
