import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

// Clase de servicio para manejar la reproducción de audio.
class ReproductorAudio {
  final AudioPlayer _audioPlayer = AudioPlayer();

// Inicialización del reproductor de audio
  Future<void> reproducir(String ruta) async {
    try {
      await _audioPlayer.play(DeviceFileSource(ruta));
    } catch (e) {
      debugPrint("Error al reproducir el archivo: $e");
    }
  }

// Pausa de la reproducción de audio
  Future<void> pausar() async {
    await _audioPlayer.pause();
  }

// Elimina la reproducción de audio
  Future<void> eliminar() async {
    await _audioPlayer.stop();
  }
}