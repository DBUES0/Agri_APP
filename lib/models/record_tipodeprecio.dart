// MODELO: record_tipodeprecio.dart
class Tipodeprecio {
  final String ktipodeprecio;
  final String tipodeprecioStr;
  final String descripcionStr;
  final DateTime fecha;
  final String kagricultor;

  Tipodeprecio({
    required this.ktipodeprecio,
    required this.tipodeprecioStr,
    required this.descripcionStr,
    required this.fecha,
    required this.kagricultor,
  });

  factory Tipodeprecio.fromJson(Map<String, dynamic> json) {
    return Tipodeprecio(
      ktipodeprecio: json['ktipodeprecio'],
      tipodeprecioStr: json['tipodeprecio_str'],
      descripcionStr: json['descripcion_str'],
      fecha: DateTime.parse(json['fecha_dtm']),
      kagricultor: json['kagricultor'],
    );
  }
}
