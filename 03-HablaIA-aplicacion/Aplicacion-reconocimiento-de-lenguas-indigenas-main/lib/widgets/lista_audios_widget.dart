import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../servicios/modelo_servicio.dart';
import '../servicios/sqlite_servicio.dart';
import '../estructuras/segmento_audio_estructura.dart';
import '../paginas/resultados_pagina.dart';
import '../servicios/reproductor_servicio.dart';
import '../estructuras/grabacion_resultados_estructura.dart';

enum AccionAudio { eliminar, analizar }

class ListaAudios extends StatefulWidget {
  const ListaAudios({super.key});

  @override
  State<ListaAudios> createState() {
    return _ListaAudiosState();
  }
}

class _ListaAudiosState extends State<ListaAudios> {
  final ReproductorAudio _service = ReproductorAudio();
  final ClasificadorServicio _clasificador = ClasificadorServicio.instancia;

  bool cargando = false;
  List<FileSystemEntity> archivosLocales = [];
  String? _pathReproduciendo;

  @override
  void initState() {
    super.initState();
    _clasificador.inicializar().catchError(
      (e) => debugPrint('Error cargando modelo: $e'),
    );
    _obtenerGrabaciones();
  }

  Future<void> alternarReproduccion(String path) async {
    try {
      if (!await File(path).exists()) {
        return;
      }

      if (_pathReproduciendo == path) {
        await _service.pausar();

        if (!mounted) return;

        setState(() {
          _pathReproduciendo = null;
        });
      } else {
        await _service.pausar();
        await _service.reproducir(path);

        if (!mounted) return;

        setState(() {
          _pathReproduciendo = path;
        });
      }
    } catch (e) {
      debugPrint("Error reproduciendo audio: $e");
    }
  }

  Future<bool> confirmarBorrado(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('¿Estás seguro?'),
            content: const Text(
              'Esta acción eliminará la grabación de forma permanente.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: const Color.fromARGB(255, 65, 71, 77),
                ),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Borrar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _obtenerGrabaciones() async {
    final directorio = await getTemporaryDirectory();
    final carpetaRaiz = Directory(directorio.path);

    final List<FileSystemEntity> archivosWav = [];

    await for (final entidad in carpetaRaiz.list()) {
      if (entidad is Directory &&
          entidad.path.split('/').last.startsWith('Grabacion_')) {
        final archivoCompleto = File('${entidad.path}/grabacion_completa.wav');

        if (await archivoCompleto.exists()) {
          archivosWav.add(archivoCompleto);
        }
      }
    }

    archivosWav.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );

    if (!mounted) return;

    setState(() {
      archivosLocales = archivosWav;
    });
  }

  Map<String, dynamic> masAlto(List<Map<String, dynamic>> resultados) {
    return resultados.reduce((a, b) {
      final confA = (a["confidence"] ?? a["confianza"] ?? 0.0) as double;

      final confB = (b["confidence"] ?? b["confianza"] ?? 0.0) as double;

      return confA >= confB ? a : b;
    });
  }

  Map<String, dynamic> promedio(List<Map<String, dynamic>> resultados) {
    final Map<String, int> votos = {};
    final Map<String, double> confianzaTotal = {};

    for (final r in resultados) {
      final idioma = r["className"] ?? "Desconocido";
      final confianza = (r["confidence"] ?? 0.0) as double;

      votos[idioma] = (votos[idioma] ?? 0) + 1;
      confianzaTotal[idioma] = (confianzaTotal[idioma] ?? 0) + confianza;
    }

    final ganador = votos.entries.reduce((a, b) => a.value >= b.value ? a : b);

    final count = ganador.value;
    final promedio = confianzaTotal[ganador.key]! / count;

    return {"className": ganador.key, "confidence": promedio};
  }

  Map<String, dynamic> mediana(List<Map<String, dynamic>> resultados) {
    final Map<String, List<double>> confianzasPorIdioma = {};

    for (final r in resultados) {
      final idioma = r["className"] ?? r["idioma"] ?? "Desconocido";

      final confianza = (r["confidence"] ?? r["confianza"] ?? 0.0) as double;

      confianzasPorIdioma.putIfAbsent(idioma, () => []).add(confianza);
    }

    String mejorIdioma = "Desconocido";
    double mejorMediana = -1;

    confianzasPorIdioma.forEach((idioma, confianzas) {
      confianzas.sort();

      final mid = confianzas.length ~/ 2;

      final valorMediana = confianzas.length.isOdd
          ? confianzas[mid]
          : (confianzas[mid - 1] + confianzas[mid]) / 2;

      if (valorMediana > mejorMediana) {
        mejorMediana = valorMediana;
        mejorIdioma = idioma;
      }
    });

    return {"className": mejorIdioma, "confidence": mejorMediana};
  }

  Future<void> analizarAudio(String audioPath) async {
    final carpetaSesion = p.dirname(audioPath);

    final carpetaFragmentos = Directory('$carpetaSesion/fragmentos');

    if (!await carpetaFragmentos.exists()) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No hay fragmentos de audio para esta grabación"),
        ),
      );

      return;
    }

    // Cada fragmento WAV es un segmento; el modelo activo decide cómo
    // preprocesarlo (espectrograma, audio crudo, ...).
    int numeroDe(String ruta) =>
        int.tryParse(
          p.basenameWithoutExtension(ruta).replaceFirst('bloque_', ''),
        ) ??
        0;

    final segmentos =
        (await carpetaFragmentos
                .list()
                .where((f) => f.path.endsWith('.wav'))
                .toList())
            .map((f) => SegmentoAudio(numero: numeroDe(f.path), rutaWav: f.path))
            .toList()
          ..sort((a, b) => a.numero.compareTo(b.numero));

    try {
      setState(() {
        cargando = true;
      });

      final List<ResultadoGrabacion> resultados = [];

      for (int i = 0; i < segmentos.length; i++) {
        final segmento = segmentos[i];

        final resultado = await _clasificador.clasificar(segmento);

        resultados.add(
          ResultadoGrabacion(
            numero: i + 1,
            idioma: resultado.etiqueta,
            confianza: resultado.confianza,
            rutaAudio: segmento.rutaWav,
          ),
        );
      }

      final resultadosMap = resultados.map((resultado) {
        return {
          "className": resultado.idioma,
          "confidence": resultado.confianza,
        };
      }).toList();

      final resultadoGeneral = promedio(resultadosMap);

      resultados.insert(
        0,
        ResultadoGrabacion(
          numero: 0,
          idioma: resultadoGeneral["className"] ?? "Desconocido",
          confianza: (resultadoGeneral["confidence"] ?? 0.0).toDouble(),
          rutaAudio: audioPath,
        ),
      );

      if (!mounted) return;

      setState(() {
        cargando = false;
      });

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * .8,
              height: MediaQuery.of(context).size.height * .7,
              child: Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ResultadoPagina(resultados: resultados),
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          cargando = false;
        });
      }

      debugPrint("ERROR AL CLASIFICAR AUDIO NATIVO: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al analizar el audio: $e")));
    }
  }

  Future<void> _mostrarOpciones(
    BuildContext context,
    FileSystemEntity archivo,
    int index,
  ) async {
    final accion = await showModalBottomSheet<AccionAudio>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.analytics),
                title: const Text('Analizar'),
                onTap: () => Navigator.pop(context, AccionAudio.analizar),
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text('Eliminar'),
                onTap: () => Navigator.pop(context, AccionAudio.eliminar),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (accion == null || !mounted) return;

    await _manejarAccion(accion, archivo, index);
  }

  Future<void> _manejarAccion(
    AccionAudio accion,
    FileSystemEntity archivo,
    int index,
  ) async {
    switch (accion) {
      case AccionAudio.eliminar:
        final seguro = await confirmarBorrado(context);

        if (seguro) {
          final carpeta = Directory(p.dirname(archivo.path));

          if (await carpeta.exists()) {
            await carpeta.delete(recursive: true);
          }

          try {
            await GrabacionesDb.eliminarPorRutaSesion(carpeta.path);
          } catch (e) {
            debugPrint("Error borrando la grabación de la base de datos: $e");
          }

          if (_pathReproduciendo == archivo.path) {
            _pathReproduciendo = null;
          }

          setState(() {
            archivosLocales.removeAt(index);
          });
        }

        break;

      case AccionAudio.analizar:
        await analizarAudio(archivo.path);
        break;
    }
  }

  @override
  void dispose() {
    _service.eliminar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (archivosLocales.isEmpty) {
      return const Center(child: Text("No hay grabaciones aún."));
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: archivosLocales.length,
            separatorBuilder: (context, index) => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(thickness: 3),
            ),
            itemBuilder: (context, index) {
              final archivo = archivosLocales[index];

              final nombre = p.basename(p.dirname(archivo.path));

              final estaReproduciendo = _pathReproduciendo == archivo.path;

              return ListTile(
                leading: estaReproduciendo
                    ? const Icon(Icons.graphic_eq)
                    : null,
                title: Text(nombre),
                subtitle: Text(
                  "Tamaño: "
                  "${(File(archivo.path).lengthSync() / 1024).toStringAsFixed(2)} KB",
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => alternarReproduccion(archivo.path),
                      icon: Icon(
                        estaReproduciendo ? Icons.pause : Icons.play_arrow,
                        color: estaReproduciendo ? null : Colors.green,
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          _mostrarOpciones(context, archivo, index),
                      icon: const Icon(Icons.more_horiz),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
