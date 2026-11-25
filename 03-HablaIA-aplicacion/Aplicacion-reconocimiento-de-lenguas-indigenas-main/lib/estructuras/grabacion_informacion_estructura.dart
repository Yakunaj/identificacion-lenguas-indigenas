import 'dart:convert';

/// Coordenadas donde se hizo una grabación (WGS84, las que da el GPS).
class Ubicacion {
  /// Grados, -90..90.
  final double latitud;

  /// Grados, -180..180.
  final double longitud;

  /// Radio de error en metros, si el GPS lo reporta.
  final double? precisionMetros;

  Ubicacion({
    required this.latitud,
    required this.longitud,
    this.precisionMetros,
  }) {
    if (latitud.isNaN || latitud < -90 || latitud > 90) {
      throw ArgumentError.value(latitud, 'latitud', 'debe estar entre -90 y 90');
    }
    if (longitud.isNaN || longitud < -180 || longitud > 180) {
      throw ArgumentError.value(longitud, 'longitud', 'debe estar entre -180 y 180');
    }
    if (precisionMetros != null && precisionMetros! < 0) {
      throw ArgumentError.value(precisionMetros, 'precisionMetros', 'no puede ser negativa');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Ubicacion &&
      other.latitud == latitud &&
      other.longitud == longitud &&
      other.precisionMetros == precisionMetros;

  @override
  int get hashCode => Object.hash(latitud, longitud, precisionMetros);

  @override
  String toString() =>
      'Ubicacion($latitud, $longitud'
      '${precisionMetros == null ? '' : ' ±${precisionMetros}m'})';
}

/// Fila de la tabla `grabaciones` (ver GrabacionesDb).
class ResultadoGrabacion {
  final int? id;
  final int numero;
  final String idioma;
  final double confianza;
  final String versionModelo;
  final List<double> probabilidadesSegmento;
  final DateTime fechaHora;

  /// Duración en milisegundos.
  final int duracion;
  final int sampleRate;

  /// null si no se tenía permiso de ubicación o no hubo señal.
  final Ubicacion? ubicacion;

  /// Carpeta de la grabación (`.../Grabacion_<timestamp>`) con el audio.
  /// El audio no se guarda en SQLite, solo su ubicación en disco.
  final String? rutaSesion;

  ResultadoGrabacion({
    this.id,
    required this.numero,
    required this.idioma,
    required this.confianza,
    required this.versionModelo,
    required this.probabilidadesSegmento,
    required this.fechaHora,
    required this.duracion,
    required this.sampleRate,
    this.ubicacion,
    this.rutaSesion,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'numero': numero,
    'idioma': idioma,
    'confianza': confianza,
    'version_modelo': versionModelo,
    'prob_segmentos': jsonEncode(probabilidadesSegmento),
    'fecha_hora': fechaHora.toIso8601String(),
    'duracion_ms': duracion,
    'sample_rate_original': sampleRate,
    'latitud': ubicacion?.latitud,
    'longitud': ubicacion?.longitud,
    'precision_metros': ubicacion?.precisionMetros,
    'ruta_sesion': rutaSesion,
  };

  factory ResultadoGrabacion.fromMap(Map<String, Object?> m) {
    final latitud = m['latitud'] as num?;
    final longitud = m['longitud'] as num?;

    return ResultadoGrabacion(
      id: m['id'] as int?,
      numero: m['numero'] as int,
      idioma: m['idioma'] as String,
      confianza: (m['confianza'] as num).toDouble(),
      versionModelo: m['version_modelo'] as String,
      probabilidadesSegmento:
          (jsonDecode(m['prob_segmentos'] as String) as List)
              .map((e) => (e as num).toDouble())
              .toList(),
      fechaHora: DateTime.parse(m['fecha_hora'] as String),
      duracion: m['duracion_ms'] as int,
      sampleRate: m['sample_rate_original'] as int,
      ubicacion: latitud != null && longitud != null
          ? Ubicacion(
              latitud: latitud.toDouble(),
              longitud: longitud.toDouble(),
              precisionMetros: (m['precision_metros'] as num?)?.toDouble(),
            )
          : null,
      rutaSesion: m['ruta_sesion'] as String?,
    );
  }
}
