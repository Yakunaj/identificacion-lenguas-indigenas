import java.awt.RenderingHints
import java.awt.image.BufferedImage
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import javax.imageio.ImageIO
import kotlin.math.*

object MelSpectrogramGenerator {

    const val SAMPLE_RATE = 16000
    const val N_FFT       = 2048
    const val HOP_LENGTH  = 512
    const val N_MEL       = 128
    const val F_MIN       = 0.0
    const val F_MAX       = 8000.0
    const val DB_MIN      = -80f
    const val OUTPUT_SIZE = 224

    // LUT Inferno (252 entradas)
    private val INFERNO_LUT = arrayOf(
        intArrayOf(0, 0, 3),    intArrayOf(0, 0, 4),    intArrayOf(0, 0, 6),    intArrayOf(1, 0, 7),
        intArrayOf(1, 1, 9),    intArrayOf(1, 1, 11),   intArrayOf(2, 1, 14),   intArrayOf(2, 2, 16),
        intArrayOf(3, 2, 18),   intArrayOf(4, 3, 20),   intArrayOf(4, 3, 22),   intArrayOf(5, 4, 24),
        intArrayOf(6, 4, 27),   intArrayOf(7, 5, 29),   intArrayOf(8, 6, 31),   intArrayOf(9, 6, 33),
        intArrayOf(10, 7, 35),  intArrayOf(11, 7, 38),  intArrayOf(13, 8, 40),  intArrayOf(14, 8, 42),
        intArrayOf(15, 9, 45),  intArrayOf(16, 9, 47),  intArrayOf(18, 10, 50), intArrayOf(19, 10, 52),
        intArrayOf(20, 11, 54), intArrayOf(22, 11, 57), intArrayOf(23, 11, 59), intArrayOf(25, 11, 62),
        intArrayOf(26, 11, 64), intArrayOf(28, 12, 67), intArrayOf(29, 12, 69), intArrayOf(31, 12, 71),
        intArrayOf(32, 12, 74), intArrayOf(34, 11, 76), intArrayOf(36, 11, 78), intArrayOf(38, 11, 80),
        intArrayOf(39, 11, 82), intArrayOf(41, 11, 84), intArrayOf(43, 10, 86), intArrayOf(45, 10, 88),
        intArrayOf(46, 10, 90), intArrayOf(48, 10, 92), intArrayOf(50, 9, 93),  intArrayOf(52, 9, 95),
        intArrayOf(53, 9, 96),  intArrayOf(55, 9, 97),  intArrayOf(57, 9, 98),  intArrayOf(59, 9, 100),
        intArrayOf(60, 9, 101), intArrayOf(62, 9, 102), intArrayOf(64, 9, 102), intArrayOf(65, 9, 103),
        intArrayOf(67, 10, 104),  intArrayOf(69, 10, 105),  intArrayOf(70, 10, 105),  intArrayOf(72, 11, 106),
        intArrayOf(74, 11, 106),  intArrayOf(75, 12, 107),  intArrayOf(77, 12, 107),  intArrayOf(79, 13, 108),
        intArrayOf(80, 13, 108),  intArrayOf(82, 14, 108),  intArrayOf(83, 14, 109),  intArrayOf(85, 15, 109),
        intArrayOf(87, 15, 109),  intArrayOf(88, 16, 109),  intArrayOf(90, 17, 109),  intArrayOf(91, 17, 110),
        intArrayOf(93, 18, 110),  intArrayOf(95, 18, 110),  intArrayOf(96, 19, 110),  intArrayOf(98, 20, 110),
        intArrayOf(99, 20, 110),  intArrayOf(101, 21, 110), intArrayOf(102, 21, 110), intArrayOf(104, 22, 110),
        intArrayOf(106, 23, 110), intArrayOf(107, 23, 110), intArrayOf(109, 24, 110), intArrayOf(110, 24, 110),
        intArrayOf(112, 25, 110), intArrayOf(114, 25, 109), intArrayOf(115, 26, 109), intArrayOf(117, 27, 109),
        intArrayOf(118, 27, 109), intArrayOf(120, 28, 109), intArrayOf(122, 28, 109), intArrayOf(123, 29, 108),
        intArrayOf(125, 29, 108), intArrayOf(126, 30, 108), intArrayOf(128, 31, 107), intArrayOf(129, 31, 107),
        intArrayOf(131, 32, 107), intArrayOf(133, 32, 106), intArrayOf(134, 33, 106), intArrayOf(136, 33, 106),
        intArrayOf(137, 34, 105), intArrayOf(139, 34, 105), intArrayOf(141, 35, 105), intArrayOf(142, 36, 104),
        intArrayOf(144, 36, 104), intArrayOf(145, 37, 103), intArrayOf(147, 37, 103), intArrayOf(149, 38, 102),
        intArrayOf(150, 38, 102), intArrayOf(152, 39, 101), intArrayOf(153, 40, 100), intArrayOf(155, 40, 100),
        intArrayOf(156, 41, 99),  intArrayOf(158, 41, 99),  intArrayOf(160, 42, 98),  intArrayOf(161, 43, 97),
        intArrayOf(163, 43, 97),  intArrayOf(164, 44, 96),  intArrayOf(166, 44, 95),  intArrayOf(167, 45, 95),
        intArrayOf(169, 46, 94),  intArrayOf(171, 46, 93),  intArrayOf(172, 47, 92),  intArrayOf(174, 48, 91),
        intArrayOf(175, 49, 91),  intArrayOf(177, 49, 90),  intArrayOf(178, 50, 89),  intArrayOf(180, 51, 88),
        intArrayOf(181, 51, 87),  intArrayOf(183, 52, 86),  intArrayOf(184, 53, 86),  intArrayOf(186, 54, 85),
        intArrayOf(187, 55, 84),  intArrayOf(189, 55, 83),  intArrayOf(190, 56, 82),  intArrayOf(191, 57, 81),
        intArrayOf(193, 58, 80),  intArrayOf(194, 59, 79),  intArrayOf(196, 60, 78),  intArrayOf(197, 61, 77),
        intArrayOf(199, 62, 76),  intArrayOf(200, 62, 75),  intArrayOf(201, 63, 74),  intArrayOf(203, 64, 73),
        intArrayOf(204, 65, 72),  intArrayOf(205, 66, 71),  intArrayOf(207, 68, 70),  intArrayOf(208, 69, 68),
        intArrayOf(209, 70, 67),  intArrayOf(210, 71, 66),  intArrayOf(212, 72, 65),  intArrayOf(213, 73, 64),
        intArrayOf(214, 74, 63),  intArrayOf(215, 75, 62),  intArrayOf(217, 77, 61),  intArrayOf(218, 78, 59),
        intArrayOf(219, 79, 58),  intArrayOf(220, 80, 57),  intArrayOf(221, 82, 56),  intArrayOf(222, 83, 55),
        intArrayOf(223, 84, 54),  intArrayOf(224, 86, 52),  intArrayOf(226, 87, 51),  intArrayOf(227, 88, 50),
        intArrayOf(228, 90, 49),  intArrayOf(229, 91, 48),  intArrayOf(230, 92, 46),  intArrayOf(230, 94, 45),
        intArrayOf(231, 95, 44),  intArrayOf(232, 97, 43),  intArrayOf(233, 98, 42),  intArrayOf(234, 100, 40),
        intArrayOf(235, 101, 39), intArrayOf(236, 103, 38), intArrayOf(237, 104, 37), intArrayOf(237, 106, 35),
        intArrayOf(238, 108, 34), intArrayOf(239, 109, 33), intArrayOf(240, 111, 31), intArrayOf(240, 112, 30),
        intArrayOf(241, 114, 29), intArrayOf(242, 116, 28), intArrayOf(242, 117, 26), intArrayOf(243, 119, 25),
        intArrayOf(243, 121, 24), intArrayOf(244, 122, 22), intArrayOf(245, 124, 21), intArrayOf(245, 126, 20),
        intArrayOf(246, 128, 18), intArrayOf(246, 129, 17), intArrayOf(247, 131, 16), intArrayOf(247, 133, 14),
        intArrayOf(248, 135, 13), intArrayOf(248, 136, 12), intArrayOf(248, 138, 11), intArrayOf(249, 140, 9),
        intArrayOf(249, 142, 8),  intArrayOf(249, 144, 8),  intArrayOf(250, 145, 7),  intArrayOf(250, 147, 6),
        intArrayOf(250, 149, 6),  intArrayOf(250, 151, 6),  intArrayOf(251, 153, 6),  intArrayOf(251, 155, 6),
        intArrayOf(251, 157, 6),  intArrayOf(251, 158, 7),  intArrayOf(251, 160, 7),  intArrayOf(251, 162, 8),
        intArrayOf(251, 164, 10), intArrayOf(251, 166, 11), intArrayOf(251, 168, 13), intArrayOf(251, 170, 14),
        intArrayOf(251, 172, 16), intArrayOf(251, 174, 18), intArrayOf(251, 176, 20), intArrayOf(251, 177, 22),
        intArrayOf(251, 179, 24), intArrayOf(251, 181, 26), intArrayOf(251, 183, 28), intArrayOf(251, 185, 30),
        intArrayOf(250, 187, 33), intArrayOf(250, 189, 35), intArrayOf(250, 191, 37), intArrayOf(250, 193, 40),
        intArrayOf(249, 195, 42), intArrayOf(249, 197, 44), intArrayOf(249, 199, 47), intArrayOf(248, 201, 49),
        intArrayOf(248, 203, 52), intArrayOf(248, 205, 55), intArrayOf(247, 207, 58), intArrayOf(247, 209, 60),
        intArrayOf(246, 211, 63), intArrayOf(246, 213, 66), intArrayOf(245, 215, 69), intArrayOf(245, 217, 72),
        intArrayOf(244, 219, 75), intArrayOf(244, 220, 79), intArrayOf(243, 222, 82), intArrayOf(243, 224, 86),
        intArrayOf(243, 226, 89), intArrayOf(242, 228, 93), intArrayOf(242, 230, 96), intArrayOf(241, 232, 100),
        intArrayOf(241, 233, 104), intArrayOf(241, 235, 108), intArrayOf(241, 237, 112), intArrayOf(241, 238, 116),
        intArrayOf(241, 240, 121), intArrayOf(241, 242, 125), intArrayOf(242, 243, 129), intArrayOf(242, 244, 133),
        intArrayOf(243, 246, 137), intArrayOf(244, 247, 141), intArrayOf(245, 248, 145), intArrayOf(246, 250, 149),
        intArrayOf(247, 251, 153), intArrayOf(249, 252, 157), intArrayOf(250, 253, 160), intArrayOf(252, 254, 164)
    )

    // Datos leídos del header WAV
    private data class WavHeader(
        val numCanales: Int,
        val sampleRate: Int,
        val bitsPorMuestra: Int,
        val audioFormat: Int,  // 1=PCM int, 3=IEEE float
        val dataOffset: Int    // offset real al chunk 'data'
    )

    // Busca el chunk 'data' dinámicamente (ignora chunks extras)
    private fun leerHeader(bytes: ByteArray): WavHeader {
        val buf = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)

        val audioFormat    = buf.getShort(20).toInt() and 0xFFFF
        val numCanales     = buf.getShort(22).toInt() and 0xFFFF
        val sampleRate     = buf.getInt(24)
        val bitsPorMuestra = buf.getShort(34).toInt() and 0xFFFF

        // Buscar el chunk 'data' a partir del byte 36
        var offset = 36
        while (offset + 8 <= bytes.size) {
            val tag  = String(bytes, offset, 4, Charsets.US_ASCII)
            val size = buf.getInt(offset + 4)
            offset += 8
            if (tag == "data") return WavHeader(numCanales, sampleRate, bitsPorMuestra, audioFormat, offset)
            offset += size
        }
        throw IllegalArgumentException("No se encontró el chunk 'data' en el archivo WAV")
    }

    // Resampleo lineal simple (para 44100→16000 u otras razones no enteras)
    private fun resamplear(samples: FloatArray, fromRate: Int, toRate: Int): FloatArray {
        if (fromRate == toRate) return samples
        val ratio      = fromRate.toDouble() / toRate
        val outSize    = (samples.size / ratio).toInt()
        return FloatArray(outSize) { i ->
            val pos   = i * ratio
            val idx   = pos.toInt().coerceIn(0, samples.size - 2)
            val frac  = (pos - idx).toFloat()
            samples[idx] * (1f - frac) + samples[idx + 1] * frac
        }
    }

    // 5. Leer WAV → FloatArray a 16000Hz
    fun cargarWav(rutaArchivo: String): FloatArray {
        val bytes  = File(rutaArchivo).readBytes()
        val header = leerHeader(bytes)
        val buf    = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)

        val pcmData = when (header.bitsPorMuestra) {
            16 -> {
                // PCM entero 16-bit
                val numMuestras = (bytes.size - header.dataOffset) / 2 / header.numCanales
                FloatArray(numMuestras) { i ->
                    val idx = header.dataOffset + i * 2 * header.numCanales
                    buf.getShort(idx) / 32768f
                }
            }
            32 -> when (header.audioFormat) {
                3 -> {
                    // IEEE 754 float 32-bit (formato 3)
                    val numMuestras = (bytes.size - header.dataOffset) / 4 / header.numCanales
                    FloatArray(numMuestras) { i ->
                        val idx = header.dataOffset + i * 4 * header.numCanales
                        buf.getFloat(idx).coerceIn(-1f, 1f)
                    }
                }
                1 -> {
                    // PCM entero 32-bit (formato 1)
                    val numMuestras = (bytes.size - header.dataOffset) / 4 / header.numCanales
                    FloatArray(numMuestras) { i ->
                        val idx = header.dataOffset + i * 4 * header.numCanales
                        buf.getInt(idx) / 2147483648f
                    }
                }
                else -> throw IllegalArgumentException(
                    "Formato WAV no soportado: audioFormat=${header.audioFormat}, bits=${header.bitsPorMuestra}"
                )
            }
            else -> throw IllegalArgumentException(
                "Bits por muestra no soportado: ${header.bitsPorMuestra}"
            )
        }

        return resamplear(pcmData, header.sampleRate, SAMPLE_RATE)
    }

    // 1. Ventana de Hann
    private fun hannWindow(size: Int) = FloatArray(size) { n ->
        (0.5 * (1.0 - cos(2.0 * PI * n / (size - 1)))).toFloat()
    }

    // 2. FFT in-place (Cooley-Tukey)
    private fun fft(real: FloatArray, imag: FloatArray) {
        val n = real.size
        var j = 0
        for (i in 1 until n) {
            var bit = n shr 1
            while (j and bit != 0) { j = j xor bit; bit = bit shr 1 }
            j = j xor bit
            if (i < j) {
                real[i] = real[j].also { real[j] = real[i] }
                imag[i] = imag[j].also { imag[j] = imag[i] }
            }
        }
        var len = 2
        while (len <= n) {
            val halfLen = len / 2
            val angStep = -2.0 * PI / len
            for (i in 0 until n step len) {
                var ang = 0.0
                for (k in 0 until halfLen) {
                    val wr = cos(ang).toFloat()
                    val wi = sin(ang).toFloat()
                    val tr = wr * real[i + k + halfLen] - wi * imag[i + k + halfLen]
                    val ti = wr * imag[i + k + halfLen] + wi * real[i + k + halfLen]
                    real[i + k + halfLen] = real[i + k] - tr
                    imag[i + k + halfLen] = imag[i + k] - ti
                    real[i + k] += tr
                    imag[i + k] += ti
                    ang += angStep
                }
            }
            len = len shl 1
        }
    }

    // 3. STFT → magnitudes [numBins x numFrames]
    private fun stft(samples: FloatArray): Array<FloatArray> {
        val window     = hannWindow(N_FFT)
        val numFrames  = (samples.size - N_FFT) / HOP_LENGTH + 1
        val numBins    = N_FFT / 2 + 1
        val magnitudes = Array(numBins) { FloatArray(numFrames) }
        val real = FloatArray(N_FFT)
        val imag = FloatArray(N_FFT)

        for (frame in 0 until numFrames) {
            val start = frame * HOP_LENGTH
            real.fill(0f); imag.fill(0f)
            for (k in 0 until N_FFT) {
                real[k] = if (start + k < samples.size) samples[start + k] * window[k] else 0f
            }
            fft(real, imag)
            for (bin in 0 until numBins) {
                magnitudes[bin][frame] = sqrt(real[bin].pow(2) + imag[bin].pow(2))
            }
        }
        return magnitudes
    }

    // 4. Banco de filtros Mel
    private fun hzToMel(hz: Double) = 2595.0 * log10(1.0 + hz / 700.0)
    private fun melToHz(mel: Double) = 700.0 * (10.0.pow(mel / 2595.0) - 1.0)

    private fun melFilterBank(numBins: Int): Array<FloatArray> {
        val melMin = hzToMel(F_MIN)
        val melMax = hzToMel(F_MAX)
        val melPoints = DoubleArray(N_MEL + 2) { i ->
            melToHz(melMin + i * (melMax - melMin) / (N_MEL + 1))
        }
        val fftBins = DoubleArray(N_MEL + 2) { i ->
            floor(melPoints[i] / (SAMPLE_RATE.toDouble() / N_FFT))
        }
        return Array(N_MEL) { m ->
            FloatArray(numBins) { k ->
                val kd = k.toDouble()
                val leftWidth  = fftBins[m+1] - fftBins[m]
                val rightWidth = fftBins[m+2] - fftBins[m+1]
                when {
                    kd < fftBins[m]    -> 0f
                    kd <= fftBins[m+1] -> if (leftWidth  > 0.0) ((kd - fftBins[m])   / leftWidth).toFloat()  else 1f
                    kd <= fftBins[m+2] -> if (rightWidth > 0.0) ((fftBins[m+2] - kd) / rightWidth).toFloat() else 1f
                    else               -> 0f
                }
            }
        }
    }

    // 6. Pipeline: samples → BufferedImage 224x224 con Inferno
    fun generarImagen(samples: FloatArray): BufferedImage {
        val magnitudes = stft(samples)
        val numBins    = magnitudes.size
        val numFrames  = magnitudes[0].size
        val filterBank = melFilterBank(numBins)
        val maxLutIdx  = INFERNO_LUT.size - 1

        val melDb = Array(N_MEL) { m ->
            FloatArray(numFrames) { frame ->
                var energia = 0f
                for (bin in 0 until numBins) energia += filterBank[m][bin] * magnitudes[bin][frame]
                20f * log10(energia.coerceAtLeast(1e-10f))
            }
        }

        // Máximo global para normalización
        val maxDb = melDb.maxOf { row -> row.max()!! }

        // Escalar todo el clip a 224x224 — el modelo aprende a ignorar silencios
        val imagen = BufferedImage(OUTPUT_SIZE, OUTPUT_SIZE, BufferedImage.TYPE_INT_RGB)
        for (py in 0 until OUTPUT_SIZE) {
            val m = ((OUTPUT_SIZE - 1 - py).toFloat() / OUTPUT_SIZE * N_MEL).toInt()
                .coerceIn(0, N_MEL - 1)
            for (px in 0 until OUTPUT_SIZE) {
                val frame = (px.toFloat() / OUTPUT_SIZE * numFrames).toInt()
                    .coerceIn(0, numFrames - 1)
                val norm = ((melDb[m][frame] - maxDb).coerceAtLeast(DB_MIN) - DB_MIN) / (-DB_MIN)
                val idx  = (norm * maxLutIdx).toInt().coerceIn(0, maxLutIdx)
                val c    = INFERNO_LUT[idx]
                imagen.setRGB(px, py, (c[0] shl 16) or (c[1] shl 8) or c[2])
            }
        }

        return imagen
    }

    // 7. Guardar como PNG
    fun guardarPNG(imagen: BufferedImage, carpeta: File, nombre: String) {
        carpeta.mkdirs()
        ImageIO.write(imagen, "PNG", File(carpeta, "$nombre.png"))
    }

    // 8. Todo-en-uno
    fun procesarWav(rutaWav: String, carpetaSalida: File, nombreSalida: String) {
        val samples = cargarWav(rutaWav)
        val imagen  = generarImagen(samples)
        guardarPNG(imagen, carpetaSalida, nombreSalida)
    }
}