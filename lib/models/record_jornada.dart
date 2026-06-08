class Jornada {
  final String kjornada;
  final String ktrabajador;
  final String kagricultor;
  final DateTime fechaDtm;
  final String? observacionesStr;
  final double? horasFlt;
  final String? horarioStr;
  final int eliminadoBit;

  Jornada({
    required this.kjornada,
    required this.ktrabajador,
    required this.kagricultor,
    required this.fechaDtm,
    this.observacionesStr,
    this.horasFlt,
    this.horarioStr,
    this.eliminadoBit = 0,
  });

  factory Jornada.fromJson(Map<String, dynamic> json) {
    return Jornada(
      kjornada: json['kjornada'] ?? '',
      ktrabajador: json['ktrabajador'] ?? '',
      kagricultor: json['kagricultor'] ?? '',
      fechaDtm: DateTime.parse(json['fecha_dtm']),
      observacionesStr: json['observaciones_str'],
      horasFlt: (json['horas_flt'] != null) ? double.tryParse(json['horas_flt'].toString()) : null,
      horarioStr: json['horario_str'],
      eliminadoBit: int.tryParse(json['eliminado_bit'].toString()) ?? 0,
    );
  }
}