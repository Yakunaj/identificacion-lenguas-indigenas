/*
import 'package:flutter/material.dart';
import 'resultados_pagina.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../servicios/uso_modelo.dart';

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ModeloService modelo = ModeloService();

  bool band= false;

  Future<void> carga() async{
    await modelo.cargarModelo();
    setState(() {
      band=true;
    });
  }

  @override
  void initState() {
    super.initState();
    carga();
  }

  @override
  void dispose() {
    modelo.dispose();
    super.dispose();
  }

  void procesarAudio() async {
    modelo.cargarModelo();
    

    var resultado = await modelo.predecir(input);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultadoPagina(
          idioma: resultado["idioma"],
          confianza: resultado["confianza"],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Prueba del modelo"),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: band ? procesarAudio : null,
          child: Text(band ? "Probar modelo" : "Cargando modelo..."),
        ),
      ),
    );
  }
}
*/