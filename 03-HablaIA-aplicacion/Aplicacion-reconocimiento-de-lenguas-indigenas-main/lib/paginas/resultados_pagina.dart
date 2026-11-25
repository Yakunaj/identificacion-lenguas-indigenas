import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../servicios/reproductor_servicio.dart';
import '../estructuras/grabacion_resultados_estructura.dart';

class ResultadoPagina extends StatefulWidget {
  final List<ResultadoGrabacion> resultados;

  const ResultadoPagina({super.key, required this.resultados});

  @override
  State<ResultadoPagina> createState() => _ResultadoPaginaState();
}

class _ResultadoPaginaState extends State<ResultadoPagina> {
  final ReproductorAudio _reproductor = ReproductorAudio();
  StreamSubscription<void>? _subFin;
  int? reproduciendo;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _subFin?.cancel();
    _reproductor.eliminar();
    super.dispose();
  }

  Future<void> _reproducirAudio(ResultadoGrabacion resultado) async {
    await _reproductor.eliminar();

    if (reproduciendo == resultado.numero) {
      setState(() => reproduciendo = null);
      return;
    }

    if (resultado.rutaAudio.isEmpty ||
        !await File(resultado.rutaAudio).exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No se encontró el audio")));
      setState(() => reproduciendo = null);
      return;
    }

    setState(() => reproduciendo = resultado.numero);
    await _reproductor.reproducir(resultado.rutaAudio);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final idxTotal = widget.resultados.indexWhere((r) => r.numero == 0);
    final total = idxTotal >= 0 ? widget.resultados[idxTotal] : null;
    final fragmentos = widget.resultados.where((r) => r.numero != 0).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Resultados",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.tertiary,
      ),
      body: Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.70,
          height: MediaQuery.of(context).size.height * 0.70,
          child: ListView(
            children: [
              if (total != null) ...[
                const Text(
                  "Total",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                primero(total, colorScheme, esTotal: true),
                const SizedBox(height: 25),
              ],
              const Text(
                "Fragmentos",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              for (int i = 0; i < fragmentos.length; i++) ...[
                primero(fragmentos[i], colorScheme),
                if (i < fragmentos.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget primero(
    dynamic resultado,
    ColorScheme colorScheme, {
    bool esTotal = false,
  }) {
    final estaReproduciendo = reproduciendo == resultado.numero;

    return Container(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.secondary,
              shape: BoxShape.circle,
            ),
            child: esTotal
                ? Icon(Icons.graphic_eq, color: colorScheme.tertiary)
                : Text(
                    "${resultado.numero}",
                    style: TextStyle(
                      color: colorScheme.tertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (esTotal)
                  Text(
                    "Audio completo",
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.secondary,
                    ),
                  ),
                Text(
                  resultado.idioma.toUpperCase(),
                  style: TextStyle(
                    fontSize: esTotal ? 16 : 14,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.tertiary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "Confianza: ${resultado.confianza.toStringAsFixed(2)}%",
                  style: TextStyle(fontSize: 12, color: colorScheme.secondary),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _reproducirAudio(resultado),
            icon: Icon(
              estaReproduciendo ? Icons.stop_circle : Icons.play_circle,
              size: 42,
              color: colorScheme.tertiary,
            ),
          ),
        ],
      ),
    );
  }
}
