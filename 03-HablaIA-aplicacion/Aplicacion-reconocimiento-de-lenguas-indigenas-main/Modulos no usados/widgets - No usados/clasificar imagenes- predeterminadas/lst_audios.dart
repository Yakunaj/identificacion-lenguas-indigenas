import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:audio_waveforms/audio_waveforms.dart';
import '../servicios/uso_modelo.dart';
import '../Paginas/resultados_pagina.dart';
import 'barra_acciones_lista.dart';
import '../servicios/imagen_rand.dart';

class ListaAudios extends StatefulWidget {
  final int? limite;

  const ListaAudios({super.key, this.limite});

  @override
  State<ListaAudios> createState() {
    return _ListaAudiosState();
  }
}

class _ListaAudiosState extends State<ListaAudios> {
  late ModeloService modelo;
  bool cargando = false;
  late PlayerController playerController;
  List<FileSystemEntity> archivosLocales = [];

  @override
  void initState() {
    super.initState();
    modelo = ModeloService();
    playerController = PlayerController();
    _obtenerGrabaciones(widget.limite);
  }

  void reproducir(String path) async {
    print(path);
    try {
      if (!await File(path).exists()) {
        return;
      }
      await playerController.stopPlayer();

      await playerController.preparePlayer(
        path: path,
        shouldExtractWaveform: false,
      );
      await playerController.startPlayer(forceRefresh: true);
    } catch (e) {
      throw Exception(e);
    }
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
    final carpeta = Directory(directorio.path);
    List<FileSystemEntity> lista = await carpeta
        .list()
        .where((archivo) => archivo.path.endsWith('.wav'))
        .toList();
    lista.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    if (limite != null && lista.length > limite) {
      lista = lista.sublist(0, widget.limite);
    }
    setState(() {
      archivosLocales = lista;
    });
  }

  Future<void> analizarAudio(String audioPath) async {
    String imgRand = obtenerImagenAleatoria();
    try {
      setState(() => cargando = true);
      if (!modelo.cargado) {
        await modelo.cargarModelo();
      }
      var resultado = await modelo.predecirDesdeImagen(imgRand);
      print("Resultado");
      if (!mounted) {
        return;
      }
      setState(() => cargando = false);

      Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * .8,
          height: MediaQuery.of(context).size.width * .8,
          child: ResultadoPagina(
            idioma: resultado["idioma"],
            confianza: resultado["confianza"],
          ),
        ), 
      );
    } catch (e) {
      setState(() => cargando = false);
      throw Exception("ERROR REAL: $e");
    }
  }

  @override
  void dispose() {
    playerController.dispose();
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
              String nombre = p.basename(archivosLocales[index].path);

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
