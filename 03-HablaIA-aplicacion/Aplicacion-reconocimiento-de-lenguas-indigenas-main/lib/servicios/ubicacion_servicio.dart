import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../estructuras/grabacion_informacion_estructura.dart';

/// Obtiene la ubicación del teléfono para guardarla con cada grabación.
///
/// Nunca bloquea ni impide grabar: si no hay permiso, el GPS está apagado o
/// no hay señal, devuelve null y la grabación se guarda sin ubicación.
class UbicacionServicio {
  /// Pide el permiso de ubicación si aún no se ha decidido.
  /// Devuelve true si se puede usar la ubicación.
  Future<bool> pedirPermiso() async {
    try {
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      return permiso == LocationPermission.whileInUse ||
          permiso == LocationPermission.always;
    } catch (e) {
      debugPrint('No se pudo pedir el permiso de ubicación: $e');
      return false;
    }
  }

  /// Ubicación actual, o null si no se puede obtener en [limite].
  /// Si el GPS tarda demasiado, usa la última posición conocida.
  Future<Ubicacion?> obtener({
    Duration limite = const Duration(seconds: 15),
  }) async {
    try {
      final permiso = await Geolocator.checkPermission();
      if (permiso != LocationPermission.whileInUse &&
          permiso != LocationPermission.always) {
        return null;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      Position? posicion;
      try {
        posicion = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: limite,
          ),
        );
      } on TimeoutException {
        posicion = await Geolocator.getLastKnownPosition();
      }
      if (posicion == null) return null;

      return Ubicacion(
        latitud: posicion.latitude,
        longitud: posicion.longitude,
        precisionMetros: posicion.accuracy > 0 ? posicion.accuracy : null,
      );
    } catch (e) {
      debugPrint('No se pudo obtener la ubicación: $e');
      return null;
    }
  }
}
