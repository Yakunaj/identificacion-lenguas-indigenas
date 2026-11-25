import 'package:flutter/foundation.dart';

class WaveformServicio extends ChangeNotifier {
  final List<double> _amplitudes = [];


  final int maxMuestras;

  WaveformServicio({
    this.maxMuestras = 10,
  });

  List<double> get amplitudes =>
      List.unmodifiable(_amplitudes);


  void agregarAmplitud(double amplitud) {
    amplitud = amplitud.clamp(0.0, 1.0);

    _amplitudes.add(amplitud);


    if (_amplitudes.length > maxMuestras) {
      _amplitudes.removeAt(0);
    }

    notifyListeners();
  }

  void limpiar() {
    _amplitudes.clear();
    notifyListeners();
  }


  void reiniciar() {
    _amplitudes.clear();
    notifyListeners();
  }
}