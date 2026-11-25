class ResultadoFragmento {
  final int numero; // Bloque 1, Bloque 2, etc.
  final String idioma;
  final double confianza;

  ResultadoFragmento({
    required this.numero,
    required this.idioma,
    required this.confianza,
  });
  // Convierte el objeto a un Mapa (estructura que SharedPreferences puede entender)
  Map<String, dynamic> toJson() => {
    'bloqueNumero': numero,
    'idioma': idioma,
    'confianza': confianza,
  };

  // Crea el objeto a partir de un Mapa (cuando se lee del disco duro)
  factory ResultadoFragmento.fromJson(Map<String, dynamic> json) {
    return ResultadoFragmento(
      // Usamos "as int" y "as double" para asegurar que Dart no se confunda con los tipos
      numero: json['bloqueNumero'] as int,
      idioma: json['idioma'] as String,
      // num es una solución de seguridad por si Kotlin manda el número entero o con decimales
      confianza: (json['confianza'] as num).toDouble(),
    );
  }
}




