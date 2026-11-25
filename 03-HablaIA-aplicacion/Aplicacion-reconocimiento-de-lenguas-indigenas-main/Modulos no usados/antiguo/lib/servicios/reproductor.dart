import 'package:audioplayers/audioplayers.dart';

class ReproductorAudio {
  // 1. Instanciar el reproductor
  final AudioPlayer _audioPlayer = AudioPlayer();

  // 2. Función para reproducir usando la ruta que te dio Kotlin
  Future<void> reproducir(String ruta) async {
    try {
      // Le decimos a la librería que es un archivo físico interno del dispositivo
      await _audioPlayer.play(DeviceFileSource(ruta));
    } catch (e) {
      print("Error al reproducir el archivo: $e");
    }
  }

  // 3. Controles básicos
  Future<void> pausar() async {
    await _audioPlayer.pause();
  }

  Future<void> detener() async {
    await _audioPlayer.stop();
  }
}