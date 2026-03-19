class Albaran {
  final String kalbaran;
  final DateTime fecha;
  final String kalmacen;
  final String? ktipodeprecio;
  final String? comentarioStr;
  final String? idalbaranstr;
  final List<AlbaranDetalle> detalles;
  final List<Archivo> archivos;

  Albaran({
    required this.kalbaran,
    required this.fecha,
    required this.kalmacen,
    this.ktipodeprecio,
    this.comentarioStr,
    this.idalbaranstr,
    required this.detalles,
    required this.archivos,
  });

factory Albaran.fromJson(Map<String, dynamic> json) {
    return Albaran(
      kalbaran: json['kalbaran'] ?? '',
      fecha: DateTime.parse(json['fecha_dtm'] ?? DateTime.now().toIso8601String()),
      kalmacen: json['kalmacen'] ?? '',
      ktipodeprecio: json['ktipodeprecio'],
      comentarioStr: json['comentario_str'],
      idalbaranstr: json['idalbaran_str'],
      // Protegemos las listas por si vienen nulas desde PHP
      detalles: (json['detalles'] as List?)
              ?.map((item) => AlbaranDetalle.fromJson(item))
              .toList() ?? [],
      archivos: (json['archivos'] as List?)
              ?.map((item) => Archivo.fromJson(item))
              .toList() ?? [],
    );
  }
}

class AlbaranDetalle {
  String kalbarandetalle;
  String kalbaran;
  int linea;
  double kg;
  int pallets;
  int cajas;
  double? precio;
  String kproducto;
  String? comentario;
  int eliminado;
  String? fechaeliminacion;
  String kagricultor;
  String kfinca;

  AlbaranDetalle({
    required this.kalbarandetalle,
    required this.kalbaran,
    required this.linea,
    required this.kg,
    required this.pallets,
    required this.cajas,
    this.precio,
    required this.kproducto,
    this.comentario,
    required this.eliminado,
    this.fechaeliminacion,
    required this.kagricultor,
    required this.kfinca,
  });

factory AlbaranDetalle.fromJson(Map<String, dynamic> json) {
    return AlbaranDetalle(
      kalbarandetalle: json['kalbarandetalle'] ?? '',
      kalbaran: json['kalbaran'] ?? '',
      linea: json['linea_int'] ?? 0, // <--- Seguro anti-nulos
      kg: json['kg_float'] != null ? (json['kg_float'] as num).toDouble() : 0.0,
      pallets: json['numeropallets_int'] ?? 0, // <--- Seguro anti-nulos
      cajas: json['numerocajas_int'] ?? 0, // <--- Seguro anti-nulos
      precio: json['precio_flt'] != null ? (json['precio_flt'] as num).toDouble() : null,
      kproducto: json['kproducto'] ?? '',
      comentario: json['comentario_str'],
      eliminado: json['eliminado_bit'] ?? 0, // <--- Seguro anti-nulos
      fechaeliminacion: json['fechaeliminacion_dtm'],
      kagricultor: json['kagricultor'] ?? '',
      kfinca: json['kfinca'] ?? '',
    );
  }
}

class Archivo {
  final String karchivos;
  final String kagricultor;
  final String kuuid;
  final int    orden;
  final DateTime fecha;
  final String formato;
  final double? sizemb;
  final String? comentario;
  final String nombrearchivo;
  final String? rutacompleta;
  final String? campo1;
  final String tipo;
  int    eliminado;

  Archivo({
    required this.karchivos,
    required this.kagricultor,
    required this.kuuid,
    required this.orden,
    required this.fecha,
    required this.formato,
    this.sizemb,
    this.comentario,
    required this.nombrearchivo,
    this.rutacompleta,
    this.campo1,
    required this.tipo,
    this.eliminado = 0, // Valor por defecto para eliminado
  });

factory Archivo.fromJson(Map<String, dynamic> json) {
    return Archivo(
      karchivos: json['karchivos'] ?? '',
      kagricultor: json['kagricultor'] ?? '',
      kuuid: json['kuuid'] ?? '',
      orden: json['orden_int'] ?? 0, // <--- Seguro anti-nulos
      fecha: DateTime.tryParse(json['fecha_dtm'] ?? '') ?? DateTime.now(),
      formato: json['formato_str'] ?? '',
      sizemb: json['sizemb_flt'] != null ? (json['sizemb_flt'] as num).toDouble() : null,
      comentario: json['comentario_str'],
      nombrearchivo: json['nombrearchivo_str'] ?? '',
      rutacompleta: json['rutacompleta_str'],
      campo1: json['campo1_str'],
      tipo: json['tipo_str'] ?? '',
      eliminado: json['eliminado_bit'] ?? 0, // <--- Seguro anti-nulos
    );
  }

  
}
