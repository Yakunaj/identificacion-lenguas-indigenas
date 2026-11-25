/// Describe un modelo y cómo usarlo.
///
/// Los modelos disponibles se declaran en
/// `modelos_disponibles_estructura.dart` (ver MODELOS.md).
class ConfiguracionModelo {
  /// Identificador único; se guarda como preferencia del usuario.
  final String id;

  /// Texto que ve el usuario al elegir modelo.
  final String nombre;

  /// Se guarda junto a cada resultado (`id@version`).
  final String version;

  /// Ruta del asset .tflite, p. ej. `lib/modelos/mi_modelo.tflite`.
  final String archivo;

  /// Si es true, se usa cuando el usuario aún no ha elegido modelo.
  final bool predeterminado;

  final ConfiguracionEntrada entrada;
  final ConfiguracionSalida salida;

  const ConfiguracionModelo({
    required this.id,
    required this.nombre,
    required this.version,
    required this.archivo,
    required this.entrada,
    required this.salida,
    this.predeterminado = false,
  });

  /// Texto que se guarda como "versión de modelo" en los resultados.
  String get identificadorVersion => '$id@$version';
}

/// Tipos de entrada soportados. Para agregar uno nuevo, añádelo aquí, crea
/// su constructor en [ConfiguracionEntrada] y su clase en
/// `servicios/modelo/entradas_modelo.dart`.
enum TipoEntrada {
  /// Imagen de espectrograma Mel [1, alto, ancho, canales] generada en nativo.
  espectrograma,

  /// Forma de onda cruda [1, muestras] (o [muestras], [1, muestras, 1]).
  audio,
}

/// Cómo escalar los valores antes de pasarlos a un tensor float32.
enum Normalizacion {
  /// Imagen: pixel / 255. Audio: (muestra + 1) / 2.
  ceroUno,

  /// Imagen: pixel / 127.5 - 1. Audio: muestra / 32768.
  menosUnoUno,

  /// Sin escalar: pixeles 0..255, audio en enteros de 16 bits.
  ninguna,
}

/// Mapa de colores del espectrograma.
enum MapaColor { inferno, gris }

/// Parámetros del espectrograma Mel. Los valores por defecto son los del
/// modelo MobileNetV3 original y coinciden con `ParametrosEspectrograma`
/// en Kotlin. El ancho y el alto se toman del tensor de entrada del modelo.
class ParametrosEspectrograma {
  final int sampleRate;

  /// Debe ser potencia de 2.
  final int nFft;
  final int hopLength;
  final int nMels;
  final double fMin;
  final double fMax;
  final double dbMin;
  final MapaColor mapaColor;

  const ParametrosEspectrograma({
    this.sampleRate = 16000,
    this.nFft = 2048,
    this.hopLength = 512,
    this.nMels = 128,
    this.fMin = 0,
    this.fMax = 8000,
    this.dbMin = -80,
    this.mapaColor = MapaColor.inferno,
  });

  /// Mapa que se envía al generador nativo por el MethodChannel.
  Map<String, Object> aMapa({required int ancho, required int alto}) => {
    'sample_rate': sampleRate,
    'n_fft': nFft,
    'hop_length': hopLength,
    'n_mels': nMels,
    'f_min': fMin,
    'f_max': fMax,
    'db_min': dbMin,
    'mapa_color': mapaColor.name,
    'ancho': ancho,
    'alto': alto,
  };
}

class ConfiguracionEntrada {
  final TipoEntrada tipo;
  final Normalizacion normalizacion;

  /// Solo para [TipoEntrada.espectrograma].
  final ParametrosEspectrograma espectrograma;

  /// Solo para [TipoEntrada.audio]: frecuencia de muestreo que espera el modelo.
  final int sampleRate;

  /// Solo para [TipoEntrada.audio]: muestras por ventana. Si es null se toma
  /// del tamaño del tensor de entrada.
  final int? muestras;

  /// Imagen de espectrograma Mel generada a partir del audio.
  const ConfiguracionEntrada.espectrograma({
    this.normalizacion = Normalizacion.ceroUno,
    this.espectrograma = const ParametrosEspectrograma(),
  }) : tipo = TipoEntrada.espectrograma,
       sampleRate = 16000,
       muestras = null;

  /// Forma de onda cruda, remuestreada a [sampleRate] y partida en ventanas
  /// de [muestras].
  const ConfiguracionEntrada.audio({
    this.sampleRate = 16000,
    this.muestras,
    this.normalizacion = Normalizacion.menosUnoUno,
  }) : tipo = TipoEntrada.audio,
       espectrograma = const ParametrosEspectrograma();
}

/// Qué produce el modelo.
enum TipoSalida {
  /// Un solo valor: probabilidad de `etiquetas[1]` (sigmoide).
  /// También acepta 2 valores (softmax de 2 clases).
  binaria,

  /// Un valor por etiqueta (softmax, o logits si `logits: true`).
  multiclase,
}

class ConfiguracionSalida {
  final TipoSalida tipo;

  /// Nombres de las clases en el MISMO orden que en el entrenamiento.
  final List<String> etiquetas;

  /// true si la salida son logits y hay que aplicar sigmoide/softmax.
  final bool logits;

  /// Dos clases. La salida del modelo es la probabilidad de [etiquetas][1].
  const ConfiguracionSalida.binaria({
    required this.etiquetas,
    this.logits = false,
  }) : tipo = TipoSalida.binaria;

  /// Una probabilidad por etiqueta.
  const ConfiguracionSalida.multiclase({
    required this.etiquetas,
    this.logits = false,
  }) : tipo = TipoSalida.multiclase;

  /// Lanza [StateError] si la configuración no tiene sentido.
  void validar(String idModelo) {
    if (etiquetas.length < 2) {
      throw StateError("El modelo '$idModelo' necesita al menos 2 etiquetas");
    }
    if (tipo == TipoSalida.binaria && etiquetas.length != 2) {
      throw StateError(
        "El modelo '$idModelo' es binario y necesita exactamente 2 etiquetas",
      );
    }
  }
}
