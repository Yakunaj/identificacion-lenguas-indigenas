import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../servicios/uso_modelo.dart';
import '../Paginas/resultados_pagina.dart';
import '../servicios/reproductor.dart';
import 'barra_acciones_lista.dart';

class ListaAudios extends StatefulWidget {
  final int? limite;

  const ListaAudios({super.key, this.limite});

  @override
  State<ListaAudios> createState() {
    return _ListaAudiosState();
  }
}

class _ListaAudiosState extends State<ListaAudios> {
  final ReproductorAudio _service = ReproductorAudio();
  final UsoModelo tflite = UsoModelo();
  bool cargando = false;
  List<FileSystemEntity> archivosLocales = [];

  @override
  void initState() {
    tflite.cargarModelo();
    super.initState();
    _obtenerGrabaciones(widget.limite);
  }

  void reproducir(String path) async {
    print(path);
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

  void pausar() async {
    await _service.pausar();
  }

  void borrar(File archivo, int index) async {
    try {
      await archivo.delete();
      setState(() {
        archivosLocales.removeAt(index);
        //mensaje = 'EL audio se ha borrado exitosamente';
      });
    } catch (e) {
      //print("Error: $e");
    }
  }

  Future<bool> confirmarBorrado(BuildContext context) async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('¿Estás seguro?'),
            content: const Text(
              'Esta acción eliminará el archivo de forma permanente.',
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

  Future<void> _obtenerGrabaciones(int? limite) async {
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

    if (limite != null && archivosWav.length > limite) {
      archivosWav = archivosWav.sublist(0, limite);
    }

    setState(() {
      archivosLocales = archivosWav;
    });
  }

 

  // ── Mejor confianza (ya la tienes) ──────────────────────────────────────────
  Map<String, dynamic> masAlto(List<Map<String, dynamic>> resultados) {
    return resultados.reduce((a, b) {
      final confA = (a["confidence"] ?? a["confianza"] ?? 0.0) as double;
      final confB = (b["confidence"] ?? b["confianza"] ?? 0.0) as double;
      return confA >= confB ? a : b;
    });
  }

  // ── Promedio de confianza por idioma ────────────────────────────────────────
 Map<String, dynamic> promedio(List<Map<String, dynamic>> resultados) {
  final Map<String, int> votos = {};
  final Map<String, double> confianzaTotal = {};

  for (final r in resultados) {
    final idioma = r["className"] ?? "Desconocido";
    print("Idioma detectado: $idioma");
    final confianza = (r["confidence"] ?? 0.0) as double;
    print("Confianza detectada: $confianza");
    votos[idioma] = (votos[idioma] ?? 0) + 1;
    confianzaTotal[idioma] = (confianzaTotal[idioma] ?? 0) + confianza;
  }
  print("Votos por idioma: $votos");
  print("Confianza total por idioma: $confianzaTotal");


  // Gana el que tenga más votos
  final ganador = votos.entries.reduce((a, b) => a.value >= b.value ? a : b);
  final count   = ganador.value;
  print("conteo ganador: ${ganador.key} con $count votos");
  final promedio = confianzaTotal[ganador.key]! / count;
  print("Resultado final: ${ganador.key} con promedio de confianza $promedio");

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

  Future<void> analizarAudio(String audioPath) async {
    final carpetaSesion = p.dirname(audioPath);
    final carpetaEspectrogramas = Directory('$carpetaSesion/espectrogramas');

    if (!await carpetaEspectrogramas.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No hay espectrogramas para esta grabación"),
        ),
      );
      return;
    }

    // Obtener y ordenar por número de bloque
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
    print("Espectrogramas encontrados: ${pngs.length}");
    print("$pngs");
    try {
      setState(() => cargando = true);

      // Acumular resultados de cada bloque
      final List<Map<String, dynamic>> resultados = [];
      print("Analizando cada bloque con el modelo...");
      
      for (final png in pngs) {
        print(png.path);
        final Map<String, dynamic> resultado = await tflite.clasificarDesdeArchivo(png.path);
        print("Bloque ${p.basename(png.path)}: $resultado");
        resultados.add(resultado);
        print("Bloque ${p.basename(png.path)}: $resultado");
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
                      (resultado["confidence"] ??
                              resultado["confianza"] ??
                              0.0)
                          as double,
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) setState(() => cargando = false);
      print("ERROR AL CLASIFICAR AUDIO NATIVO: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al analizar el audio: $e")));
    }
  }

  @override
  void dispose() {
    _service.detener();
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
              String nombre =
                  p.basename(p.dirname(archivosLocales[index].path));

              return ListTile(
                leading: IconButton(
                  onPressed: () async {
                    bool seguro = await confirmarBorrado(context);
                    if (seguro) {
                      await File(archivosLocales[index].path).delete();
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
