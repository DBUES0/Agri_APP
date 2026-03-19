import 'package:flutter/material.dart';
import '../models/record_usuario.dart';
import '../models/record_finca.dart';
import '../models/record_almacen.dart';
import '../models/record_producto.dart';
import '../models/record_tipodeprecio.dart';
import '../models/record_tipogasto.dart';
import '../models/record_tipooperacion.dart';
import '../models/record_trabajador.dart';
import '../models/record_albaran.dart';
import '../pages/page_dashboard.dart'; // <-- IMPORTANTE

class UsuarioPage extends StatelessWidget {
  final Usuario usuario;
  final List<finca> fincas;
  final List<Tipogasto> tiposGasto;
  final List<Almacen> almacen;
  final List<Producto> producto;
  final List<Tipodeprecio> tipodeprecio;
  final List<Tipooperacion> tipooperacion;
  final List<Trabajador> trabajador;
  final List<Albaran> albaranes;

  const UsuarioPage({
    Key? key,
    required this.usuario,
    required this.fincas,
    required this.tiposGasto,
    required this.almacen,
    required this.producto,
    required this.tipodeprecio,
    required this.tipooperacion,
    required this.trabajador,
    required this.albaranes,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Datos del Usuario')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text('Nombre: ${usuario.nombre}'),
            Text('Apellidos: ${usuario.apellidos}'),
            Text('DNI: ${usuario.dni}'),
            Text('Dirección: ${usuario.direccion}'),
            Text('Email: ${usuario.email}'),
            Text('Teléfono: ${usuario.telefono}'),
            Text('Validado: ${usuario.validado ? 'Sí' : 'No'}'),
            Text('Bloqueado: ${usuario.bloqueado ? 'Sí' : 'No'}'),
            Text('Intentos Fallidos: ${usuario.intentos}'),
            Text('Último intento: ${usuario.ultimoIntento}'),
            Text('Tipo Usuario: ${usuario.tipoUsuario}'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DashboardPage(
                      usuario: usuario,
                      fincas: fincas,
                      tiposGasto: tiposGasto,
                      almacen: almacen,
                      producto: producto,
                      tipodeprecio: tipodeprecio,
                      tipooperacion: tipooperacion,
                      trabajador: trabajador,
                      albaranes: albaranes,
                    ),
                  ),
                );
              },
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }
}
