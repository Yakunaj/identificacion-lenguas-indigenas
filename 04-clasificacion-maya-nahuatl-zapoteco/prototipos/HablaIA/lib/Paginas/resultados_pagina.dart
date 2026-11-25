import 'package:flutter/material.dart';


class ResultadoPagina extends StatelessWidget {
  final String idioma;
  final double confianza;

// Constructor del widget de página de resultados, que recibe el idioma detectado y la confianza del modelo.
  const ResultadoPagina({
    super.key,
    required this.idioma,
    required this.confianza,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Resultado", style: TextStyle(fontSize: 22)),
            
            Text(
              "Idioma detectado",
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 20),

            Text(
              idioma,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),

            SizedBox(height: 10),

            Text(
              "Confianza: ${(confianza).toStringAsFixed(2)}%",
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      );
  }
}