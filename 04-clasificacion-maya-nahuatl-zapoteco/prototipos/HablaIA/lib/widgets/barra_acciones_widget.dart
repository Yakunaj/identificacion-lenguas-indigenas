import 'package:flutter/material.dart';

// Barra de acciones para la lista de archivos, con las opciones de borrar, analizar y reproducir.
Widget barraAcciones() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: _TextoAccion("Borrar"),
          ),
        ),
        _separador(),
        Expanded(
          child: Align(
            alignment: Alignment.center,
            child: _TextoAccion("Analizar"),
          ),
        ),
        _separador(),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: _TextoAccion("Reproducir"),
          ),
        ),
      ],
    ),
  );
}

// Widget para el texto de cada acción en la barra de acciones.
class _TextoAccion extends StatelessWidget {
  final String texto;

  const _TextoAccion(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: TextStyle(
        fontSize: 18,
        color: const Color.fromARGB(255, 0, 0, 0),
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    );
  }
}

// Widget para la linea separadora entre las acciones en la barra de acciones.
Widget _separador() {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 10),
    width: 2,
    height: 30,
    color: const Color.fromARGB(255, 144, 142, 142),
  );
}
