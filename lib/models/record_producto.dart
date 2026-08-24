//record_producto.dart
class Producto {
  final String kproducto;
  final String productoStr;
  final DateTime fecha;
  final String ktipoalbaran; // Vinculado al tipo de documento (Albarán o Gasto)

  Producto({
    required this.kproducto,
    required this.productoStr,
    required this.fecha,
    required this.ktipoalbaran,
  });

  factory Producto.fromJson(Map<String, dynamic> json) {
    return Producto(
      kproducto: json['kproducto'] ?? '',
      productoStr: json['producto_str'] ?? '',
      fecha: json['fecha_dtm'] != null ? DateTime.parse(json['fecha_dtm']) : DateTime.now(),
      ktipoalbaran: json['ktipoalbaran'] ?? '', 
    );
  }

  // Soluciona el error 'undefined_method toJson' en page_carga.dart
  Map<String, dynamic> toJson() => {
        'kproducto': kproducto,
        'producto_str': productoStr,
        'fecha_dtm': fecha.toIso8601String(),
        'ktipoalbaran': ktipoalbaran,
      };
}