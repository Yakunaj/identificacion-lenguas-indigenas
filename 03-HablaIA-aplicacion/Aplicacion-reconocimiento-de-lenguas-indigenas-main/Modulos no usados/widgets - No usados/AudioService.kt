package com.Uuy

import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log

class AudioRecorderService(
    private val context: Context,
    private val onResultCallback: (String, Float) -> Unit // Envía datos a MainActivity
) {
    private val SAMPLE_RATE = 22050
    private val SEGMENT_SEC = 5
    private val SAMPLES_SEG = SAMPLE_RATE * SEGMENT_SEC
    private val CHANNEL     = AudioFormat.CHANNEL_IN_MONO
    private val ENCODING    = AudioFormat.ENCODING_PCM_16BIT

    private val bufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL, ENCODING)
    private var audioRecord: AudioRecord? = null
    private var isRecording = false

    // Instanciamos el manejador de archivos pasándole el SampleRate
    private val fileManager = FileManager(context, SAMPLE_RATE)

    fun startRecording(): String {
        isRecording = true
        
        // Iniciamos una nueva sesión en disco y capturamos la ruta base
        val rutaSesion = fileManager.iniciarNuevaSesion()

        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            SAMPLE_RATE, CHANNEL, ENCODING, bufferSize
        )
        audioRecord?.startRecording()

        Thread {
            val segmentBuffer = ShortArray(SAMPLES_SEG)
            var samplesAcumulados = 0
            var bloqueContador = 0
            val readBuffer = ShortArray(bufferSize)

            while (isRecording) {
                val read = audioRecord?.read(readBuffer, 0, bufferSize) ?: 0

                if (read > 0) {
                    val espacio = SAMPLES_SEG - samplesAcumulados
                    val toCopy  = minOf(read, espacio)

                    System.arraycopy(readBuffer, 0, segmentBuffer, samplesAcumulados, toCopy)
                    samplesAcumulados += toCopy

                    if (samplesAcumulados >= SAMPLES_SEG) {
                        bloqueContador++

                        // 1. Lógica de IA: Generar espectrograma y clasificarlo
                        val bitmap = classifier.generateSpectrogram(segmentBuffer)
                        val prediction = classifier.classify(bitmap)

                        // 2. Lógica de Persistencia: Escribir imágenes y audios a sus carpetas
                        fileManager.guardarEspectrogramaEnDisco(bitmap, bloqueContador)
                        fileManager.guardarFragmentoAudioWav(segmentBuffer, bloqueContador)

                        // 3. Comunicación: Detonamos el callback hacia la interfaz
                        onResultCallback(prediction.className, prediction.confidence)

                        samplesAcumulados = 0
                    }
                }
            }
        }.start()

        return rutaSesion // Regresa el nombre o ruta de la carpeta para que Flutter lo use como ID
    }

    fun stopRecording() {
        isRecording = false
        try {
            audioRecord?.stop()
            audioRecord?.release()
        } catch (e: Exception) {
            Log.e("AudioRecorderService", "Error al detener hardware: ${e.message}")
        }
        audioRecord = null
    }
}