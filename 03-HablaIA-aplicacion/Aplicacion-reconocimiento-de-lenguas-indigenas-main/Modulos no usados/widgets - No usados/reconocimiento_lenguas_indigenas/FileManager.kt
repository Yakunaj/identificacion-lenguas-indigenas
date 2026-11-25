package com.Uuy
import android.content.Context
import android.graphics.Bitmap
import android.util.Log
import java.io.File
import java.io.FileOutputStream


class FileManager(private val context: Context, sampleRate: Int) {
    private val sampleRateGlobal = sampleRate
    private var carpetaSesionActiva: File? = null

    // Crea la carpeta principal de la sesión usando un TimeStamp único
    fun iniciarNuevaSesion(): String {
        val nombreCarpeta = "Grabacion_${System.currentTimeMillis()}"
        carpetaSesionActiva = File(context.cacheDir, nombreCarpeta)
        if (carpetaSesionActiva?.exists() == false) {
            carpetaSesionActiva?.mkdirs()
        }
        return carpetaSesionActiva?.absolutePath ?: ""
    }

    fun guardarEspectrogramaEnDisco(bitmap: Bitmap, numeroBloque: Int) {
        val carpeta = carpetaSesionActiva ?: return
        val carpetaImagenes = File(carpeta, "espectrogramas")
        if (!carpetaImagenes.exists()) carpetaImagenes.mkdirs()

        val archivoImagen = File(carpetaImagenes, "espectrograma_$numeroBloque.png")
        try {
            FileOutputStream(archivoImagen).use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                out.flush()
            }
        } catch (e: Exception) {
            Log.e("FileManager", "Error al guardar espectrograma: ${e.message}")
        }
    }

    fun guardarFragmentoAudioWav(segmentBuffer: ShortArray, numeroBloque: Int) {
        val carpeta = carpetaSesionActiva ?: return
        val carpetaAudios = File(carpeta, "fragmentos")
        if (!carpetaAudios.exists()) carpetaAudios.mkdirs()

        val archivoFragmento = File(carpetaAudios, "bloque_$numeroBloque.wav")
        try {
            FileOutputStream(archivoFragmento).use { out ->
                // Convertir ShortArray a bytes crudos PCM
                val pcmData = ByteArray(segmentBuffer.size * 2)
                for (i in segmentBuffer.indices) {
                    val value = segmentBuffer[i].toInt()
                    pcmData[i * 2] = (value and 0x00FF).toByte()
                    pcmData[i * 2 + 1] = ((value and 0xFF00) shr 8).toByte()
                }

                // Generar cabecera WAV de 44 bytes e inyectarla
                val header = createWavHeader(pcmData.size.toLong())
                out.write(header)
                out.write(pcmData)
            }
        } catch (e: Exception) {
            Log.e("FileManager", "Error al guardar fragmento audio: ${e.message}")
        }
    }

    private fun createWavHeader(pcmDataLength: Long): ByteArray {
        val totalDataLength = pcmDataLength + 36
        val header = ByteArray(44)
        val byteRate = (sampleRateGlobal * 2).toLong()

        header[0] = 'R'.toByte(); header[1] = 'I'.toByte(); header[2] = 'F'.toByte(); header[3] = 'F'.toByte()
        header[4] = (totalDataLength and 0xff).toByte()
        header[5] = ((totalDataLength shr 8) and 0xff).toByte()
        header[6] = ((totalDataLength shr 16) and 0xff).toByte()
        header[7] = ((totalDataLength shr 24) and 0xff).toByte()
        header[8] = 'W'.toByte(); header[9] = 'A'.toByte(); header[10] = 'V'.toByte(); header[11] = 'E'.toByte()
        header[12] = 'f'.toByte(); header[13] = 'm'.toByte(); header[14] = 't'.toByte(); header[15] = ' '.toByte()
        header[16] = 16
        header[17] = 0; header[18] = 0; header[19] = 0
        header[20] = 1 // PCM lineal
        header[21] = 0
        header[22] = 1 // Mono
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
        header[34] = 16 // 16 bits
        header[35] = 0
        header[36] = 'd'.toByte(); header[37] = 'a'.toByte(); header[38] = 't'.toByte(); header[39] = 'a'.toByte()
        header[40] = (pcmDataLength and 0xff).toByte()
        header[41] = ((pcmDataLength shr 8) and 0xff).toByte()
        header[42] = ((pcmDataLength shr 16) and 0xff).toByte()
        header[43] = ((pcmDataLength shr 24) and 0xff).toByte()

        return header
    }
}