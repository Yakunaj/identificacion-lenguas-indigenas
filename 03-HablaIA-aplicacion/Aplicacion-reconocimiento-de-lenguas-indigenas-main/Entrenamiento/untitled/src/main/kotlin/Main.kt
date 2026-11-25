import java.io.File

/**
 * Genera espectrogramas PNG desde una carpeta de archivos .wav
 *
 * Estructura esperada (MODO_SUBCARPETAS = true):
 *   CARPETA_ENTRADA/
 *     ├── maya/
 *     │     ├── clip_001.wav
 *     │     └── clip_002.wav
 *     └── español/
 *           ├── clip_001.wav
 *           └── clip_002.wav
 *
 * Estructura de salida generada:
 *   CARPETA_SALIDA/
 *     ├── maya/
 *     │     ├── clip_001.png
 *     │     └── clip_002.png
 *     └── español/
 *           ├── clip_001.png
 *           └── clip_002.png
 *
 * Si todos los .wav están en una sola carpeta sin subcarpetas,
 * cambia MODO_SUBCARPETAS a false.
 */

// Configuración, las rutas son relativas a la carpeta untitled, que es desde donde IntelliJ ejecuta el proyecto
// Entrada, los clips a 16 kHz mono que deja hacer16000.py en Entrenamiento/entrenamiento
const val CARPETA_ENTRADA  = "../entrenamiento"
// Salida, los PNG que lee entrenador.py desde Entrenamiento/espectrogramas
const val CARPETA_SALIDA   = "../espectrogramas"
const val MODO_SUBCARPETAS = true

fun main() {
    val carpetaEntrada = File(CARPETA_ENTRADA).canonicalFile
    val carpetaSalida  = File(CARPETA_SALIDA).canonicalFile

    require(carpetaEntrada.exists() && carpetaEntrada.isDirectory) {
        "La carpeta de entrada no existe: ${carpetaEntrada.path}"
    }
    println("📂 Entrada    : ${carpetaEntrada.path}")

    var procesados = 0
    var errores    = 0

    if (MODO_SUBCARPETAS) {
        val subcarpetas = carpetaEntrada.listFiles { f -> f.isDirectory } ?: emptyArray()

        if (subcarpetas.isEmpty()) {
            println("⚠️  No se encontraron subcarpetas en ${carpetaEntrada.path}")
            println("   Cambia MODO_SUBCARPETAS a false si tus .wav están en la raíz")
            return
        }

        for (subcarpeta in subcarpetas.sortedBy { it.name }) {
            val carpetaClaseSalida = File(carpetaSalida, subcarpeta.name)
            val wavFiles = subcarpeta.listFiles { f ->
                f.isFile && f.extension.lowercase() == "wav"
            }?.sortedBy { it.name } ?: emptyList()

            println("\n📁 Clase: ${subcarpeta.name} — ${wavFiles.size} archivos")

            for (wav in wavFiles) {
                val ok = procesarArchivo(wav, carpetaClaseSalida)
                if (ok) procesados++ else errores++
            }
        }

    } else {
        val wavFiles = carpetaEntrada.listFiles { f ->
            f.isFile && f.extension.lowercase() == "wav"
        }?.sortedBy { it.name } ?: emptyList()

        println("\n📁 Carpeta plana — ${wavFiles.size} archivos")

        for (wav in wavFiles) {
            val ok = procesarArchivo(wav, carpetaSalida)
            if (ok) procesados++ else errores++
        }
    }

    println("\n─────────────────────────────────────")
    println("✅ Procesados : $procesados")
    if (errores > 0) println("❌ Errores    : $errores")
    println("📂 Salida     : ${carpetaSalida.path}")
    println("─────────────────────────────────────")
}

fun procesarArchivo(wav: File, carpetaSalida: File): Boolean {
    return try {
        MelSpectrogramGenerator.procesarWav(
            rutaWav       = wav.absolutePath,
            carpetaSalida = carpetaSalida,
            nombreSalida  = wav.nameWithoutExtension
        )
        println("  ✔ ${wav.name}")
        true
    } catch (e: IllegalArgumentException) {
        println("  ✘ ${wav.name} — formato inválido: ${e.message}")
        false
    } catch (e: Exception) {
        println("  ✘ ${wav.name} — error: ${e.message}")
        false
    }
}