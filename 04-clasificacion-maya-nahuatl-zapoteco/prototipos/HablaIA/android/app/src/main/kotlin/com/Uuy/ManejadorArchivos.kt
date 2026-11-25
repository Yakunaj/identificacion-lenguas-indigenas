package com.uuy

import android.content.Context
import android.graphics.Bitmap
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import java.io.ByteArrayOutputStream

// Clase para manejar la creación de carpetas y archivos de audio y espectrogramas.
class ManejadorArchivos(private val context: Context, sampleRate: Int) {
    private val sampleRateGlobal = sampleRate
    private var carpetaSesionActiva: File? = null

    // Crea la carpeta principal de la grabación
    fun iniciarNuevaSesion(): String {
        val nombreCarpeta = "Grabacion_${System.currentTimeMillis()}"
        carpetaSesionActiva = File(context.cacheDir, nombreCarpeta)
        if (carpetaSesionActiva?.exists() == false) {
            carpetaSesionActiva?.mkdirs()
        }
        return carpetaSesionActiva?.absolutePath ?: ""
    }

    // Guarda un espectrograma en disco como archivo PNG dentro de la carpeta de la sesión activa.
    fun guardarEspectrogramaEnDisco(bitmap: Bitmap, numeroBloque: Int) {
        val carpeta = carpetaSesionActiva ?: return
        val carpetaImagenes = File(carpeta, "espectrogramas")
        println("Guardando espectrograma en: ${carpetaImagenes.absolutePath}")
        if (!carpetaImagenes.exists()) carpetaImagenes.mkdirs()

        val archivoImagen = File(carpetaImagenes, "espectrograma_$numeroBloque.png")
        try {
            FileOutputStream(archivoImagen).use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                out.flush()
            }
        } catch (e: Exception) {
            Log.e("ManejadorArchivos", "Error al guardar espectrograma: ${e.message}")
        }
    }

    // Une todos los fragmentos de audio WAV en un solo archivo WAV completo.
    fun unirFragmentosEnAudioCompleto(): File? {
        val carpeta = carpetaSesionActiva ?: return null
        val carpetaFragmentos = File(carpeta, "fragmentos")
        if (!carpetaFragmentos.exists()) return null

        val fragmentos = carpetaFragmentos.listFiles()
            ?.filter { it.name.endsWith(".wav") }
            ?.sortedBy {
                it.nameWithoutExtension
                    .removePrefix("bloque_")
                    .toIntOrNull() ?: 0
            } ?: return null

        if (fragmentos.isEmpty()) return null

        val archivoCompleto = File(carpeta, "grabacion_completa.wav")

        try {
            var tamañoTotalPcm: Long = 0
            for (fragmento in fragmentos) {
                tamañoTotalPcm += (fragmento.length() - 44)
            }

            FileOutputStream(archivoCompleto).use { out ->
                out.write(createWavHeader(tamañoTotalPcm))
                val buffer = ByteArray(4096)
                for (fragmento in fragmentos) {
                    fragmento.inputStream().use { input ->
                        input.skip(44)
                        var bytesLeidos: Int
                        while (input.read(buffer).also { bytesLeidos = it } != -1) {
                            out.write(buffer, 0, bytesLeidos)
                        }
                    }
                }
                out.flush()
            }
        } catch (e: Exception) {
            Log.e("ManejadorArchivos", "Error al unir fragmentos: ${e.message}")
            return null
        }

        return archivoCompleto
    }

    // Guarda un fragmento de audio en disco como archivo WAV dentro de la carpeta de la sesión activa.
    fun guardarFragmentoAudioWav(segmentBuffer: ShortArray, numeroBloque: Int) {
        val carpeta = carpetaSesionActiva ?: return
        val carpetaAudios = File(carpeta, "fragmentos")
        if (!carpetaAudios.exists()) carpetaAudios.mkdirs()

        val archivoFragmento = File(carpetaAudios, "bloque_$numeroBloque.wav")
        try {
            FileOutputStream(archivoFragmento).use { out ->
                val pcmData = ByteArray(segmentBuffer.size * 2)
                for (i in segmentBuffer.indices) {
                    val value = segmentBuffer[i].toInt()
                    pcmData[i * 2] = (value and 0x00FF).toByte()
                    pcmData[i * 2 + 1] = ((value and 0xFF00) shr 8).toByte()
                }
                val header = createWavHeader(pcmData.size.toLong())
                out.write(header)
                out.write(pcmData)
            }
        } catch (e: Exception) {
            Log.e("ManejadorArchivos", "Error al guardar fragmento audio: ${e.message}")
        }
    }

    // Crea la cabecera WAV de 44 bytes para un archivo PCM dado el tamaño de los datos.
    private fun createWavHeader(pcmDataLength: Long): ByteArray {
        val totalDataLength = pcmDataLength + 36
        val header = ByteArray(44)
        val byteRate = (sampleRateGlobal * 2).toLong()

        header[0] = 'R'.code.toByte(); header[1] = 'I'.code.toByte(); header[2] = 'F'.code.toByte(); header[3] =
            'F'.code.toByte()
        header[4] = (totalDataLength and 0xff).toByte()
        header[5] = ((totalDataLength shr 8) and 0xff).toByte()
        header[6] = ((totalDataLength shr 16) and 0xff).toByte()
        header[7] = ((totalDataLength shr 24) and 0xff).toByte()
        header[8] = 'W'.code.toByte(); header[9] = 'A'.code.toByte(); header[10] = 'V'.code.toByte(); header[11] =
            'E'.code.toByte()
        header[12] = 'f'.code.toByte(); header[13] = 'm'.code.toByte(); header[14] =
            't'.code.toByte(); header[15] = ' '.code.toByte()
        header[16] = 16
        header[17] = 0; header[18] = 0; header[19] = 0
        header[20] = 1
        header[21] = 0
        header[22] = 1
        header[23] = 0
        header[24] = (sampleRateGlobal and 0xff).toByte()
        header[25] = ((sampleRateGlobal shr 8) and 0xff).toByte()
        header[26] = ((sampleRateGlobal shr 16) and 0xff).toByte()
        header[27] = ((sampleRateGlobal shr 24) and 0xff).toByte()
        header[28] = (byteRate and 0xff).toByte()
        header[29] = ((byteRate shr 8) and 0xff).toByte()
        header[30] = ((byteRate shr 16) and 0xff).toByte()
        header[31] = ((byteRate shr 24) and 0xff).toByte()
        header[32] = 2
        header[33] = 0
        header[34] = 16
        header[35] = 0
        header[36] = 'd'.code.toByte(); header[37] = 'a'.code.toByte(); header[38] =
            't'.code.toByte(); header[39] = 'a'.code.toByte()
        header[40] = (pcmDataLength and 0xff).toByte()
        header[41] = ((pcmDataLength shr 8) and 0xff).toByte()
        header[42] = ((pcmDataLength shr 16) and 0xff).toByte()
        header[43] = ((pcmDataLength shr 24) and 0xff).toByte()

        return header
    }
}