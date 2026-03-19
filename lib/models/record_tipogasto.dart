// MODELO: record_tipogasto.dart
class Tipogasto {
  final String ktipogasto;
  final String tipogastoStr;
  final String descripcionStr;
  final DateTime fecha;
  final DateTime? fechaModificacion;
  final String? kagricultor;

  Tipogasto({
    required this.ktipogasto,
    required this.tipogastoStr,
    required this.descripcionStr,
    required this.fecha,
    this.fechaModificacion,
    this.kagricultor,
  });

  factory Tipogasto.fromJson(Map<String, dynamic> json) {
    return Tipogasto(
      ktipogasto: json['ktipogasto'],
      tipogastoStr: json['tipogasto_str'],
      descripcionStr: json['descripcion_str'],
      fecha: DateTime.parse(json['fecha_dtm']),
      fechaModificacion: json['fechamodificacion_dtm'] != null
          ? DateTime.tryParse(json['fechamodificacion_dtm'])
          : null,
      kagricultor: json['kagricultor'],
    );
  }
}
