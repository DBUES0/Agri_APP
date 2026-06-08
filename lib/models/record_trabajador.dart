// lib/models/record_trabajador.dart

class Trabajador {
  final String ktrabajador;
  final String kagricultor;
  final String nombreStr;
  final String? dniStr;
  final String? telefonoStr;
  final String? emailStr;
  final int eliminadoBit;
  final DateTime? fechaeliminacionDtm;
  final DateTime? fechainicioultimocontratoDtm;
  final DateTime? fechafinultimocontratoDtm;

  Trabajador({
    required this.ktrabajador,
    required this.kagricultor,
    required this.nombreStr,
    this.dniStr,
    this.telefonoStr,
    this.emailStr,
    this.eliminadoBit = 0,
    this.fechaeliminacionDtm,
    this.fechainicioultimocontratoDtm,
    this.fechafinultimocontratoDtm,
  });

  factory Trabajador.fromJson(Map<String, dynamic> json) {
    return Trabajador(
      ktrabajador: json['ktrabajador'] ?? '',
      kagricultor: json['kagricultor'] ?? '',
      nombreStr: json['nombre_str'] ?? 'Sin nombre',
      dniStr: json['dni_str'],
      telefonoStr: json['telefono_str'],
      emailStr: json['email_str'],
      eliminadoBit: int.tryParse(json['eliminado_bit'].toString()) ?? 0,
      fechaeliminacionDtm: json['fechaeliminacion_dtm'] != null ? DateTime.tryParse(json['fechaeliminacion_dtm']) : null,
      fechainicioultimocontratoDtm: json['fechainicioultimocontrato_dtm'] != null ? DateTime.tryParse(json['fechainicioultimocontrato_dtm']) : null,
      fechafinultimocontratoDtm: json['fechafinultimocontrato_dtm'] != null ? DateTime.tryParse(json['fechafinultimocontrato_dtm']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ktrabajador': ktrabajador,
      'kagricultor': kagricultor,
      'nombre_str': nombreStr,
      'dni_str': dniStr,
      'telefono_str': telefonoStr,
      'email_str': emailStr,
      'eliminado_bit': eliminadoBit,
    };
  }
}