import 'dart:typed_data';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class UsoModelo {
  Interpreter? _interpreter;

  // Orden alfabético — debe coincidir exactamente con el que usó
  // image_dataset_from_directory durante el entrenamiento (índice 0 y 1)
  final List<String> classNames = ["maya", "español"];

  Future<void> cargarModelo() async {
    _interpreter = await Interpreter.fromAsset(
      "lib/modelos/MobileNetV3Large_normal.tflite",
    );
  }

  Future<Map<String, dynamic>> clasificar(Uint8List imageBytes) async {
    // 1. Validar preventivamente que el modelo no esté vacío en memoria
    if (_interpreter == null) {
      throw Exception("El intérprete TFLite no ha sido inicializado. Llama a cargarModelo() primero.");
    }

    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception("No se pudo leer la imagen del espectrograma");
    }

    img.Image resized = img.copyResize(image, width: 224, height: 224);

    var input4D = List.generate(1, (_) =>
      List.generate(224, (y) =>
        List.generate(224, (x) {
          final pixel = resized.getPixel(x, y);
          return [
            pixel.r / 255.0,
            pixel.g / 255.0,
            pixel.b / 255.0,
          ];
        })
      )
    );

    // El modelo tiene 1 sola neurona de salida (Dense(1, activation="sigmoid")),
    // NO 2 clases con softmax -> el buffer de salida debe ser shape [1, 1]
    var outputBuffer = List.generate(1, (_) => List.filled(1, 0.0));

    try {
      _interpreter!.run(input4D, outputBuffer);
    } catch (e) {
      print("Error interno del procesador TFLite al ejecutar los tensores: $e");
      throw Exception("Fallo en la inferencia del modelo: $e");
    }

    // Único valor sigmoid entre 0 y 1
    final double rawScore = outputBuffer[0][0];

    // Umbral 0.5, no argmax: classNames[0]="español" si rawScore<=0.5,
    // classNames[1]="maya" si rawScore>0.5 (mismo orden alfabético del entrenamiento)
    final int predictedIdx = rawScore > 0.5 ? 1 : 0;
    final double confidence = predictedIdx == 1 ? rawScore : (1 - rawScore);

    print("Score crudo (sigmoid): ${rawScore.toStringAsFixed(4)}");
    print("Predicción: ${classNames[predictedIdx]} con confianza de ${(confidence * 100).toStringAsFixed(2)}%");

    return {
      "className": classNames[predictedIdx],
      "confidence": confidence * 100
    };
  }

  void cerrar() {
    _interpreter?.close();
  }

  Future<Map<String, dynamic>> clasificarDesdeArchivo(String rutaPng) async {
    final file = File(rutaPng);

    if (!await file.exists()) {
      throw Exception("Archivo no encontrado: $rutaPng");
    }

    final Uint8List bytes = await file.readAsBytes();

    return clasificar(bytes);
  }
}