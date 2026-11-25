import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Clase de servicio para manejar la grabación de audio y la comunicación con el canal nativo.
class Grabacion {
  static const MethodChannel _methodChannel =
      MethodChannel('com.hablaia/language');

  static const EventChannel _eventChannel =
      EventChannel('com.hablaia/stream');

  Stream<dynamic> get results =>
      _eventChannel.receiveBroadcastStream();

// Inicia la grabación de audio y devuelve un ID de grabación si es exitoso.
  Future<String?> iniciar() async {
    try {
      final String? id =
          await _methodChannel.invokeMethod("start");
      return id;
    } catch (e) {
      debugPrint("ERROR START: $e");
      return null;
    }
  }

// Detiene la grabación de audio.
  Future<void> detener() async {
    try {
      await _methodChannel.invokeMethod("stop");
    } catch (e) {
      debugPrint("ERROR STOP: $e");
    }
  }

  void liberar() {}
}