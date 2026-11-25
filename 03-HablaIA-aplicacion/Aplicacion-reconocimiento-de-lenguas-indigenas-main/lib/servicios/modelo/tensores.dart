import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

/// Utilidades para pasar valores flotantes a/desde tensores de cualquier tipo
/// soportado (float32, uint8 e int8 cuantizados).

const _tiposSoportados = {TensorType.float32, TensorType.uint8, TensorType.int8};

void validarTipoTensor(Tensor tensor, String rol) {
  if (!_tiposSoportados.contains(tensor.type)) {
    throw UnsupportedError(
      'Tensor de $rol con tipo ${tensor.type.name} no soportado '
      '(se soporta float32, uint8 e int8)',
    );
  }
}

/// Número de elementos de una forma (ignora dimensiones <= 0).
int numeroElementos(List<int> forma) =>
    forma.fold(1, (total, d) => d > 0 ? total * d : total);

/// Convierte [valores] (ya normalizados como espera el modelo en float) al
/// formato binario del [tensor]. Para tensores cuantizados aplica
/// `q = valor / escala + puntoCero`.
ByteBuffer codificarEntrada(Float32List valores, Tensor tensor) {
  switch (tensor.type) {
    case TensorType.float32:
      return valores.buffer;
    case TensorType.uint8:
    case TensorType.int8:
      final esUint8 = tensor.type == TensorType.uint8;
      final escala = tensor.params.scale;
      final puntoCero = tensor.params.zeroPoint;
      final minimo = esUint8 ? 0 : -128;
      final maximo = esUint8 ? 255 : 127;
      final salida = esUint8
          ? Uint8List(valores.length)
          : Int8List(valores.length);
      for (int i = 0; i < valores.length; i++) {
        final q = escala > 0
            ? (valores[i] / escala + puntoCero).round()
            : valores[i].round();
        salida[i] = q.clamp(minimo, maximo);
      }
      return salida.buffer;
    default:
      throw UnsupportedError('Tipo de tensor ${tensor.type.name} no soportado');
  }
}

/// Lee la salida del [tensor] (copiada en [bytes]) como flotantes,
/// des-cuantizando si hace falta.
List<double> decodificarSalida(ByteBuffer bytes, Tensor tensor) {
  final n = tensor.numElements();
  switch (tensor.type) {
    case TensorType.float32:
      return bytes.asFloat32List(0, n).toList();
    case TensorType.uint8:
    case TensorType.int8:
      final escala = tensor.params.scale;
      final puntoCero = tensor.params.zeroPoint;
      final crudos = tensor.type == TensorType.uint8
          ? bytes.asUint8List(0, n)
          : bytes.asInt8List(0, n);
      return [
        for (final v in crudos) escala > 0 ? (v - puntoCero) * escala : v / 255.0,
      ];
    default:
      throw UnsupportedError('Tipo de tensor ${tensor.type.name} no soportado');
  }
}

double sigmoide(double x) => 1 / (1 + math.exp(-x));

List<double> softmax(List<double> valores) {
  final maximo = valores.reduce(math.max);
  final exps = valores.map((v) => math.exp(v - maximo)).toList();
  final suma = exps.reduce((a, b) => a + b);
  return exps.map((e) => e / suma).toList();
}
