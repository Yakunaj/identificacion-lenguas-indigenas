/// Resultado de clasificar un segmento con cualquier modelo.
class ResultadoClasificacion {
  /// Etiqueta (idioma) con mayor probabilidad.
  final String etiqueta;

  /// Confianza de [etiqueta] en porcentaje (0–100).
  final double confianza;

  /// Probabilidad (0–1) de cada etiqueta del modelo.
  final Map<String, double> probabilidades;

  /// `id@version` del modelo que produjo el resultado.
  final String versionModelo;

  const ResultadoClasificacion({
    required this.etiqueta,
    required this.confianza,
    required this.probabilidades,
    required this.versionModelo,
  });

  /// Construye el resultado eligiendo la etiqueta con mayor probabilidad.
  factory ResultadoClasificacion.desdeProbabilidades(
    Map<String, double> probabilidades, {
    required String versionModelo,
  }) {
    final mejor = probabilidades.entries.reduce(
      (a, b) => b.value > a.value ? b : a,
    );
    return ResultadoClasificacion(
      etiqueta: mejor.key,
      confianza: mejor.value * 100,
      probabilidades: Map.unmodifiable(probabilidades),
      versionModelo: versionModelo,
    );
  }

  @override
  String toString() =>
      'ResultadoClasificacion($etiqueta, ${confianza.toStringAsFixed(1)}%, $versionModelo)';
}
