import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hablaia/estructuras/modelo_configuracion_estructura.dart';
import 'package:hablaia/estructuras/modelos_disponibles_estructura.dart';
import 'package:hablaia/estructuras/resultado_clasificacion_estructura.dart';
import 'package:hablaia/estructuras/segmento_audio_estructura.dart';
import 'package:hablaia/servicios/modelo/tensores.dart';

/// WAV PCM 16 bits igual al que escribe ManejadorArchivos.kt.
Uint8List wav(List<int> muestras, {int sampleRate = 44100, int canales = 1}) {
  final datos = ByteData(44 + muestras.length * 2);
  void texto(int pos, String t) {
    for (int i = 0; i < 4; i++) {
      datos.setUint8(pos + i, t.codeUnitAt(i));
    }
  }

  texto(0, 'RIFF');
  datos.setUint32(4, 36 + muestras.length * 2, Endian.little);
  texto(8, 'WAVE');
  texto(12, 'fmt ');
  datos.setUint32(16, 16, Endian.little);
  datos.setUint16(20, 1, Endian.little);
  datos.setUint16(22, canales, Endian.little);
  datos.setUint32(24, sampleRate, Endian.little);
  datos.setUint32(28, sampleRate * 2 * canales, Endian.little);
  datos.setUint16(32, 2 * canales, Endian.little);
  datos.setUint16(34, 16, Endian.little);
  texto(36, 'data');
  datos.setUint32(40, muestras.length * 2, Endian.little);
  for (int i = 0; i < muestras.length; i++) {
    datos.setInt16(44 + i * 2, muestras[i], Endian.little);
  }
  return datos.buffer.asUint8List();
}

void main() {
  group('modelosDisponibles', () {
    test('hay exactamente un predeterminado y los ids no se repiten', () {
      final ids = modelosDisponibles.map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(modelosDisponibles.where((m) => m.predeterminado).length, 1);
    });

    test('cada modelo apunta a un .tflite que existe y su salida es válida', () {
      for (final m in modelosDisponibles) {
        expect(File(m.archivo).existsSync(), isTrue, reason: m.archivo);
        expect(() => m.salida.validar(m.id), returnsNormally);
      }
    });

    test('el modelo MobileNetV3 conserva los parámetros originales', () {
      final m = modelosDisponibles.firstWhere((m) => m.id == 'mobilenetv3_es_maya');
      expect(m.entrada.tipo, TipoEntrada.espectrograma);
      expect(m.entrada.normalizacion, Normalizacion.ceroUno);
      expect(m.entrada.espectrograma.aMapa(ancho: 224, alto: 224), {
        'sample_rate': 16000,
        'n_fft': 2048,
        'hop_length': 512,
        'n_mels': 128,
        'f_min': 0.0,
        'f_max': 8000.0,
        'db_min': -80.0,
        'mapa_color': 'inferno',
        'ancho': 224,
        'alto': 224,
      });
      expect(m.salida.tipo, TipoSalida.binaria);
      expect(m.salida.etiquetas, ['español', 'maya']);
    });
  });

  group('ConfiguracionEntrada / Salida', () {
    test('valores por defecto según el tipo', () {
      const audio = ConfiguracionEntrada.audio(muestras: 15600);
      expect(audio.tipo, TipoEntrada.audio);
      expect(audio.normalizacion, Normalizacion.menosUnoUno);
      expect(audio.sampleRate, 16000);

      const esp = ConfiguracionEntrada.espectrograma();
      expect(esp.normalizacion, Normalizacion.ceroUno);
      expect(esp.espectrograma.nMels, 128);
    });

    test('validar rechaza etiquetas inválidas', () {
      expect(
        () => const ConfiguracionSalida.binaria(etiquetas: ['a', 'b', 'c']).validar('x'),
        throwsStateError,
      );
      expect(
        () => const ConfiguracionSalida.multiclase(etiquetas: ['a']).validar('x'),
        throwsStateError,
      );
      expect(
        () => const ConfiguracionSalida.multiclase(etiquetas: ['a', 'b', 'c']).validar('x'),
        returnsNormally,
      );
    });
  });

  group('AudioPcm', () {
    test('lee WAV mono y remuestrea a 16 kHz', () {
      final pcm = AudioPcm.desdeWav(wav(List.filled(44100, 16384)));
      expect(pcm.sampleRate, 44100);
      expect(pcm.muestras.length, 44100);

      final r = pcm.remuestrear(16000);
      expect(r.length, closeTo(16000, 1));
      expect(r.every((v) => (v - 0.5).abs() < 1e-6), isTrue);
    });

    test('un fragmento grabado a 16 kHz llega al modelo sin conversión', () {
      final muestras = [for (int i = 0; i < 80000; i++) (i % 200) - 100];
      final pcm = AudioPcm.desdeWav(wav(muestras, sampleRate: 16000));
      expect(pcm.sampleRate, 16000);
      final r = pcm.remuestrear(16000);
      expect(r.length, 80000);
      for (final i in [0, 1, 150, 79999]) {
        expect(r[i], muestras[i] / 32768.0);
      }
    });

    test('promedia estéreo a mono', () {
      final pcm = AudioPcm.desdeWav(wav([1000, 3000, -2000, 0], canales: 2));
      expect(pcm.muestras, [2000, -1000]);
    });

    test('rechaza archivos que no son WAV', () {
      expect(() => AudioPcm.desdeWav(Uint8List(50)), throwsFormatException);
    });
  });

  group('salida', () {
    test('binaria: igual que el código anterior (p > 0.5 → etiqueta 1)', () {
      for (final (p, esperado) in [(0.8, 'maya'), (0.2, 'español'), (0.5, 'español')]) {
        final r = ResultadoClasificacion.desdeProbabilidades(
          {'español': 1 - p, 'maya': p},
          versionModelo: 'test@1',
        );
        expect(r.etiqueta, esperado);
        expect(r.confianza, closeTo((p > 0.5 ? p : 1 - p) * 100, 1e-9));
      }
    });

    test('softmax y sigmoide', () {
      final s = softmax([1.0, 2.0, 3.0]);
      expect(s.reduce((a, b) => a + b), closeTo(1, 1e-9));
      expect(s[2], greaterThan(s[1]));
      expect(sigmoide(0), 0.5);
    });
  });
}
