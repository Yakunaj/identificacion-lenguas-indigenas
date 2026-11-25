import 'dart:typed_data';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/material.dart';

// Clase de servicio para manejar la carga y uso del modelo TFLite para clasificación de imágenes.
class UsoModelo {
  Interpreter? _interpreter;
  final List<String> classNames = ["español", "maya"];

// Carga el modelo TFLite desde los assets de la aplicación.
  Future<void> cargarModelo() async {
    _interpreter = await Interpreter.fromAsset(
      "lib/modelos/MobileNetV3Large_normal.tflite",
    );
  }

// Clasifica una imagen representada como bytes (Uint8List) y devuelve el nombre de la clase y la confianza.
  Future<Map<String, dynamic>> clasificar(Uint8List imageBytes) async {
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

    var outputBuffer = List.generate(1, (_) => List.filled(1, 0.0));

    try {
      _interpreter!.run(input4D, outputBuffer);
    } catch (e) {
      debugPrint("Error interno del procesador TFLite al ejecutar los tensores: $e");
      throw Exception("Fallo en la inferencia del modelo: $e");
    }
    final double rawScore = outputBuffer[0][0];
    final int predictedIdx = rawScore > 0.5 ? 1 : 0;
    final double confidence = predictedIdx == 1 ? rawScore : (1 - rawScore);
    debugPrint("Score crudo (sigmoid): ${rawScore.toStringAsFixed(4)}");
    debugPrint("Predicción: ${classNames[predictedIdx]} con confianza de ${(confidence * 100).toStringAsFixed(2)}%");
    return {
      "className": classNames[predictedIdx],
      "confidence": confidence * 100
    };
  }

  void cerrar() {
    _interpreter?.close();
  }

// Clasifica una imagen desde un archivo PNG y devuelve el nombre de la clase y la confianza.
  Future<Map<String, dynamic>> clasificarDesdeArchivo(String rutaPng) async {
    final file = File(rutaPng);

    if (!await file.exists()) {
      throw Exception("Archivo no encontrado: $rutaPng");
    }

    final Uint8List bytes = await file.readAsBytes();

    return clasificar(bytes);
  }
}