import 'dart:async';
import 'package:flutter/material.dart';
import '../servicios/grabacion_servicio.dart';
import '../estructuras/grabacion_informacion_estructura.dart';
import '../estructuras/segmento_audio_estructura.dart';
import '../estructuras/sesion_grabacion_estructura.dart';
import '../servicios/modelo_servicio.dart';
import '../servicios/sqlite_servicio.dart';
import '../servicios/ubicacion_servicio.dart';
import '../servicios/waveform_servicio.dart';
import '../widgets/boton_grabacion_widget.dart';
import '../widgets/waveform_construccion_widget.dart';
import 'package:permission_handler/permission_handler.dart';

// Página principal de la aplicación, que permite grabar audio
// y clasificarlo usando el modelo.
class PrincipalPagina extends StatefulWidget {
  const PrincipalPagina({super.key});

  @override
  State<PrincipalPagina> createState() => _PrincipalPaginaState();
}

class _PrincipalPaginaState extends State<PrincipalPagina> {
  final Grabacion _grabacionService = Grabacion();
  final ClasificadorServicio _clasificador = ClasificadorServicio.instancia;

  final WaveformServicio _waveformServicio = WaveformServicio();
  final UbicacionServicio _ubicacionServicio = UbicacionServicio();

  /// Grabación en curso: acumula los resultados para guardarlos al detener.
  SesionGrabacion? _sesion;

  /// Ubicación que se pide al empezar a grabar (se espera al guardar).
  Future<Ubicacion?>? _ubicacion;

  /// Clasificaciones aún en proceso; se esperan antes de guardar.
  final Set<Future<void>> _clasificacionesPendientes = {};

  StreamSubscription? _subscription;

  bool grabando = false;

  String resultadoIdioma = 'Esperando grabacion';
  double confianza = 0.0;

  DateTime? tiempo;

  bool graboSuficiente = false;

  @override
  void initState() {
    super.initState();

    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      await _clasificador.inicializar();
    } catch (e) {
      debugPrint("Error cargando modelo: $e");
    }
  }

  void _iniciarEscuchaStream() {
    _subscription = _grabacionService.results.listen((data) async {
      try {
        if (data is Map) {
          final tipo = data['type'];

          if (tipo == 'amplitude') {
            final valor = data['value'];

            if (valor != null) {
              final amplitud = (valor as num).toDouble();

              _waveformServicio.agregarAmplitud(amplitud);
            }

            return;
          }

          if (tipo == 'segmento') {
            final ruta = data['ruta'];

            if (ruta is! String) {
              throw Exception("El evento 'segmento' no contiene la llave 'ruta'");
            }

            final tarea = _clasificarSegmento(
              _sesion,
              SegmentoAudio(
                numero: (data['numero'] as num?)?.toInt() ?? 0,
                rutaWav: ruta,
              ),
            );
            _clasificacionesPendientes.add(tarea);
            await tarea.whenComplete(
              () => _clasificacionesPendientes.remove(tarea),
            );

            return;
          }
        }
      } catch (e) {
        debugPrint("Error procesando datos del stream: $e");
      }
    });
  }

  /// Clasifica un segmento, lo agrega a la sesión y actualiza la pantalla.
  Future<void> _clasificarSegmento(
    SesionGrabacion? sesion,
    SegmentoAudio segmento,
  ) async {
    try {
      final resultado = await _clasificador.clasificar(segmento);

      if (sesion != null) {
        sesion.agregar(resultado);
        sesion.sampleRate ??= (await segmento.leerPcm()).sampleRate;
      }

      if (!mounted || !grabando || !graboSuficiente) {
        return;
      }

      setState(() {
        resultadoIdioma = resultado.etiqueta;
        confianza = resultado.confianza;
      });
    } catch (e) {
      debugPrint("Error clasificando el segmento ${segmento.numero}: $e");
    }
  }

  /// Guarda la grabación terminada en SQLite (con su ubicación, si hay).
  Future<void> _guardarSesion(
    SesionGrabacion sesion,
    DateTime fin,
    Future<Ubicacion?>? ubicacionPendiente,
    List<Future<void>> pendientes,
  ) async {
    try {
      await Future.wait(pendientes);
      final ubicacion = await ubicacionPendiente;

      final fila = sesion.resumir(
        numero: await GrabacionesDb.siguienteNumero(),
        fin: fin,
        ubicacion: ubicacion,
      );
      if (fila == null) return; // menos de 5 s: nada que guardar

      await GrabacionesDb.insertar(fila);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ubicacion == null
                ? "Grabación guardada (sin ubicación)"
                : "Grabación guardada con ubicación",
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error guardando la grabación: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No se pudo guardar la grabación: $e")),
      );
    }
  }

  void _detenerEscuchaStream() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _gestionarGrabacion() async {
    if (grabando) {
  final sesion = _sesion;
  final ubicacion = _ubicacion;
  final pendientes = _clasificacionesPendientes.toList();
  final fin = DateTime.now();
  _sesion = null;
  _ubicacion = null;

  _detenerEscuchaStream();
  _waveformServicio.limpiar();

  setState(() {
    grabando = false;
    resultadoIdioma = 'Esperando grabacion';
    confianza = 0.0;
    tiempo = null;
    graboSuficiente = false;
  });

  await _grabacionService.detener();

  if (sesion != null) {
    unawaited(_guardarSesion(sesion, fin, ubicacion, pendientes));
  }
  return;
}

    var status = await Permission.microphone.status;

    if (status.isDenied) {
      status = await Permission.microphone.request();
    }

    if (status.isGranted) {
      // Solo pregunta la primera vez; si se niega se graba sin ubicación.
      await _ubicacionServicio.pedirPermiso();

      final String? idSession = await _grabacionService.iniciar();

      if (idSession != null) {
        tiempo = DateTime.now();

        _sesion = SesionGrabacion(rutaSesion: idSession, inicio: tiempo!);
        _ubicacion = _ubicacionServicio.obtener();

        graboSuficiente = false;

        _waveformServicio.limpiar();

        setState(() {
          grabando = true;

          resultadoIdioma = 'Grabe al menos 5 segundos';

          confianza = 0.0;
        });

        _iniciarEscuchaStream();

        Future.delayed(const Duration(seconds: 5), () {
          if (!mounted || !grabando) {
            return;
          }

          setState(() {
            graboSuficiente = true;

            resultadoIdioma = 'Analizando...';
          });
        });
      } else {
        setState(() {});
      }
    } else {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Acepta el permiso del micrófono en los ajustes para usar la app.",
          ),
        ),
      );
    }
  }

  Future<void> _elegirModelo() async {
    try {
      await _clasificador.inicializar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("No se pudieron cargar los modelos: $e")));
      return;
    }
    if (!mounted) return;

    final elegido = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Modelo de clasificación')),
            for (final modelo in _clasificador.modelosDisponibles)
              ListTile(
                selected: modelo.id == _clasificador.modeloActivo?.id,
                leading: Icon(
                  modelo.id == _clasificador.modeloActivo?.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(modelo.nombre),
                subtitle: Text(
                  '${modelo.salida.etiquetas.join(' · ')}  —  '
                  'entrada: ${modelo.entrada.tipo.name}  —  v${modelo.version}',
                ),
                onTap: () => Navigator.pop(context, modelo.id),
              ),
          ],
        ),
      ),
    );

    if (elegido == null) return;

    try {
      await _clasificador.seleccionarModelo(elegido);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("No se pudo cargar el modelo: $e")));
    }
  }

  @override
  void dispose() {
    _detenerEscuchaStream();

    _waveformServicio.dispose();

    _grabacionService.liberar();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Habla IA",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 60),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Elegir modelo',
            icon: const Icon(Icons.tune),
            onPressed: grabando ? null : _elegirModelo,
          ),
        ],
      ),

      body: Stack(
        children: [
          Positioned(
            left: 30,
            right: 30,
            top: 180,
            height: 150,
            child: ListenableBuilder(
              listenable: _waveformServicio,
              builder: (context, _) => WaveformWidget(
                amplitudes: _waveformServicio.amplitudes,
                height: 150,
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 200,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    resultadoIdioma.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  if (graboSuficiente) ...[
                    const SizedBox(height: 10),

                    Text(
                      "${confianza.toStringAsFixed(1)} % Confianza",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),

      floatingActionButton: ControlesGrabacion(
        grabando: grabando,
        onToggle: _gestionarGrabacion,
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
