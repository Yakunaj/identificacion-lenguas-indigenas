import 'resultado_fragmento.dart';

class GrabacionCompleta {
  final String id;              
  final DateTime fecha;
  final List<ResultadoFragmento> cortes; 

  GrabacionCompleta({
    required this.id,
    required this.fecha,
    required this.cortes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'fecha': fecha.toIso8601String(), // Las fechas se guardan obligatoriamente como Texto
    'cortes': cortes.map((corte) => corte.toJson()).toList(), // Convierte la lista de fragmentos
  };

  factory GrabacionCompleta.fromJson(Map<String, dynamic> json) {
    return GrabacionCompleta(
      id: json['id'] as String,
      fecha: DateTime.parse(json['fecha'] as String), // Convierte el texto de vuelta a fecha real
      // Esta línea suele fallar si no se castea correctamente como Lista:
      cortes: (json['cortes'] as List<dynamic>)
          .map((corteJson) => ResultadoFragmento.fromJson(Map<String, dynamic>.from(corteJson)))
          .toList(),
    );
  }

}