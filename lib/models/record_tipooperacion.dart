// MODELO: record_tipooperacion.dart
class Tipooperacion {
  final String ktipooperacion;
  final String tipooperacionStr;
  final String descripcionStr;
  final DateTime fecha;
  final DateTime? fechaModificacion;
  final String? kagricultor;

  Tipooperacion({
    required this.ktipooperacion,
    required this.tipooperacionStr,
    required this.descripcionStr,
    required this.fecha,
    this.fechaModificacion,
    this.kagricultor,
  });

  factory Tipooperacion.fromJson(Map<String, dynamic> json) {
    return Tipooperacion(
      ktipooperacion: json['ktipooperacion'],
      tipooperacionStr: json['tipooperacion_str'],
      descripcionStr: json['descripcion_str'],
      fecha: DateTime.parse(json['fecha_dtm']),
      fechaModificacion: json['fechamodificacion_dtm'] != null
          ? DateTime.tryParse(json['fechamodificacion_dtm'])
          : null,
      kagricultor: json['kagricultor'],
    );
  }
  Map<String, dynamic> toJson() => {
        'ktipooperacion': ktipooperacion,
        'tipooperacion_str': tipooperacionStr,
        'descripcion_str': descripcionStr,
        'fecha_dtm': fecha.toIso8601String(),
        'fechamodificacion_dtm':
            fechaModificacion?.toIso8601String(), // Puede ser null
        'kagricultor': kagricultor,
      };
}
