// MODELO: record_producto.dart
class Producto {
  final String kproducto;
  final String productoStr;
  final DateTime fecha;
  final String ktipoproducto;
  final String tipoproductoStr;
  
  Producto({
    required this.kproducto,
    required this.productoStr,
    required this.fecha,
    required this.ktipoproducto,
    required this.tipoproductoStr,
  });

  // factory Producto.fromJson(Map<String, dynamic> json) {
  //   return Producto(
  //     kproducto: json['kproducto'],
  //     productoStr: json['producto_str'],
  //     fecha: DateTime.parse(json['fecha_dtm']),
  //     ktipoproducto: json['ktipoproducto'],
  //     tipoproductoStr: json['tipoproducto_str'],
  //   );
  // }

  // En record_producto.dart
factory Producto.fromJson(Map<String, dynamic> json) {
  return Producto(
    kproducto: json['kproducto'] ?? '',
    productoStr: json['producto_str'] ?? 'Sin nombre',
    // Si la fecha falla, ponemos la de hoy
    fecha: DateTime.tryParse(json['fecha_dtm'] ?? '') ?? DateTime(1980,1,1),
    // IMPORTANTE: Asegúrate de que el nombre coincide con el SELECT de tu PHP
    ktipoproducto: json['ktipoproducto'] ?? json['ktipoalbaran'] ?? '', 
    tipoproductoStr: json['tipoproducto_str'] ?? 'General',
  );
}

Map<String, dynamic> toJson() => {
  'kproducto': kproducto,
  'producto_str': productoStr,
  'fecha_dtm': fecha.toIso8601String(),
  'ktipoproducto': ktipoproducto,
  'tipoproducto_str': tipoproductoStr,
};

}