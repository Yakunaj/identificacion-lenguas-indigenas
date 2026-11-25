import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../servicios/grabacion_servicio.dart';
import '../servicios/modelo_servicio.dart';
import '../widgets/boton_grabacion_widget.dart';
import 'package:permission_handler/permission_handler.dart';

// Página principal de la aplicación, que permite grabar audio y clasificarlo en tiempo real usando el modelo.
class PrincipalPagina extends StatefulWidget {
  const PrincipalPagina({super.key});

  @override
  State<PrincipalPagina> createState() => _PrincipalPaginaState();
}

// Estado del widget PrincipalPagina, que maneja la lógica de grabación y clasificación de audio.
class _PrincipalPaginaState extends State<PrincipalPagina> {
  final Grabacion _grabacionService = Grabacion();
  final UsoModelo _interpreter = UsoModelo();
  StreamSubscription? _subscription;
  bool grabando = false;
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
        if (data is Map) {
          final rawBytes = data['bytes'];
          if (rawBytes == null) {
            throw Exception("El mapa nativo no contiene la llave 'bytes'");
          }
          imageBytes = Uint8List.fromList(List<int>.from(rawBytes));
        } else {
          imageBytes = Uint8List.fromList(List<int>.from(data));
        }
        final resultado = await _interpreter.clasificar(imageBytes);

        setState(() {
          resultadoIdioma = resultado["className"] ?? "Desconocido";
          double confRaw = (resultado["confidence"] ?? 0.0) as double;
          confianza = confRaw <= 1.0 ? confRaw : confRaw;
        });
      } catch (e) {
        debugPrint("Error procesando datos del stream: $e");
      }
    });
  }

  // Cancelar la escucha del stream cuando se detiene la grabación
  void _detenerEscuchaStream() {
    _subscription?.cancel();
    _subscription = null;
  }

  // Gestión de los estados del botón flotante sincronizado con Kotlin
  Future<void> _gestionarGrabacion() async {
    if (grabando) {
      await _grabacionService.detener();
      _detenerEscuchaStream();
      setState(() {
        grabando = false;
      });
    } else {
      var status = await Permission.microphone.status;
      if (status.isDenied) {
        status = await Permission.microphone.request();
      }

      if (status.isGranted) {
        final String? idSession = await _grabacionService.iniciar();
        if (idSession != null) {
          _iniciarEscuchaStream();
          setState(() {
            grabando = true;
            confianza = 0.0;
          });
        } else {
          setState(() {});
        }
      } else {
        if(!mounted) return;
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
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 32.0,
          ),
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
                color: grabando
                    ? Color.fromARGB(255, 181, 255, 187)
                    : Color.fromARGB(255, 235, 255, 198),
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
                      color: grabando
                          ? const Color.fromARGB(255, 0, 0, 0)
                          : const Color.fromARGB(137, 0, 0, 0),
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
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: ControlesGrabacion(
        grabando: grabando,
        onToggle: _gestionarGrabacion,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
