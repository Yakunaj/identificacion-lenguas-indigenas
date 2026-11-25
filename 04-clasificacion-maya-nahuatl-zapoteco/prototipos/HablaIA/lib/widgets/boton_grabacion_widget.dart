import 'package:flutter/material.dart';

// Widget de controles de grabación, que muestra un botón para iniciar o detener la grabación de audio.
class ControlesGrabacion extends StatelessWidget {
  final bool grabando;
  final VoidCallback onToggle;

  // Constructor del widget de controles de grabación, que recibe el estado de grabación y la función para alternar la grabación.
  const ControlesGrabacion({
    super.key,
    required this.grabando,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
