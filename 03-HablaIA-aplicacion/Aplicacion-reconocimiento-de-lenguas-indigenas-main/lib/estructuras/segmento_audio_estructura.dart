import 'dart:io';
import 'dart:typed_data';

/// Un fragmento de audio grabado (por defecto 5 s) guardado como WAV.
///
/// Es la unidad que se clasifica: cada modelo deriva de aquí su propia
/// entrada (espectrograma, audio crudo, ...), tanto en vivo como al
/// re-analizar grabaciones guardadas.
class SegmentoAudio {
  final int numero;
  final String rutaWav;

  AudioPcm? _pcm;

  SegmentoAudio({required this.numero, required this.rutaWav});

  /// Lee (y guarda en caché) las muestras PCM del WAV.
  Future<AudioPcm> leerPcm() async =>
      _pcm ??= AudioPcm.desdeWav(await File(rutaWav).readAsBytes());
}

/// Audio PCM mono de 16 bits.
class AudioPcm {
  final Int16List muestras;
  final int sampleRate;

  const AudioPcm(this.muestras, this.sampleRate);

  /// Lee un WAV PCM de 16 bits. Si es estéreo se promedia a mono.
  factory AudioPcm.desdeWav(Uint8List bytes) {
    final datos = ByteData.sublistView(bytes);
    String id(int pos) => String.fromCharCodes(bytes, pos, pos + 4);

    if (bytes.length < 12 || id(0) != 'RIFF' || id(8) != 'WAVE') {
      throw const FormatException('No es un archivo WAV válido');
    }

    int canales = 1;
    int sampleRate = 0;
    int bits = 16;
    int pos = 12;

    while (pos + 8 <= bytes.length) {
      final tam = datos.getUint32(pos + 4, Endian.little);
      final inicio = pos + 8;

      if (id(pos) == 'fmt ') {
        canales = datos.getUint16(inicio + 2, Endian.little);
        sampleRate = datos.getUint32(inicio + 4, Endian.little);
        bits = datos.getUint16(inicio + 14, Endian.little);
      } else if (id(pos) == 'data') {
        if (bits != 16) {
          throw FormatException('Solo se soporta WAV de 16 bits (recibido $bits)');
        }
        final fin = (inicio + tam).clamp(0, bytes.length);
        final total = (fin - inicio) ~/ 2 ~/ canales;
        final muestras = Int16List(total);
        for (int i = 0; i < total; i++) {
          int suma = 0;
          for (int c = 0; c < canales; c++) {
            suma += datos.getInt16(inicio + (i * canales + c) * 2, Endian.little);
          }
          muestras[i] = suma ~/ canales;
        }
        return AudioPcm(muestras, sampleRate);
      }

      pos = inicio + tam + (tam & 1);
    }

    throw const FormatException('El WAV no contiene datos de audio');
  }

  /// Muestras en flotante (-1..1) remuestreadas a [destino] Hz con
  /// interpolación lineal (igual que el generador nativo de espectrogramas).
  Float32List remuestrear(int destino) {
    final n = muestras.length;
    if (destino == sampleRate || n < 2) {
      return Float32List.fromList([for (final m in muestras) m / 32768.0]);
    }
    final ratio = sampleRate / destino;
    final salida = Float32List((n / ratio).floor());
    for (int i = 0; i < salida.length; i++) {
      final pos = i * ratio;
      final idx = pos.floor().clamp(0, n - 2);
      final frac = pos - idx;
      salida[i] =
          (muestras[idx] * (1 - frac) + muestras[idx + 1] * frac) / 32768.0;
    }
    return salida;
  }
}
