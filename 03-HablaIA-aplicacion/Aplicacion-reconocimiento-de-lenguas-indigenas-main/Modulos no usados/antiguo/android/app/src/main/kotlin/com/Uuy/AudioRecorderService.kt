package com.Uuy

import android.content.Context
import android.graphics.Bitmap
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import java.io.ByteArrayOutputStream

class AudioRecorderService(
    private val context: Context,
    private val onBitmapSegment: (ByteArray) -> Unit,
) {
    private val SAMPLE_RATE  = 44100
    private val SEGMENT_SEC  = 5
    private val SAMPLES_SEG  = SAMPLE_RATE * SEGMENT_SEC
    private val CHANNEL      = AudioFormat.CHANNEL_IN_MONO
    private val ENCODING     = AudioFormat.ENCODING_PCM_16BIT

    private val bufferSize   = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL, ENCODING)
    private var audioRecord: AudioRecord? = null
    private var isRecording  = false
    private val fileManager  = FileManager(context, SAMPLE_RATE)
    private val spectrogramGenerator = SpectrogramGenerator()

    fun startRecording(): String {
        if (isRecording) return ""
        isRecording = true
        val rutaSesion = fileManager.iniciarNuevaSesion()

        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            SAMPLE_RATE, CHANNEL, ENCODING, bufferSize
        )
        audioRecord?.startRecording()

        Thread {
            val segmentBuffer     = ShortArray(SAMPLES_SEG)
            var samplesAcumulados = 0
            var bloqueContador    = 0
            val readBuffer        = ShortArray(bufferSize)

            while (isRecording) {
                val read = audioRecord?.read(readBuffer, 0, bufferSize) ?: 0
                if (read > 0) {
                    val espacio = SAMPLES_SEG - samplesAcumulados
                    val toCopy  = minOf(read, espacio)
                    System.arraycopy(readBuffer, 0, segmentBuffer, samplesAcumulados, toCopy)
                    samplesAcumulados += toCopy

                    if (samplesAcumulados >= SAMPLES_SEG) {
                        bloqueContador++

                        // ── Generar espectrograma 800×400 ─────────────────
                        val normalizedBuffer = normalizeAudio(segmentBuffer)
                        val bitmapOriginal = spectrogramGenerator.generate(normalizedBuffer )

                        // ── Guardar en disco el original 800×400 ──────────
                        fileManager.guardarEspectrogramaEnDisco(bitmapOriginal, bloqueContador)
                        fileManager.guardarFragmentoAudioWav(normalizedBuffer , bloqueContador)

                      
                        // ── Comprimir y mandar a Flutter ──────────────────
                        val stream = ByteArrayOutputStream()
                        bitmapOriginal.compress(Bitmap.CompressFormat.PNG, 100, stream)
                        onBitmapSegment(stream.toByteArray())

                        // ── Liberar memoria ───────────────────────────────
                        bitmapOriginal.recycle()

                        samplesAcumulados = 0
                    }
                }
            }
        }.start()

        return rutaSesion
    }

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

    fun stopRecording(): String? {
        isRecording = false
        try {
            audioRecord?.stop()
            audioRecord?.release()
        } catch (e: Exception) {
            Log.e("AudioRecorderService", "Error al detener: ${e.message}")
        }
        audioRecord = null
        return fileManager.unirFragmentosEnAudioCompleto()?.absolutePath
    }
}