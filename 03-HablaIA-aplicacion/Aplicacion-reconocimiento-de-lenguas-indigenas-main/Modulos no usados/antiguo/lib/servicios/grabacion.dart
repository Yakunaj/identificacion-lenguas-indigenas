import 'dart:async';
import 'package:flutter/services.dart';

class Grabacion {
  static const MethodChannel _methodChannel =
      MethodChannel('com.Uuy/language');

  static const EventChannel _eventChannel =
      EventChannel('com.Uuy/stream');

  Stream<dynamic> get results =>
      _eventChannel.receiveBroadcastStream();

  Future<String?> iniciar() async {
    try {
      final String? id =
          await _methodChannel.invokeMethod("start");
      return id;
    } catch (e) {
      print("ERROR START: $e");
      return null;
    }
  }

  Future<void> detener() async {
    try {
      await _methodChannel.invokeMethod("stop");
    } catch (e) {
      print("ERROR STOP: $e");
    }
  }

  void liberar() {}
}