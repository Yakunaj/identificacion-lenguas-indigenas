package com.uuy

import android.content.Context
import android.graphics.Bitmap
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import java.io.ByteArrayOutputStream

// Servicio de grabación de audio que captura segmentos de audio, genera espectrogramas y los envía a Flutter.
class GrabadorAudio(
    private val context: Context,
    private val onBitmapSegment: (ByteArray) -> Unit,
) {
    private val SAMPLE_RATE = 44100
    private val SEGMENT_SEC = 5
    private val SAMPLES_SEG = SAMPLE_RATE * SEGMENT_SEC
    private val CHANNEL = AudioFormat.CHANNEL_IN_MONO
    private val ENCODING = AudioFormat.ENCODING_PCM_16BIT

    private val bufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL, ENCODING)
    private var grabar: AudioRecord? = null
    private var grabando = false
    private val manejadorArchivos = ManejadorArchivos(context, SAMPLE_RATE)
    private val GeneradorEspectograma = GeneradorEspectograma()

    // Inicia la grabación de audio, genera espectrogramas y los envía a Flutter.
    fun startRecording(): String {
        if (grabando) return ""
        grabando = true
        val rutaSesion = manejadorArchivos.iniciarNuevaSesion()

        grabar = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            SAMPLE_RATE, CHANNEL, ENCODING, bufferSize
        )
        grabar?.startRecording()

        Thread {
            val segmentBuffer = ShortArray(SAMPLES_SEG)
            var samplesAcumulados = 0
            var bloqueContador = 0
            val readBuffer = ShortArray(bufferSize)

            while (grabando) {
                val read = grabar?.read(readBuffer, 0, bufferSize) ?: 0
                if (read > 0) {
                    val espacio = SAMPLES_SEG - samplesAcumulados
                    val toCopy = minOf(read, espacio)
                    System.arraycopy(readBuffer, 0, segmentBuffer, samplesAcumulados, toCopy)
                    samplesAcumulados += toCopy

                    if (samplesAcumulados >= SAMPLES_SEG) {
                        bloqueContador++

                        val normalizedBuffer = normalizeAudio(segmentBuffer)
                        val bitmapOriginal = GeneradorEspectograma.genera(normalizedBuffer)

                        manejadorArchivos.guardarEspectrogramaEnDisco(bitmapOriginal, bloqueContador)
                        manejadorArchivos.guardarFragmentoAudioWav(normalizedBuffer, bloqueContador)

                        val stream = ByteArrayOutputStream()
                        bitmapOriginal.compress(Bitmap.CompressFormat.PNG, 100, stream)
                        onBitmapSegment(stream.toByteArray())

                        bitmapOriginal.recycle()

                        samplesAcumulados = 0
                    }
                }
            }
        }.start()

        return rutaSesion
    }

    // Normaliza el audio para que el valor máximo absoluto sea 32767 (16 bits).
    private fun normalizeAudio(samples: ShortArray): ShortArray {

        var maxAmp = 1

        for (s in samples) {
            val absVal = kotlin.math.abs(s.toInt())
            if (absVal > maxAmp) maxAmp = absVal
        }

        val scale = 32767f / maxAmp.toFloat()

        return ShortArray(samples.size) {
            (samples[it] * scale)
                .toInt()
                .coerceIn(-32768, 32767)
                .toShort()
        }
    }

    // Detiene la grabación de audio, libera recursos y devuelve la ruta del archivo de audio completo.
    fun stopRecording(): String? {
        grabando = false
        try {
            grabar?.stop()
            grabar?.release()
        } catch (e: Exception) {
            Log.e("GrabadorAudio", "Error al detener: ${e.message}")
        }
        grabar = null
        return manejadorArchivos.unirFragmentosEnAudioCompleto()?.absolutePath
    }
}