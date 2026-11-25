import 'package:flutter/material.dart';

class ControlesGrabacion extends StatelessWidget {
  final bool grabando;
  final VoidCallback onToggle;

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
