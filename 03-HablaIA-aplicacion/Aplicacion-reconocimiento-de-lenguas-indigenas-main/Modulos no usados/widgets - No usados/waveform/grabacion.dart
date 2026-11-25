import 'dart:io';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class RecorderService {
  RecorderController controller = RecorderController();

  Future<bool> tienePermiso() async {
    return await controller.checkPermission();
  }

  Future<void> iniciar() async {
  final Directory temporal = await getTemporaryDirectory();
  String tiempo = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
  String ubicacion = p.join(temporal.path, "temp_audio_$tiempo.wav");
  print(ubicacion);
  controller.refresh();
  await controller.record(
    path: ubicacion,
    recorderSettings: const RecorderSettings(
      androidEncoderSettings: AndroidEncoderSettings(
        androidEncoder: AndroidEncoder.wav,
      ),
    ),
  );
}
  Future<String?> detener() async {
  if (controller.isRecording) {
    final path = await controller.stop(false);  
    await Future.delayed(const Duration(milliseconds: 300));
    controller.reset();
    return path;
  }
  return null;
}
  void liberar() {
    controller.dispose();
  }
}