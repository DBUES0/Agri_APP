
class finca {
  final String kfinca;
  final String kfincapadre;
  final String nombreStr;
  final String descripcionStr;
  final String kagricultor;
  final String ubicacionStr;
  final double aream2Flt;
  final String campo1Str;
  final String campo2Str;
  final DateTime fecha;
  final DateTime fechaultimouso;
  
  finca({
    required this.kfinca,
    required this.kfincapadre,
    required this.nombreStr,
    required this.descripcionStr,
    required this.kagricultor,
    required this.ubicacionStr,
    required this.aream2Flt,
    required this.campo1Str,
    required this.campo2Str,
    required this.fecha,
    required this.fechaultimouso
  });

  factory finca.fromJson(Map<String, dynamic> json) {
    return finca(
      kfinca: json['kfinca'] ?? '',
      kfincapadre: json['kfincapadre'] ?? '',
      nombreStr: json['nombre_str'] ?? '',
      descripcionStr: json['descripcion_str'] ?? '',
      kagricultor: json['kagricultor'] ?? '',
      ubicacionStr: json['ubicacion_str'] ?? '',
      //aream2Flt: json['aream2_float'] ?? 0,
      aream2Flt: (json['aream2_float'] is int)
        ? (json['aream2_float'] as int).toDouble()
        : (json['aream2_float'] ?? 0.0),
      campo1Str: json['campo1_str'] ?? '',
      campo2Str: json['campo2_str'] ?? '',
      fecha: DateTime.tryParse(json['fecha'] ?? '') ?? DateTime.now(),
      fechaultimouso: DateTime.tryParse(json['fechaultimouso_dtm'] ?? '') ?? DateTime.now(),
    );
  }

Map<String, dynamic> toJson() => {
    'kfinca': kfinca,
    'kfincapadre': kfincapadre,
    'nombre_str': nombreStr,
    'descripcion_str': descripcionStr,
    'kagricultor': kagricultor,
    'ubicacion_str': ubicacionStr,
    'aream2_float': aream2Flt,    
    'campo1_str': campo1Str,
    'campo2_str': campo2Str,
    'fecha': fecha.toIso8601String(),
    'fechaultimouso_dtm': fechaultimouso.toIso8601String(), 
    // Asegúrate de poner AQUÍ todos los campos que tiene el modelo
  };
  @override
  String toString() {
    return 'Finca(nombre: $nombreStr, descripcion: $descripcionStr, ubicación: $ubicacionStr, área: $aream2Flt m2)';
  }
}

/*
select tf.kfinca, tf.nombre_str, max(tad.fecha_dtm) as fechaultimouso,tf.kagricultor
from tblfinca tf inner join tblalbarandetalle tad on tf.kfinca = tad.kfinca
group by tf.kfinca
, tf.nombre_str, tf.kagricultor
order by fechaultimouso desc
*/