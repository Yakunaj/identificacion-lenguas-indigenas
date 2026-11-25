import 'package:flutter/material.dart';
import 'package:Uuy/widgets/lst_audios.dart';
import '../widgets/btn_grabacion.dart'; 
import '../widgets/waveform.dart';        
import '../servicios/grabacion.dart';   

class ColorPagina extends StatefulWidget {
  const ColorPagina({super.key});

  @override
  State<ColorPagina> createState() => _ColorPaginaState();
}

class _ColorPaginaState extends State<ColorPagina> {
  final RecorderService _service = RecorderService();
  
  bool grabando = false;
  String mensaje = 'Graba un audio';
  final Color fondo = const Color.fromARGB(255, 214, 255, 181);

  Future<void> _gestionarGrabacion() async {
    if (grabando) {
      //final path = await _service.detener();
      setState(() {
        grabando = false;
        mensaje = 'Grabación guardada';
      });
    } else {
      final tienePermiso = await _service.tienePermiso();
      if (tienePermiso) {
        
        await _service.iniciar();
        setState(() {
          grabando = true;
          mensaje = 'Grabando...';
        });
      } else {
        mensaje = 'Acepta los permisos antes de empezar a grabar';
        setState(() => mensaje = 'No diste permiso al micrófono');
      }
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
          children: [
            ListaAudios(limite: 3),
          ],
        ),
      );
    },
  );
}

  @override
  void dispose() {
    _service.liberar(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondo,
      appBar: AppBar(
        title: const Text("Principal"),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            VisualizadorAudio(controller: _service.controller),
            
            const SizedBox(height: 30),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Text(
                mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: ControlesGrabacion(
        grabando: grabando,
        onToggle: _gestionarGrabacion,
        onVerListado: () => _mostrar(context),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}