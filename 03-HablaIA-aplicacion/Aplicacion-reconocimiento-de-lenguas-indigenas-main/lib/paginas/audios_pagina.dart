import 'package:flutter/material.dart';
import '../widgets/lista_audios_widget.dart';

// Página de audios, que muestra la lista de grabaciones de audio y permite reproducir, borrar o analizar cada archivo.
class AudiosPagina extends StatelessWidget {
  const AudiosPagina({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Grabaciones"),
      ),
      body: 
            ListaAudios(), 
    );
  }
}