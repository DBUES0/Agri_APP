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
}