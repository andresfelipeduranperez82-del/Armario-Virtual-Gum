import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

/* Quita el fondo claro de la foto de una prenda y devuelve una imagen con transparencia.

   Cómo funciona: toma como color de fondo el promedio de los píxeles del borde y borra,
   avanzando desde los bordes hacia adentro, los píxeles parecidos a ese color. Como solo
   avanza desde afuera, el interior de una prenda blanca no se borra.

   Limitación: funciona bien con fondos lisos y claros. Con fondos oscuros, con textura
   o con mucho degradado, el resultado es parcial. Para esos casos haría falta un
   recorte con inteligencia artificial.

   [tolerancia] es qué tan distinto del color de fondo puede ser un píxel para borrarse. */
Future<ui.Image> recortarFondo(
  Uint8List bytes, {
  double tolerancia = 38,
  int anchoMaximo = 600,
}) async {
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: anchoMaximo);
  final cuadro = await codec.getNextFrame();
  final origen = cuadro.image;
  final ancho = origen.width;
  final alto = origen.height;
  final datos = await origen.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  origen.dispose();
  codec.dispose();
  if (datos == null) {
    throw Exception('No se pudo leer la imagen');
  }
  final px = Uint8List.fromList(datos.buffer.asUint8List());
  final total = ancho * alto;

  /* Color de fondo: promedio de los píxeles del borde */
  var sumaR = 0;
  var sumaG = 0;
  var sumaB = 0;
  var cuenta = 0;
  void muestrear(int x, int y) {
    final i = (y * ancho + x) * 4;
    sumaR += px[i];
    sumaG += px[i + 1];
    sumaB += px[i + 2];
    cuenta++;
  }

  for (var x = 0; x < ancho; x++) {
    muestrear(x, 0);
    muestrear(x, alto - 1);
  }
  for (var y = 1; y < alto - 1; y++) {
    muestrear(0, y);
    muestrear(ancho - 1, y);
  }
  final fondoR = sumaR / cuenta;
  final fondoG = sumaG / cuenta;
  final fondoB = sumaB / cuenta;

  double distancia2(int idx) {
    final i = idx * 4;
    final dr = px[i] - fondoR;
    final dg = px[i + 1] - fondoG;
    final db = px[i + 2] - fondoB;
    return dr * dr + dg * dg + db * db;
  }

  final umbral = tolerancia * tolerancia;

  /* Recorrido desde los bordes hacia adentro */
  final fondo = Uint8List(total);
  final cola = Int32List(total);
  var inicio = 0;
  var fin = 0;

  void agregar(int idx) {
    if (fondo[idx] == 0 && distancia2(idx) <= umbral) {
      fondo[idx] = 1;
      cola[fin++] = idx;
    }
  }

  for (var x = 0; x < ancho; x++) {
    agregar(x);
    agregar((alto - 1) * ancho + x);
  }
  for (var y = 0; y < alto; y++) {
    agregar(y * ancho);
    agregar(y * ancho + ancho - 1);
  }

  while (inicio < fin) {
    final idx = cola[inicio++];
    final x = idx % ancho;
    final y = idx ~/ ancho;
    if (x > 0) agregar(idx - 1);
    if (x < ancho - 1) agregar(idx + 1);
    if (y > 0) agregar(idx - ancho);
    if (y < alto - 1) agregar(idx + ancho);
  }

  bool tieneVecino(Uint8List mapa, int x, int y) {
    final idx = y * ancho + x;
    if (x > 0 && mapa[idx - 1] == 1) return true;
    if (x < ancho - 1 && mapa[idx + 1] == 1) return true;
    if (y > 0 && mapa[idx - ancho] == 1) return true;
    if (y < alto - 1 && mapa[idx + ancho] == 1) return true;
    return false;
  }

  /* Quita el halo: píxeles del contorno que todavía se parecen al fondo */
  final transparente = Uint8List.fromList(fondo);
  final umbralHalo = umbral * 3.0;
  for (var y = 0; y < alto; y++) {
    for (var x = 0; x < ancho; x++) {
      final idx = y * ancho + x;
      if (fondo[idx] == 0 && tieneVecino(fondo, x, y) && distancia2(idx) <= umbralHalo) {
        transparente[idx] = 1;
      }
    }
  }

  /* Suaviza el borde: una línea de píxeles semitransparentes alrededor de la prenda */
  final borde = Uint8List(total);
  for (var y = 0; y < alto; y++) {
    for (var x = 0; x < ancho; x++) {
      final idx = y * ancho + x;
      if (transparente[idx] == 0 && tieneVecino(transparente, x, y)) {
        borde[idx] = 1;
      }
    }
  }

  const alfaBorde = 130;
  for (var idx = 0; idx < total; idx++) {
    final i = idx * 4;
    if (transparente[idx] == 1) {
      px[i] = 0;
      px[i + 1] = 0;
      px[i + 2] = 0;
      px[i + 3] = 0;
    } else if (borde[idx] == 1) {
      px[i] = px[i] * alfaBorde ~/ 255;
      px[i + 1] = px[i + 1] * alfaBorde ~/ 255;
      px[i + 2] = px[i + 2] * alfaBorde ~/ 255;
      px[i + 3] = alfaBorde;
    }
  }

  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(px, ancho, alto, ui.PixelFormat.rgba8888, completer.complete);
  return completer.future;
}
