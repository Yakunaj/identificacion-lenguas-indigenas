import 'package:flutter/material.dart';

class ControlesGrabacion extends StatelessWidget {
  final bool grabando;
  final VoidCallback onToggle;
  final VoidCallback onVerListado;

  const ControlesGrabacion({
    super.key,
    required this.grabando,
    required this.onToggle,
    required this.onVerListado,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          onPressed: onVerListado,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            fixedSize: const Size(200, 50),
          ),
          icon: const Icon(Icons.list),
          label: const Text("Ver Grabaciones"),
        ),

        const SizedBox(height: 16),

        SizedBox(
          width: 120,
          height: 120,
          child: FloatingActionButton(
            onPressed: onToggle,
            backgroundColor: grabando ? Colors.red : Colors.blueGrey,
            foregroundColor: grabando ? Colors.white : Colors.amber,
            shape: const CircleBorder(),
            heroTag: "btn_grabacion",
            child: Icon(grabando ? Icons.stop : Icons.mic, size: 60),
          ),
        ),
      ],
    );
  }
}

  void _mostrar(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [ListaAudios(limite: 3)],
          ),
        );
      },
    );
  }

   floatingActionButton: ControlesGrabacion(
        grabando: grabando,
        onToggle: _gestionarGrabacion,
        onVerListado: () => _mostrar(context),
      ),