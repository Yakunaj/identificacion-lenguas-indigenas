package com.Uuy

import android.content.Context
import android.content.res.AssetFileDescriptor
import android.graphics.Bitmap
import android.util.Log
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel

data class PredictionResult(val className: String, val confidence: Float)

class LanguageClassifier(context: Context) {
    
    // 1. Declaramos el intérprete de TensorFlow Lite
    private var interpreter: Interpreter? = null
    
    // Define las etiquetas de tu modelo en el mismo orden en que fue entrenado
    private val labels = listOf("Español", "Maya") 

    init {
        try {
            // 2. Cargamos el archivo .tflite desde los assets e inicializamos el intérprete
            val modelBuffer = loadModelFile(context, "lib/modelos/MobileNetV3Large_normal.tflite")
            val options = Interpreter.Options().apply {
                setNumThreads(4) // Usa 4 núcleos del procesador para que sea rápido
            }
            interpreter = Interpreter(modelBuffer, options)
            Log.d("LanguageClassifier", "Modelo TFLite cargado exitosamente.")
        } catch (e: Exception) {
            Log.e("LanguageClassifier", "Error al cargar el modelo TFLite: ${e.message}")
        }
    }

    // Función auxiliar para leer el archivo binario desde la carpeta assets
    private fun loadModelFile(context: Context, modelName: String): ByteBuffer {
        val fileDescriptor: AssetFileDescriptor = context.assets.openFd(modelName)
        val inputStream = FileInputStream(fileDescriptor.fileDescriptor)
        val fileChannel: FileChannel = inputStream.channel
        val startOffset = fileDescriptor.startOffset
        val declaredLength = fileDescriptor.declaredLength
        return fileChannel.map(FileChannel.MapMode.READ_ONLY, startOffset, declaredLength)
    }

    fun generateSpectrogram(audioSamples: ShortArray): Bitmap {
        return Bitmap.createBitmap(224, 224, Bitmap.Config.ARGB_8888)
    }

    fun classify(bitmap: Bitmap): PredictionResult {
        if (interpreter == null) {
            return PredictionResult("Error", 0.0f)
        }

        val inputSize = 224
        val byteBuffer = ByteBuffer.allocateDirect(1 * inputSize * inputSize * 3 * 4).apply {
            order(ByteOrder.nativeOrder())
        }

        // Redimensionar el bitmap por seguridad al tamaño de entrada del modelo
        val resizedBitmap = Bitmap.createScaledBitmap(bitmap, inputSize, inputSize, true)
        val intValues = IntArray(inputSize * inputSize)
        resizedBitmap.getPixels(intValues, 0, resizedBitmap.width, 0, 0, resizedBitmap.width, resizedBitmap.height)

        byteBuffer.rewind()
        for (pixelValue in intValues) {
            val r = ((pixelValue shr 16) and 0xFF) / 255.0f
            val g = ((pixelValue shr 8) and 0xFF) / 255.0f
            val b = (pixelValue and 0xFF) / 255.0f
            
            byteBuffer.putFloat(r)
            byteBuffer.putFloat(g)
            byteBuffer.putFloat(b)
        }

        val outputOutputs = Array(1) { FloatArray(labels.size) }

        // 5. Correr la inferencia de la Red Neuronal
        interpreter?.run(byteBuffer, outputOutputs)

        // 6. Post-procesamiento: Encontrar cuál clase tiene el porcentaje más alto
        val confianzas = outputOutputs[0]
        var maxIdx = 0
        var maxConf = confianzas[0]
        for (i in confianzas.indices) {
            if (confianzas[i] > maxConf) {
                maxConf = confianzas[i]
                maxIdx = i
            }
        }

        return PredictionResult(labels[maxIdx], maxConf)
    }

    fun close() {
        interpreter?.close()
        interpreter = null
    }
}