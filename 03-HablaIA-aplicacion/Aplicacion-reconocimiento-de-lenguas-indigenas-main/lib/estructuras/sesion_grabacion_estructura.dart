import 'grabacion_informacion_estructura.dart';
import 'resultado_clasificacion_estructura.dart';

/// Acumula los resultados de los segmentos de una grabación en vivo y los
/// resume en una fila para SQLite al detener.
class SesionGrabacion {
  /// Carpeta `.../Grabacion_<timestamp>` que devuelve el grabador nativo.
  final String rutaSesion;
  final DateTime inicio;

  final List<ResultadoClasificacion> _segmentos = [];

  /// Frecuencia de muestreo del audio grabado (se lee del primer WAV).
  int? sampleRate;

  SesionGrabacion({required this.rutaSesion, required this.inicio});

  List<ResultadoClasificacion> get segmentos => List.unmodifiable(_segmentos);

  void agregar(ResultadoClasificacion resultado) => _segmentos.add(resultado);

  /// Resume la sesión. Devuelve null si no se clasificó ningún segmento
  /// (grabación de menos de 5 s).
  ///
  /// Mismo criterio que el análisis de la lista de audios: gana el idioma
  /// con más segmentos (en empate, el que apareció primero) y la confianza es
  /// el promedio de la confianza de ese idioma en los segmentos que ganó.
  /// `probabilidadesSegmento` guarda la probabilidad (0–1) del idioma ganador
  /// en cada segmento, en orden.
  ResultadoGrabacion? resumir({
    required int numero,
    required DateTime fin,
    Ubicacion? ubicacion,
  }) {
    if (_segmentos.isEmpty) return null;

    final votos = <String, int>{};
    final confianzaTotal = <String, double>{};
    for (final s in _segmentos) {
      votos[s.etiqueta] = (votos[s.etiqueta] ?? 0) + 1;
      confianzaTotal[s.etiqueta] = (confianzaTotal[s.etiqueta] ?? 0) + s.confianza;
    }
    final ganador = votos.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    return ResultadoGrabacion(
      numero: numero,
      idioma: ganador,
      confianza: confianzaTotal[ganador]! / votos[ganador]!,
      versionModelo: _segmentos.first.versionModelo,
      probabilidadesSegmento: [
        for (final s in _segmentos) s.probabilidades[ganador] ?? 0,
      ],
      fechaHora: inicio,
      duracion: fin.difference(inicio).inMilliseconds,
      sampleRate: sampleRate ?? 16000,
      ubicacion: ubicacion,
      rutaSesion: rutaSesion,
    );
  }
}
