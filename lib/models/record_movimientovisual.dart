import '../models/record_albaran.dart';

class MovimientoVisual {
  final String idFinca;
  final String nombreFinca;
  final String idProducto;
  final String nombreProducto;
  final String idAlmacen;
  final String nombreAlmacen;
  final DateTime fecha;
  final double kg;
  final double rendimientoM2;
  final Albaran albaranPadre;
  final AlbaranDetalle detalleOriginal;

  MovimientoVisual({
    required this.idFinca,
    required this.nombreFinca,
    required this.idProducto,
    required this.nombreProducto,
    required this.idAlmacen,
    required this.nombreAlmacen,
    required this.fecha,
    required this.kg,
    required this.rendimientoM2,
    required this.albaranPadre,
    required this.detalleOriginal,
  });
}