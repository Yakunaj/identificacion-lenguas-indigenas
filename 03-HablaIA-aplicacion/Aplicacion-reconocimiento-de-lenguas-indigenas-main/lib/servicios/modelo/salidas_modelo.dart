import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import '../../estructuras/modelo_configuracion_estructura.dart';
import 'tensores.dart';

/// Convierte la salida cruda del modelo en una probabilidad por etiqueta.
class SalidaModelo {
  final ConfiguracionSalida configuracion;
  final Interpreter interprete;

  SalidaModelo(this.configuracion, this.interprete) {
    final tensor = interprete.getOutputTensor(0);
    validarTipoTensor(tensor, 'salida');

    final n = tensor.numElements();
    final etiquetas = configuracion.etiquetas.length;
    final valido = switch (configuracion.tipo) {
      // Se acepta [1, 1] (sigmoide) o [1, 2] (softmax de 2 clases).
      TipoSalida.binaria => n == 1 || n == 2,
      TipoSalida.multiclase => n == etiquetas,
    };
    if (!valido) {
      throw FormatException(
        'La salida del modelo tiene $n valores (forma ${tensor.shape}) pero su '
        "configuración declara tipo '${configuracion.tipo.name}' con $etiquetas etiquetas",
      );
    }
  }

  /// Buffer donde el intérprete escribe la salida.
  ByteBuffer crearBuffer() =>
      Uint8List(interprete.getOutputTensor(0).numBytes()).buffer;

  /// Probabilidad (0–1) de cada etiqueta.
  Map<String, double> interpretar(ByteBuffer bytes) {
    final valores = decodificarSalida(bytes, interprete.getOutputTensor(0));
    final etiquetas = configuracion.etiquetas;

    final List<double> probabilidades;
    if (valores.length == 1) {
      final p = configuracion.logits ? sigmoide(valores[0]) : valores[0];
      probabilidades = [1 - p, p];
    } else {
      probabilidades = configuracion.logits ? softmax(valores) : valores;
    }

    return {
      for (int i = 0; i < etiquetas.length; i++) etiquetas[i]: probabilidades[i],
    };
  }
}
