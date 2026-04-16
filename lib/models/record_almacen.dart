// MODELO: record_almacen.dart
class Almacen {
  final String kalmacen;
  final String nombreStr;
  final String? ktipoalbaran; // <--- NUEVO CAMPO AÑADIDO
  final DateTime fecha;
  final String kagricultor;

  Almacen({
    required this.kalmacen,
    required this.nombreStr,
    required this.ktipoalbaran, // <--- REQUERIDO EN CONSTRUCTOR
    required this.fecha,
    required this.kagricultor,
  });

  factory Almacen.fromJson(Map<String, dynamic> json) {
    return Almacen(
      kalmacen: json['kalmacen'],
      nombreStr: json['nombre_str'],
      ktipoalbaran: json['ktipoalbaran'] ?? '', // <--- MAPEO DESDE JSON
      fecha: DateTime.parse(json['fecha_dtm']),
      kagricultor: json['kagricultor'],
    );
  }
  Map<String, dynamic> toJson() => {
    'kalmacen': kalmacen,
    'nombre_str': nombreStr,
    'ktipoalbaran': ktipoalbaran, // <--- INCLUIDO EN toJson
    'fecha_dtm': fecha.toIso8601String(),
    'kagricultor': kagricultor,
  };
}