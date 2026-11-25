package com.Uuy
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val METHOD_CHANNEL = "com.Uuy/language"
    private val EVENT_CHANNEL  = "com.Uuy/stream"

    private var classifier: LanguageClassifier? = null
    private var recorderService: AudioRecorderService? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Inicializamos el clasificador de TFLite una sola vez al arrancar la app
        classifier = LanguageClassifier(applicationContext)

        // 1. Configuración de EventChannel (Para enviar ráfagas de 5 segundos en tiempo real)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sinks: EventChannel.EventSink?) {
                    eventSink = sinks
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )

        // 2. Configuración de MethodChannel (Para los comandos Imperativos Start/Stop)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    try {
                        // Creamos el servicio pasándole el clasificador y una función lambda para el Stream
                        recorderService = AudioRecorderService(applicationContext, classifier!!) { idioma, confianza ->
                            // Este bloque corre cada que se completan 5 segundos
                            runOnUiThread {
                                val mapaResultados = mapOf("className" to idioma, "confidence" to confianza)
                                eventSink?.success(mapaResultados) // Viaja directo al stream.listen de Flutter
                            }
                        }

                        // Arrancamos y nos devuelve el nombre único de la carpeta (ID)
                        val idGrabacion = recorderService?.startRecording()
                        result.success(idGrabacion) // Le devolvemos el ID del audio a Flutter de inmediato
                    } catch (e: Exception) {
                        result.error("ERR_START", e.message, null)
                    }
                }
                "stop" -> {
                    recorderService?.stopRecording()
                    recorderService = null
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        recorderService?.stopRecording()
        classifier?.close()
        super.onDestroy()
    }
}