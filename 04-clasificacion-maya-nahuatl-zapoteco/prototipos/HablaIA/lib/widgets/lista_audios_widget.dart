import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../servicios/modelo_servicio.dart';
import '../paginas/resultados_pagina.dart';
import '../servicios/reproductor_servicio.dart';
import 'barra_acciones_widget.dart';

// Widget de lista de audios, que muestra los archivos de audio grabados y permite reproducir, borrar o analizar cada archivo.
class ListaAudios extends StatefulWidget {
  const ListaAudios({super.key});

  @override
  State<ListaAudios> createState() {
    return _ListaAudiosState();
  }
}

// Estado del widget de lista de audios, que maneja la lógica de obtención, reproducción, borrado y análisis de los archivos de audio.
class _ListaAudiosState extends State<ListaAudios> {
  final ReproductorAudio _service = ReproductorAudio();
  final UsoModelo tflite = UsoModelo();
  bool cargando = false;
  List<FileSystemEntity> archivosLocales = [];

  @override
  void initState() {
    tflite.cargarModelo();
    super.initState();
    _obtenerGrabaciones();
  }

  // Función para reproducir un archivo de audio dado su path, pausando cualquier reproducción en curso.
  void reproducir(String path) async {
    debugPrint(path);
    try {
      if (!await File(path).exists()) {
        return;
      }
      await _service.pausar();
      await _service.reproducir(path);
    } catch (e) {
      throw Exception(e);
    }
  }

  // Función para pausar la reproducción de audio en curso.
  void pausar() async {
    await _service.pausar();
  }

  // Función para mostrar un diálogo de confirmación antes de borrar una grabación.
  Future<bool> confirmarBorrado(BuildContext context) async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('¿Estás seguro?'),
            content: const Text(
              'Esta acción eliminará la grabación de forma permanente.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
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

  // Función para obtener los archivos de audio grabados en el directorio temporal, filtrando por nombre y ordenando por fecha de modificación, limitando la cantidad si se especifica un límite.
  Future<void> _obtenerGrabaciones() async {
    final directorio = await getTemporaryDirectory();
    final carpetaRaiz = Directory(directorio.path);

    List<FileSystemEntity> archivosWav = [];

    await for (final entidad in carpetaRaiz.list()) {
      if (entidad is Directory &&
          entidad.path.split('/').last.startsWith('Grabacion_')) {
        // Buscar directamente el archivo completo en la raíz de la sesión
        final archivoCompleto = File('${entidad.path}/grabacion_completa.wav');

        if (await archivoCompleto.exists()) {
          archivosWav.add(archivoCompleto);
        }
      }
    }

    archivosWav.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );

    setState(() {
      archivosLocales = archivosWav;
    });
  }

  // Función para obtener el resultado con la mayor confianza
  Map<String, dynamic> masAlto(List<Map<String, dynamic>> resultados) {
    return resultados.reduce((a, b) {
      final confA = (a["confidence"] ?? a["confianza"] ?? 0.0) as double;
      final confB = (b["confidence"] ?? b["confianza"] ?? 0.0) as double;
      return confA >= confB ? a : b;
    });
  }

  // Función para obtener el resultado con la mayor confianza promedio por idioma
  // Cuenta los votos y suma las confianzas, devolviendo el idioma con más votos y su confianza promedio.
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

  // Función para obtener el resultado con la mayor mediana de confianza por idioma
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
      final mediana = confianzas.length.isOdd
          ? confianzas[mid]
          : (confianzas[mid - 1] + confianzas[mid]) / 2;

      if (mediana > mejorMediana) {
        mejorMediana = mediana;
        mejorIdioma = idioma;
      }
    });

    return {"className": mejorIdioma, "confidence": mejorMediana};
  }

  // Función para analizar un archivo de audio dado su path
  // obtiene los espectrogramas generados y clasificando cada bloque con el modelo, mostrando el resultado final en un diálogo.
  Future<void> analizarAudio(String audioPath) async {
    final carpetaSesion = p.dirname(audioPath);
    final carpetaEspectrogramas = Directory('$carpetaSesion/espectrogramas');

    if (!await carpetaEspectrogramas.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No hay espectrogramas para esta grabación"),
        ),
      );
      return;
    }

    final pngs = await carpetaEspectrogramas
        .list()
        .where((f) => f.path.endsWith('.png'))
        .toList();

    pngs.sort((a, b) {
      final numA =
          int.tryParse(
            p
                .basenameWithoutExtension(a.path)
                .replaceFirst('espectrograma_', ''),
          ) ??
          0;
      final numB =
          int.tryParse(
            p
                .basenameWithoutExtension(b.path)
                .replaceFirst('espectrograma_', ''),
          ) ??
          0;
      return numA.compareTo(numB);
    });

    try {
      setState(() => cargando = true);

      final List<Map<String, dynamic>> resultados = [];
      for (final png in pngs) {
        final Map<String, dynamic> resultado = await tflite
            .clasificarDesdeArchivo(png.path);
        resultados.add(resultado);
      }

      final resultado = promedio(resultados);

      if (!mounted) return;
      setState(() => cargando = false);

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * .8,
              height: MediaQuery.of(context).size.width * .8,
              child: Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ResultadoPagina(
                  idioma:
                      resultado["className"] ??
                      resultado["idioma"] ??
                      "Desconocido",
                  confianza:
                      (resultado["confidence"] ?? resultado["confianza"] ?? 0.0)
                          as double,
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) setState(() => cargando = false);
      debugPrint("ERROR AL CLASIFICAR AUDIO NATIVO: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al analizar el audio: $e")));
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
        Column(
          children: [
            barraAcciones(),
            Divider(
              height: 0,
              thickness: 3,
              color: Color.fromARGB(255, 144, 142, 142),
            ),
          ],
        ),

        Expanded(
          child: ListView.separated(
            itemCount: archivosLocales.length,
            separatorBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                thickness: 3,
                color: Color.fromARGB(255, 144, 142, 142),
              ),
            ),
            itemBuilder: (context, index) {
              String nombre = p.basename(
                p.dirname(archivosLocales[index].path),
              );

              return ListTile(
                leading: IconButton(
                  onPressed: () async {
                    bool seguro = await confirmarBorrado(context);
                    if (seguro) {
                      final carpeta = Directory(
                        p.dirname(archivosLocales[index].path),
                      );

                      if (await carpeta.exists()) {
                        await carpeta.delete(recursive: true);
                      }

                      setState(() {
                        archivosLocales.removeAt(index);
                      });
                    }
                  },
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                ),
                title: Text(nombre),
                subtitle: Text(
                  "Tamaño: ${(File(archivosLocales[index].path).lengthSync() / 1024).toStringAsFixed(2)} KB",
                ),
                onTap: () => analizarAudio(archivosLocales[index].path),
                trailing: IconButton(
                  onPressed: () => reproducir(archivosLocales[index].path),
                  icon: const Icon(
                    Icons.play_circle_fill,
                    color: Colors.blueGrey,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
