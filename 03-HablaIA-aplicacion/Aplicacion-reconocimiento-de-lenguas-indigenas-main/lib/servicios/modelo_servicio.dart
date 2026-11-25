import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../estructuras/modelo_configuracion_estructura.dart';
import '../estructuras/modelos_disponibles_estructura.dart' as catalogo;
import '../estructuras/resultado_clasificacion_estructura.dart';
import '../estructuras/segmento_audio_estructura.dart';
import 'modelo/entradas_modelo.dart';
import 'modelo/salidas_modelo.dart';

/// Servicio único para clasificar audio con el modelo activo.
///
/// Los modelos se declaran en `estructuras/modelos_disponibles_estructura.dart`
/// (tipo de entrada, tipo de salida, etiquetas...).
class ClasificadorServicio extends ChangeNotifier {
  ClasificadorServicio._();

  static final ClasificadorServicio instancia = ClasificadorServicio._();

  static const String _preferenciaModelo = 'modelo_activo';

  final List<ConfiguracionModelo> _modelos = catalogo.modelosDisponibles;
  _ModeloCargado? _activo;
  Future<void>? _inicializacion;

  /// Serializa cargas e inferencias para no cerrar un intérprete en uso.
  Future<void> _cola = Future.value();

  List<ConfiguracionModelo> get modelosDisponibles => _modelos;
  ConfiguracionModelo? get modeloActivo => _activo?.configuracion;
  bool get listo => _activo != null;

  /// Carga el último modelo elegido (o el predeterminado).
  /// Se puede llamar varias veces; solo se ejecuta una.
  Future<void> inicializar() => _inicializacion ??= _inicializar().catchError(
    (Object e) {
      _inicializacion = null; // permite reintentar
      throw e;
    },
  );

  Future<void> _inicializar() async {
    if (_modelos.isEmpty) {
      throw StateError('No hay modelos en modelosDisponibles');
    }

    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getString(_preferenciaModelo);
    final elegido =
        _modelos.where((m) => m.id == guardado).firstOrNull ??
        _modelos.where((m) => m.predeterminado).firstOrNull ??
        _modelos.first;

    await _enCola(() => _cargar(elegido));
  }

  /// Cambia el modelo activo y recuerda la elección.
  Future<void> seleccionarModelo(String id) async {
    await inicializar();
    final configuracion = _modelos.firstWhere(
      (m) => m.id == id,
      orElse: () => throw ArgumentError('Modelo desconocido: $id'),
    );
    if (configuracion.id == _activo?.configuracion.id) return;

    await _enCola(() => _cargar(configuracion));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferenciaModelo, id);
  }

  /// Clasifica un segmento con el modelo activo.
  Future<ResultadoClasificacion> clasificar(SegmentoAudio segmento) async {
    await inicializar();
    return _enCola(() async {
      final modelo = _activo;
      if (modelo == null) throw StateError('No hay un modelo cargado');
      return modelo.clasificar(segmento);
    });
  }

  Future<void> _cargar(ConfiguracionModelo configuracion) async {
    final nuevo = await _ModeloCargado.cargar(configuracion);
    _activo?.cerrar();
    _activo = nuevo;
    debugPrint('Modelo activo: ${configuracion.identificadorVersion}');
    notifyListeners();
  }

  Future<T> _enCola<T>(Future<T> Function() tarea) {
    final resultado = _cola.then((_) => tarea());
    _cola = resultado.then<void>((_) {}, onError: (_) {});
    return resultado;
  }
}

/// Un modelo con su intérprete y sus adaptadores de entrada/salida.
class _ModeloCargado {
  final ConfiguracionModelo configuracion;
  final Interpreter interprete;
  final EntradaModelo entrada;
  final SalidaModelo salida;

  _ModeloCargado._(this.configuracion, this.interprete, this.entrada, this.salida);

  static Future<_ModeloCargado> cargar(ConfiguracionModelo configuracion) async {
    configuracion.salida.validar(configuracion.id);
    final interprete = await Interpreter.fromAsset(configuracion.archivo);
    try {
      interprete.allocateTensors();
      return _ModeloCargado._(
        configuracion,
        interprete,
        EntradaModelo.crear(configuracion.entrada, interprete),
        SalidaModelo(configuracion.salida, interprete),
      );
    } catch (e) {
      interprete.close();
      throw StateError(
        "El modelo '${configuracion.id}' no coincide con su configuración: $e",
      );
    }
  }

  Future<ResultadoClasificacion> clasificar(SegmentoAudio segmento) async {
    final entradas = await entrada.preparar(segmento);

    // Promedio de probabilidades sobre todas las ventanas del segmento.
    final suma = <String, double>{};
    for (final datos in entradas) {
      final buffer = salida.crearBuffer();
      try {
        interprete.run(datos, buffer);
      } catch (e) {
        throw StateError('Fallo en la inferencia del modelo: $e');
      }
      salida.interpretar(buffer).forEach((etiqueta, p) {
        suma[etiqueta] = (suma[etiqueta] ?? 0) + p;
      });
    }

    return ResultadoClasificacion.desdeProbabilidades(
      suma.map((etiqueta, total) => MapEntry(etiqueta, total / entradas.length)),
      versionModelo: configuracion.identificadorVersion,
    );
  }

  void cerrar() => interprete.close();
}
