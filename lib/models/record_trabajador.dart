// MODELO: record_trabajador.dart
class Trabajador {
  final String ktrabajador;
  final String kagricultor;
  final String nombreStr;
  final String? dniStr;
  final String? telefonoStr;
  final String? emailStr;

  Trabajador({
    required this.ktrabajador,
    required this.kagricultor,
    required this.nombreStr,
    this.dniStr,
    this.telefonoStr,
    this.emailStr,
  });

  factory Trabajador.fromJson(Map<String, dynamic> json) {
    return Trabajador(
      ktrabajador: json['ktrabajador'],
      kagricultor: json['kagricultor'],
      nombreStr: json['nombre_str'],
      dniStr: json['dni_str'],
      telefonoStr: json['telefono_str'],
      emailStr: json['email_str'],
    );
  }
  Map<String, dynamic> toJson() => {
        'ktrabajador': ktrabajador,
        'kagricultor': kagricultor,
        'nombre_str': nombreStr,
        'dni_str': dniStr,
        'telefono_str': telefonoStr,
        'email_str': emailStr,
      };
}
