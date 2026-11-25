import 'dart:math';

String obtenerImagenAleatoria() {
  final random = Random();

  final clases = ['espanol', 'nahuatl'];
  final clase = clases[random.nextInt(clases.length)];

  final numero = random.nextInt(5) + 1;
  print('$clase/$clase$numero.png');

  return 'lib/imagenes/$clase/$clase$numero.png';
}
