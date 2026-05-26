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
import '../pages/page_dashboard.dart'; 
import 'package:sqflite/sqflite.dart';
import '../services/api_service.dart'; 
import '../utils/app_palette.dart';
import '../utils/ui_utils.dart';

class UsuarioPage extends StatefulWidget {
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
  State<UsuarioPage> createState() => _UsuarioPageState();
}

class _UsuarioPageState extends State<UsuarioPage> {
  final ApiService _apiService = ApiService();

  final Map<String, String> _opcionesOrdenacion = {
    "finca,cultivo,fecha": "Finca > Cultivo > Fecha",
    "cultivo,finca,fecha": "Cultivo > Finca > Fecha",
    "almacen,cultivo,finca,fecha": "Almacén > Cultivo > Finca > Fecha",
    "almacen,finca,fecha": "Almacén > Finca > Fecha",
    "fecha,cultivo,finca": "Fecha > Cultivo > Finca",
    "Fecha,finca,cultivo": "Fecha > Finca > Cultivo",
  };

  String? _prefAlbaranes;
  String? _prefGastos;

  @override
  void initState() {
    super.initState();
    _prefAlbaranes = widget.usuario.prefAgrupacion.isEmpty ? "finca,cultivo,fecha" : widget.usuario.prefAgrupacion;
    _prefGastos = widget.usuario.prefAgrupacionGastos.isEmpty ? "almacen,cultivo,fecha" : widget.usuario.prefAgrupacionGastos;

    if (!_opcionesOrdenacion.containsKey(_prefAlbaranes)) _prefAlbaranes = "finca,cultivo,fecha";
    if (!_opcionesOrdenacion.containsKey(_prefGastos)) _prefGastos = "almacen,cultivo,fecha";
  }

  // --- BOTÓN CANCELAR: Regresa al Dashboard con los datos originales (Sin Salvar) ---
  void _volverSinGuardar() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DashboardPage(
          usuario: widget.usuario, // Enviamos el usuario original intacto
          fincas: widget.fincas,
          tiposGasto: widget.tiposGasto,
          almacen: widget.almacen,
          producto: widget.producto,
          tipodeprecio: widget.tipodeprecio,
          tipooperacion: widget.tipooperacion,
          trabajador: widget.trabajador,
          albaranes: widget.albaranes,
        ),
      ),
    );
  }

  // Future<void> _guardarCambiosYContinuar() async {
  //   try {
  //     final Map<String, dynamic> datosModificados = {
  //       'pref_agrupacion_str': _prefAlbaranes,
  //       'pref_agrupacion_gastos_str': _prefGastos,
  //     };

  //     // CORRECCIÓN CRÍTICA: Cambiado 'tblagricultores' a 'tblAgricultores' (Respeta Mayúsculas en Linux)
  //     await _apiService.putGeneric('tblAgricultores', widget.usuario.dni, datosModificados);

  //     final usuarioActualizado = Usuario(
  //       nombre: widget.usuario.nombre,
  //       apellidos: widget.usuario.apellidos,
  //       dni: widget.usuario.dni,
  //       direccion: widget.usuario.direccion,
  //       email: widget.usuario.email,
  //       telefono: widget.usuario.telefono,
  //       validado: widget.usuario.validado,
  //       bloqueado: widget.usuario.bloqueado,
  //       intentos: widget.usuario.intentos,
  //       ultimoIntento: widget.usuario.ultimoIntento,
  //       tipoUsuario: widget.usuario.tipoUsuario,
  //       prefAgrupacion: _prefAlbaranes ?? 'finca,cultivo,fecha',
  //       prefAgrupacionGastos: _prefGastos ?? 'almacen,cultivo,fecha',
  //     );

  //     if (!mounted) return;
  //     mensajeEmergente(context, 'Preferencias actualizadas');

  //     Navigator.pushReplacement(
  //       context,
  //       MaterialPageRoute(
  //         builder: (context) => DashboardPage(
  //           usuario: usuarioActualizado, 
  //           fincas: widget.fincas,
  //           tiposGasto: widget.tiposGasto,
  //           almacen: widget.almacen,
  //           producto: widget.producto,
  //           tipodeprecio: widget.tipodeprecio,
  //           tipooperacion: widget.tipooperacion,
  //           trabajador: widget.trabajador,
  //           albaranes: widget.albaranes,
  //         ),
  //       ),
  //     );
  //   } catch (e) {
  //     mensajeEmergente(context, 'Error al guardar configuración: $e', tipo: 'error');
  //   }
  // }

// Future<void> _guardarCambiosYContinuar() async {
//     try {
// final Map<String, dynamic> datosModificados = {
//         'pref_agrupacion_str': _prefAlbaranes,
//         'pref_agrupacion_gastos_str': _prefGastos,
//       };

//       // 1. BLINDAJE DE ID: Si el usuario no tiene el kagricultor en caché, lo extraemos de su primera finca.
//       String idAgricultor = widget.usuario.kagricultor;
//       if (idAgricultor.isEmpty && widget.fincas.isNotEmpty) {
//         idAgricultor = widget.fincas.first.kagricultor; 
//       }

//       // 2. CORRECCIÓN DE RUTA: Apuntamos a la tabla en singular (estándar de tu API) con el ID garantizado.
//       await _apiService.putGeneric('tblagricultor', idAgricultor, datosModificados);

//       // Creamos el clon actualizado para el Dashboard
//       final usuarioActualizado = Usuario(
//         kagricultor: widget.usuario.kagricultor, // Conservamos el UUID
//         nombre: widget.usuario.nombre,
//         apellidos: widget.usuario.apellidos,
//         dni: widget.usuario.dni,
//         direccion: widget.usuario.direccion,
//         email: widget.usuario.email,
//         telefono: widget.usuario.telefono,
//         validado: widget.usuario.validado,
//         bloqueado: widget.usuario.bloqueado,
//         intentos: widget.usuario.intentos,
//         ultimoIntento: widget.usuario.ultimoIntento,
//         tipoUsuario: widget.usuario.tipoUsuario,
//         prefAgrupacion: _prefAlbaranes ?? 'finca,cultivo,fecha',
//         prefAgrupacionGastos: _prefGastos ?? 'almacen,cultivo,fecha',
//       );

//       if (!mounted) return;
//       mensajeEmergente(context, 'Preferencias actualizadas');

//       // Volvemos al Dashboard con los datos en orden
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(
//           builder: (context) => DashboardPage(
//             usuario: usuarioActualizado, 
//             fincas: widget.fincas,
//             tiposGasto: widget.tiposGasto,
//             almacen: widget.almacen,
//             producto: widget.producto,
//             tipodeprecio: widget.tipodeprecio,
//             tipooperacion: widget.tipooperacion,
//             trabajador: widget.trabajador,
//             albaranes: widget.albaranes,
//           ),
//         ),
//       );
//     } catch (e) {
//       // Si hay un error de red (como el SocketException de DuckDNS), saltará aquí
//       print("Error detallado al guardar: $e");
//       mensajeEmergente(context, 'Error al guardar configuración: $e', tipo: 'error');
//     }
//   }

Future<void> _guardarCambiosYContinuar() async {
    try {
      final Map<String, dynamic> datosModificados = {
        'pref_agrupacion_str': _prefAlbaranes,
        'pref_agrupacion_gastos_str': _prefGastos,
      };

      String idAgricultor = widget.usuario.kagricultor;
      if (idAgricultor.isEmpty && widget.fincas.isNotEmpty) {
        idAgricultor = widget.fincas.first.kagricultor; 
      }

      // CORRECCIÓN DE ENRUTAMIENTO EN PHP:
      // Apuntamos al endpoint unificado /api/editar/ o pasamos el esquema exacto que espera tu router.
      // Si putGeneric internamente ya añade el prefijo "editar/", asegúrate de que el nombre de la tabla sea exacto.
      await _apiService.putGeneric('tblAgricultores', idAgricultor, datosModificados);

      final usuarioActualizado = Usuario(
        kagricultor: idAgricultor,
        nombre: widget.usuario.nombre,
        apellidos: widget.usuario.apellidos,
        dni: widget.usuario.dni,
        direccion: widget.usuario.direccion,
        email: widget.usuario.email,
        telefono: widget.usuario.telefono,
        validado: widget.usuario.validado,
        bloqueado: widget.usuario.bloqueado,
        intentos: widget.usuario.intentos,
        ultimoIntento: widget.usuario.ultimoIntento,
        tipoUsuario: widget.usuario.tipoUsuario,
        prefAgrupacion: _prefAlbaranes ?? 'finca,cultivo,fecha',
        prefAgrupacionGastos: _prefGastos ?? 'almacen,cultivo,fecha',
      );

      if (!mounted) return;
      mensajeEmergente(context, 'Preferencias actualizadas');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardPage(
            usuario: usuarioActualizado, 
            fincas: widget.fincas,
            tiposGasto: widget.tiposGasto,
            almacen: widget.almacen,
            producto: widget.producto,
            tipodeprecio: widget.tipodeprecio,
            tipooperacion: widget.tipooperacion,
            trabajador: widget.trabajador,
            albaranes: widget.albaranes,
          ),
        ),
      );
    } catch (e) {
      print("Error detallado al guardar: $e");
      mensajeEmergente(context, 'Error al guardar configuración: $e', tipo: 'error');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración del Perfil'),
        // Añadimos botón físico de escape en la esquina superior izquierda
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _volverSinGuardar,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text('Nombre: ${widget.usuario.nombre}', style: const TextStyle(fontSize: 16)),
            Text('Apellidos: ${widget.usuario.apellidos}', style: const TextStyle(fontSize: 16)),
            Text('DNI: ${widget.usuario.dni}'),
            Text('Dirección: ${widget.usuario.direccion}'),
            Text('Email: ${widget.usuario.email}'),
            Text('Teléfono: ${widget.usuario.telefono}'),
            Text('Tipo Usuario: ${widget.usuario.tipoUsuario}'),
            
            const SizedBox(height: 30),
            Text(
              'Preferencias de Organización', 
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AgriPalette.greenMain)
            ),
            const Divider(),
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: _prefAlbaranes,
              decoration: const InputDecoration(
                labelText: 'Estructura de Albaranes (Ingresos)',
                border: OutlineInputBorder(),
              ),
              items: _opcionesOrdenacion.entries.map((e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value),
              )).toList(),
              onChanged: (v) => setState(() => _prefAlbaranes = v),
            ),

            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              value: _prefGastos,
              decoration: const InputDecoration(
                labelText: 'Estructura de Gastos (Egresos)',
                border: OutlineInputBorder(),
              ),
              items: _opcionesOrdenacion.entries.map((e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value),
              )).toList(),
              onChanged: (v) => setState(() => _prefGastos = v),
            ),

            const SizedBox(height: 40),
            
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AgriPalette.greenMain,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _guardarCambiosYContinuar,
              child: const Text(
                'GUARDAR Y CONTINUAR', 
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
              ),
            ),
            
            const SizedBox(height: 10),
            
            // Botón explícito de Cancelar para salir sin alterar la nube
            TextButton(
              onPressed: _volverSinGuardar,
              child: Text(
                'CANCELAR Y SALIR',
                style: TextStyle(color: AgriPalette.greyMain.withValues(alpha: 0.8), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}