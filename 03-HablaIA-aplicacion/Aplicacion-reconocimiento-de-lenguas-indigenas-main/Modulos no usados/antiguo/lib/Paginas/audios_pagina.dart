import 'package:flutter/material.dart';
import '../widgets/lst_audios.dart';
  
class AudiosPagina extends StatelessWidget {
  const AudiosPagina({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Todas las grabaciones"),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
      ),
      body: 
            ListaAudios(), 
    );
  }
}