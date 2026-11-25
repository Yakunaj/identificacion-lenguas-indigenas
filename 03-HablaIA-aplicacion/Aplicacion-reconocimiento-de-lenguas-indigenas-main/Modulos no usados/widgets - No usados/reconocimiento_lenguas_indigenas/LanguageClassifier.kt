package com.Uuy

import android.content.Context
import android.content.res.AssetFileDescriptor
import android.graphics.Bitmap
import android.util.Log
import com.google.ai.edge.litert.Interpreter
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel

data class PredictionResult(val className: String, val confidence: Float)

class LanguageClassifier(context: Context) {

    private var interpreter: Interpreter? = null
    private val labels = listOf("Espanol", "Maya")

    init {
        try {
            val modelBuffer = loadModelFile(context, "MobileNetV3Large_normal.tflite")
            val options = Interpreter.Options().apply {
                numThreads = 4
            }
            interpreter = Interpreter(modelBuffer, options)
            Log.d("LanguageClassifier", "Modelo cargado exitosamente.")
        } catch (e: Exception) {
            Log.e("LanguageClassifier", "Error al cargar modelo: ${e.message}")
        }
    }

    private fun loadModelFile(context: Context, modelName: String): ByteBuffer {
        val fileDescriptor: AssetFileDescriptor = context.assets.openFd(modelName)
        val inputStream = FileInputStream(fileDescriptor.fileDescriptor)
        val fileChannel: FileChannel = inputStream.channel
        return fileChannel.map(
            FileChannel.MapMode.READ_ONLY,
            fileDescriptor.startOffset,
            fileDescriptor.declaredLength
        )
    }

    fun generateSpectrogram(audioSamples: ShortArray): Bitmap {
        return Bitmap.createBitmap(224, 224, Bitmap.Config.ARGB_8888)
    }

    fun classify(bitmap: Bitmap): PredictionResult {
        if (interpreter == null) return PredictionResult("Error", 0.0f)

        val inputSize = 224
        val byteBuffer = ByteBuffer.allocateDirect(1 * inputSize * inputSize * 3 * 4).apply {
            order(ByteOrder.nativeOrder())
        }

        val resizedBitmap = Bitmap.createScaledBitmap(bitmap, inputSize, inputSize, true)
        val intValues = IntArray(inputSize * inputSize)
        resizedBitmap.getPixels(intValues, 0, resizedBitmap.width, 0, 0, resizedBitmap.width, resizedBitmap.height)

        byteBuffer.rewind()
        for (pixelValue in intValues) {
            val r = (((pixelValue shr 16) and 0xFF) / 127.5f) - 1.0f
            val g = (((pixelValue shr 8)  and 0xFF) / 127.5f) - 1.0f
            val b = ((pixelValue           and 0xFF) / 127.5f) - 1.0f
            byteBuffer.putFloat(r)
            byteBuffer.putFloat(g)
            byteBuffer.putFloat(b)
        }

        val output = Array(1) { FloatArray(labels.size) }
        interpreter?.run(byteBuffer, output)

        val scores = output[0]
        var maxIdx = 0
        var maxConf = scores[0]
        for (i in scores.indices) {
            if (scores[i] > maxConf) {
                maxConf = scores[i]
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
