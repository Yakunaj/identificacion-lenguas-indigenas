import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../servicios/grabacion.dart'; // Tu clase Grabacion que acabas de mostrar
import '../servicios/uso_modelo.dart';
import '../widgets/btn_grabacion.dart';
import 'package:permission_handler/permission_handler.dart';

class ColorPagina extends StatefulWidget {
  const ColorPagina({super.key});

  @override
  State<ColorPagina> createState() => _ColorPaginaState();
}

class _ColorPaginaState extends State<ColorPagina> {
  // Servicios nativos y de IA
  final Grabacion _grabacionService = Grabacion();
  final UsoModelo _interpreter = UsoModelo();

  // Suscripción al flujo de bytes de Kotlin
  StreamSubscription? _subscription;


  // Variables de Estado de la UI
  bool grabando = false;
  String mensaje = 'Graba un audio para identificar la lengua';
  String resultadoIdioma = 'Esperando grabacion';
  double confianza = 0.0;

  final Color fondo = const Color.fromARGB(255, 214, 255, 181);

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  // Carga inicial del modelo clasificador
  Future<void> _loadModel() async {
    try {
      await _interpreter.cargarModelo();
      debugPrint("Modelo clasificador cargado correctamente");
    } catch (e) {
      debugPrint("Error cargando modelo: $e");
    }
  }

  // Escucha activa de los espectrogramas que manda Kotlin
  void _iniciarEscuchaStream() {
    _subscription = _grabacionService.results.listen((data) async {
      try {
        Uint8List imageBytes;

        // 1. Validamos la estructura del Map proveniente de MainActivity.kt
        if (data is Map) {
          // Extraemos los bytes directamente usando la llave exacta creada en Kotlin
          final rawBytes = data['bytes'];

          if (rawBytes == null) {
            throw Exception("El mapa nativo no contiene la llave 'bytes'");
          }

          imageBytes = Uint8List.fromList(List<int>.from(rawBytes));
        } else {
          // Fallback por si en un futuro decides mandar la lista directa sin mapa
          imageBytes = Uint8List.fromList(List<int>.from(data));
        }

        // 2. Clasificación directa usando los bytes del espectrograma (PNG)
        final resultado = await _interpreter.clasificar(imageBytes);


        setState(() {
          resultadoIdioma = resultado["className"] ?? "Desconocido";
          double confRaw = (resultado["confidence"] ?? 0.0) as double;
          confianza = confRaw <= 1.0 ? confRaw : confRaw;

          mensaje = 'Analizando flujo de audio activo...';
        });
      } catch (e) {
        print("ERROR CLASIFICANDO FRAGMENTO NATIVO: $e");
      }
    });
  }

  // Cancelar la escucha para no dejar procesos colgados en memoria
  void _detenerEscuchaStream() {
    _subscription?.cancel();
    _subscription = null;
  }

  // Gestión de los estados del botón flotante sincronizado con Kotlin
  Future<void> _gestionarGrabacion() async {
    if (grabando) {
      // Si ya está grabando, detenemos de manera normal
      await _grabacionService.detener();
      _detenerEscuchaStream();

      setState(() {
        grabando = false;
        mensaje = 'Análisis finalizado y guardado';
      });
    } else {
      // 1. Verificamos el estado del permiso del micrófono
      var status = await Permission.microphone.status;

      // 2. Si el usuario no lo ha aceptado o es la primera vez, se lo pedimos
      if (status.isDenied) {
        status = await Permission.microphone.request();
      }

      // 3. Si el permiso está otorgado, procedemos a encender el hardware nativo
      if (status.isGranted) {
        final String? idSession = await _grabacionService.iniciar();

        if (idSession != null) {

          _iniciarEscuchaStream();

          setState(() {
            grabando = true;
            mensaje = 'Escuchando entorno...';
            confianza = 0.0;
          });
        } else {
          setState(() {
            mensaje = 'Error al inicializar el hardware del micrófono';
          });
        }
      } else {
        // 4. Si el usuario rechaza el cuadro de diálogo, le avisamos por qué no avanza
        setState(() {
          mensaje = 'No se puede grabar sin acceso al micrófono';
        });

        // Opcional: Un snackbar rápido para que sea más visual
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Acepta el permiso del micrófono en los ajustes para usar la app.",
            ),
          ),
        );
      }
    }
  }

  // Modal inferior idéntico al de tu primer diseño


  @override
  void dispose() {
    _detenerEscuchaStream();
    _grabacionService.liberar();
    _interpreter.cerrar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        title: const Text(
          "Uuy",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 32.0,),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Remplazo de Waveform: Un contenedor dinámico de estado
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: grabando ? Color.fromARGB(255, 181, 255, 187) : Color.fromARGB(255, 235, 255, 198)
,
                borderRadius: BorderRadius.circular(24),
                boxShadow: grabando
                    ? [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              width: MediaQuery.of(context).size.width * 0.85,
              child: Column(
                children: [
                  Text(
                    resultadoIdioma.toUpperCase(),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: grabando ? const Color.fromARGB(255, 0, 0, 0) : const Color.fromARGB(137, 0, 0, 0),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "${confianza.toStringAsFixed(1)} % Confianza",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
            ),

            // Espacio inferior para empujar el panel hacia arriba del FAB
            const SizedBox(height: 80),
          ],
        ),
      ),
      // Tu botón estilizado original con callbacks actualizados
      floatingActionButton: ControlesGrabacion(
        grabando: grabando,
        onToggle: _gestionarGrabacion,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
