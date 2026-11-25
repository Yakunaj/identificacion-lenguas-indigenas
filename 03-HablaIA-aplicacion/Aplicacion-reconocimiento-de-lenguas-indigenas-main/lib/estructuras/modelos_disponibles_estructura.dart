import 'modelo_configuracion_estructura.dart';

/// Catálogo de modelos que puede usar la app.
///
/// Para agregar un modelo:
///   1. copia el .tflite a `lib/modelos/`,
///   2. agrega aquí su [ConfiguracionModelo].
/// El usuario lo elige con el botón ⚙ de la pantalla principal.
///
/// Ejemplos de otros tipos:
///
/// ```dart
/// // Audio crudo, 3 idiomas, salida softmax:
/// ConfiguracionModelo(
///   id: 'wav_es_maya_nahuatl',
///   nombre: 'Audio crudo · Español / Maya / Náhuatl',
///   version: '1.0',
///   archivo: 'lib/modelos/wav_tres_idiomas.tflite',
///   entrada: ConfiguracionEntrada.audio(sampleRate: 16000, muestras: 16000),
///   salida: ConfiguracionSalida.multiclase(
///     etiquetas: ['español', 'maya', 'náhuatl'],
///   ),
/// ),
///
/// // Espectrograma en gris de 64 bandas, salida con logits:
/// ConfiguracionModelo(
///   id: 'cnn_gris',
///   nombre: 'CNN gris · Español / Maya',
///   version: '1.0',
///   archivo: 'lib/modelos/cnn_gris.tflite',
///   entrada: ConfiguracionEntrada.espectrograma(
///     espectrograma: ParametrosEspectrograma(
///       nMels: 64,
///       mapaColor: MapaColor.gris,
///     ),
///   ),
///   salida: ConfiguracionSalida.binaria(
///     etiquetas: ['español', 'maya'],
///     logits: true,
///   ),
/// ),
/// ```
const List<ConfiguracionModelo> modelosDisponibles = [
  ConfiguracionModelo(
    id: 'mobilenetv3_es_maya',
    nombre: 'MobileNetV3 · Español / Maya',
    version: '1.0',
    archivo: 'lib/modelos/MobileNetV3Large_normal.tflite',
    predeterminado: true,
    entrada: ConfiguracionEntrada.espectrograma(
      normalizacion: Normalizacion.ceroUno,
      espectrograma: ParametrosEspectrograma(
        sampleRate: 16000,
        nFft: 2048,
        hopLength: 512,
        nMels: 128,
        fMin: 0,
        fMax: 8000,
        dbMin: -80,
        mapaColor: MapaColor.inferno,
      ),
    ),
    salida: ConfiguracionSalida.binaria(etiquetas: ['español', 'maya']),
  ),
];
