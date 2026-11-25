import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'dart:ui' as ui;

class VisualizadorAudio extends StatelessWidget {
  final RecorderController controller;

  const VisualizadorAudio({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AudioWaveforms(
      size: Size(MediaQuery.of(context).size.width/2, 100.0),
      recorderController: controller,
      enableGesture: true,
      shouldCalculateScrolledPosition: false,
      waveStyle: WaveStyle(
        gradient: ui.Gradient.linear(
      const Offset(0, 50),
      const Offset(300, 50),
      [Colors.blue, const Color.fromARGB(255, 39, 176, 98), const Color.fromARGB(255, 50, 233, 30)],
      [0.0, 0.5, 1.0],
      ),
        extendWaveform: true,
        spacing: 10.0,
        showMiddleLine: false,
        scaleFactor: 350.0,
        waveThickness: 8.0,
      ),
      
    );
  }
}
