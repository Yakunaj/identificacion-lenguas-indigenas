import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../estructuras/modelo_configuracion_estructura.dart';
import '../../estructuras/segmento_audio_estructura.dart';
import 'tensores.dart';

/// Convierte un [SegmentoAudio] en la(s) entrada(s) que espera un modelo.
///
/// Para soportar un tipo de entrada nuevo (p. ej. MFCC):
///   1. agrega el valor en [TipoEntrada],
///   2. crea una subclase de [EntradaModelo],
///   3. regístrala en [EntradaModelo.crear].
///   (y su constructor en [ConfiguracionEntrada])
abstract class EntradaModelo {
  /// Devuelve una entrada por ventana; los resultados de todas las ventanas
  /// se promedian. La mayoría de los modelos devuelve una sola.
  Future<List<ByteBuffer>> preparar(SegmentoAudio segmento);

  static EntradaModelo crear(
    ConfiguracionEntrada configuracion,
    Interpreter interprete,
  ) {
    switch (configuracion.tipo) {
      case TipoEntrada.espectrograma:
        return EntradaEspectrograma(configuracion, interprete);
      case TipoEntrada.audio:
        return EntradaAudio(configuracion, interprete);
    }
  }
}

/// Imagen de espectrograma Mel generada en nativo (Kotlin) con los parámetros
/// del modelo. Ancho, alto y canales se leen del tensor de entrada.
class EntradaEspectrograma implements EntradaModelo {
  static const MethodChannel _canal = MethodChannel('com.hablaia/language');

  final ConfiguracionEntrada configuracion;
  final Interpreter interprete;

  late final int alto;
  late final int ancho;
  late final int canales;

  /// true si el tensor es [1, C, H, W] en lugar de [1, H, W, C].
  late final bool canalesPrimero;

  EntradaEspectrograma(this.configuracion, this.interprete) {
    final tensor = interprete.getInputTensor(0);
    validarTipoTensor(tensor, 'entrada');

    final forma = tensor.shape;
    if (forma.length != 3 && forma.length != 4) {
      throw FormatException(
        'Un modelo de espectrograma necesita una entrada [1, alto, ancho, canales]; '
        'el modelo tiene $forma',
      );
    }
    final dims = forma.sublist(forma.length - 3);
    canalesPrimero = (dims[0] == 1 || dims[0] == 3) && dims[2] != 1 && dims[2] != 3;
    if (canalesPrimero) {
      canales = dims[0];
      alto = dims[1];
      ancho = dims[2];
    } else {
      alto = dims[0];
      ancho = dims[1];
      canales = dims[2];
    }
    if (canales != 1 && canales != 3) {
      throw FormatException('Se esperaban 1 o 3 canales de imagen; el modelo tiene $canales');
    }
  }

  @override
  Future<List<ByteBuffer>> preparar(SegmentoAudio segmento) async {
    final respuesta = await _canal.invokeMapMethod<String, dynamic>(
      'espectrograma',
      {
        'ruta': segmento.rutaWav,
        'parametros': configuracion.espectrograma.aMapa(
          ancho: ancho,
          alto: alto,
        ),
      },
    );
    final rgb = respuesta?['rgb'];
    if (rgb is! Uint8List || rgb.length != ancho * alto * 3) {
      throw StateError('El generador nativo devolvió un espectrograma inválido');
    }

    final valores = Float32List(alto * ancho * canales);
    final planos = alto * ancho;
    for (int i = 0; i < planos; i++) {
      final r = rgb[i * 3], g = rgb[i * 3 + 1], b = rgb[i * 3 + 2];
      if (canales == 1) {
        valores[i] = _normalizar((r + g + b) / 3);
      } else if (canalesPrimero) {
        valores[i] = _normalizar(r.toDouble());
        valores[planos + i] = _normalizar(g.toDouble());
        valores[2 * planos + i] = _normalizar(b.toDouble());
      } else {
        valores[i * 3] = _normalizar(r.toDouble());
        valores[i * 3 + 1] = _normalizar(g.toDouble());
        valores[i * 3 + 2] = _normalizar(b.toDouble());
      }
    }

    return [codificarEntrada(valores, interprete.getInputTensor(0))];
  }

  double _normalizar(double pixel) {
    switch (configuracion.normalizacion) {
      case Normalizacion.ceroUno:
        return pixel / 255.0;
      case Normalizacion.menosUnoUno:
        return pixel / 127.5 - 1.0;
      case Normalizacion.ninguna:
        return pixel;
    }
  }
}

/// Forma de onda cruda. El segmento se remuestrea a `sample_rate` y se parte
/// en ventanas del tamaño de entrada del modelo (rellenando con ceros la
/// última). Cada ventana se clasifica y los resultados se promedian.
class EntradaAudio implements EntradaModelo {
  final ConfiguracionEntrada configuracion;
  final Interpreter interprete;

  /// Muestras por ventana.
  late final int muestrasVentana;

  EntradaAudio(this.configuracion, this.interprete) {
    var tensor = interprete.getInputTensor(0);
    validarTipoTensor(tensor, 'entrada');

    final deseadas = configuracion.muestras;
    final actuales = numeroElementos(tensor.shape);

    if (deseadas != null && deseadas != actuales) {
      // Modelos con entrada dinámica: ajustamos el tensor al tamaño pedido.
      // Se reemplaza la dimensión de tiempo: la mayor, o la 2ª si todas valen 1
      // (p. ej. [1, 1] -> [1, muestras]; [1, 16000, 1] -> [1, muestras, 1]).
      final forma = List<int>.from(tensor.shape);
      if (forma.isEmpty) {
        forma.add(deseadas);
      } else {
        int idxTiempo = forma.length == 1 ? 0 : 1;
        for (int i = 0; i < forma.length; i++) {
          if (forma[i] > forma[idxTiempo]) idxTiempo = i;
        }
        forma[idxTiempo] = deseadas;
      }
      interprete.resizeInputTensor(0, forma);
      interprete.allocateTensors();
      tensor = interprete.getInputTensor(0);
    }

    muestrasVentana = numeroElementos(tensor.shape);
    if (muestrasVentana < 2) {
      throw FormatException(
        "No se pudo determinar el tamaño de entrada de audio (forma ${tensor.shape}). "
        "Indica 'muestras' en ConfiguracionEntrada.audio(...).",
      );
    }
  }

  @override
  Future<List<ByteBuffer>> preparar(SegmentoAudio segmento) async {
    final pcm = await segmento.leerPcm();
    final audio = pcm.remuestrear(configuracion.sampleRate);
    final tensor = interprete.getInputTensor(0);

    final ventanas = <ByteBuffer>[];
    for (int inicio = 0; inicio < audio.length; inicio += muestrasVentana) {
      final restantes = audio.length - inicio;
      // Descarta un pedazo final muy corto si ya hay otras ventanas.
      if (ventanas.isNotEmpty && restantes < muestrasVentana ~/ 2) break;

      final ventana = Float32List(muestrasVentana);
      final n = restantes < muestrasVentana ? restantes : muestrasVentana;
      for (int i = 0; i < n; i++) {
        ventana[i] = _normalizar(audio[inicio + i]);
      }
      ventanas.add(codificarEntrada(ventana, tensor));
    }

    if (ventanas.isEmpty) {
      ventanas.add(codificarEntrada(Float32List(muestrasVentana), tensor));
    }
    return ventanas;
  }

  /// [muestra] llega en -1..1.
  double _normalizar(double muestra) {
    switch (configuracion.normalizacion) {
      case Normalizacion.menosUnoUno:
        return muestra;
      case Normalizacion.ceroUno:
        return (muestra + 1) / 2;
      case Normalizacion.ninguna:
        return muestra * 32768.0;
    }
  }
}
