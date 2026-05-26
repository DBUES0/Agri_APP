import 'dart:convert';

import 'package:agriapp/pages/page_usuario.dart';
import 'package:agriapp/services/db_service.dart';
import 'package:agriapp/services/sync_service.dart';
import 'package:agriapp/utils/ui_utils.dart';
import 'package:agriapp/widgets/icono_sync.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:agriapp/utils/app_theme.dart';
import 'package:agriapp/utils/app_palette.dart';

// Importación de todos los modelos (Records) que definen la estructura de los datos
import '../models/record_usuario.dart';
import '../models/record_finca.dart';
import '../models/record_almacen.dart';
import '../models/record_producto.dart';
import '../models/record_tipodeprecio.dart';
import '../models/record_tipogasto.dart';
import '../models/record_tipooperacion.dart';
import '../models/record_trabajador.dart';
import '../models/record_albaran.dart';
import '../models/record_movimientovisual.dart';
import '../pages/page_albaran.dart';


/// [DashboardPage] es la pantalla principal tras el login.
/// Recibe por constructor TODA la información cargada inicialmente.
class DashboardPage extends StatefulWidget {
  final Usuario usuario;
  final List<finca> fincas;
  final List<Tipogasto> tiposGasto;
  final List<Almacen> almacen;
  final List<Producto> producto;
  final List<Tipodeprecio> tipodeprecio;
  final List<Tipooperacion> tipooperacion;
  final List<Trabajador> trabajador;
  final List<Albaran> albaranes;

  const DashboardPage({
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
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // Estos Mapas sirven para recordar qué secciones están abiertas (expandidas) o cerradas.
  // La clave (String) es el ID de la finca o albarán, y el valor (bool) es si está abierto.
  final Map<String, bool> _expandedFincas = {};
  final Map<String, bool> _expandedAlbaranes = {};
  
  // Controla si la sección general de Albaranes está abierta o cerrada.
  bool _albaranesExpanded = false;
  bool _albaranes2Expanded = false;
  
  // Lista local de albaranes que podemos refrescar sin salir de la página.
  List<Albaran> _albaranes = [];
  
  // Motor de conexión con la API
  final ApiService _apiService = ApiService();

  // Colores constantes para mantener la estética uniforme.
  static const Color colorAccion = Colors.green;
  static const Color colorEliminar = Colors.red;
  static const Color colorFondo = Colors.white;

  // @override
  // void initState() {
  //   super.initState();
  //   // Al iniciar, cargamos los albaranes que nos pasaron desde el login.
  //   _albaranes = widget.albaranes;
  // }

@override
void initState() {
  super.initState();
  _albaranes = widget.albaranes;

  // --- ESCUCHAMOS AL TRABAJADOR DE FONDO ---
  SyncService.syncStream.listen((finalizadoOk) {
    if (finalizadoOk && mounted) {
      print("SyncService avisa: ¡Cola vacía o registros subidos! Refrescando UI...");
      _refreshAlbaranes(); // Esto actualiza la lista visual con lo que ya está en el servidor
    }
  });
}

Stream<List<Albaran>> _getAlbaranesStream() async* {
  while (true) {
    // 1. Albaranes de la caché (API)
    final localData = await DBService.instance.getAllFromLocal('albaranes');
    List<Albaran> albaranesAPI = localData.map((json) => Albaran.fromJson(json)).toList();

    // 2. Albaranes pendientes de subir (Offline)
    final db = await DBService.instance.database;
    final resPendientes = await db.query('pendientes_sincro', where: 'entidad = ?', whereArgs: ['albaran']);
    
    List<Albaran> albaranesPendientes = resPendientes.map((item) {
      final Map<String, dynamic> datos = jsonDecode(item['datos_json'] as String);
      return Albaran.fromJson(datos);
    }).toList();

    // --- PASO 3 MODIFICADO: Unir y ORDENAR ---
    List<Albaran> listaTotal = [...albaranesPendientes, ...albaranesAPI];
    
    // Ordenamos: b.fecha.compareTo(a.fecha) para que el más reciente esté ARRIBA
    listaTotal.sort((a, b) => b.fecha.compareTo(a.fecha));

    yield listaTotal;

    await Future.delayed(const Duration(seconds: 5));
  }
}
  /// [logout] Borra el token de seguridad del teléfono y vuelve atrás.
  // Future<void> _logout() async {
  //   // final prefs = await SharedPreferences.getInstance();
  //   // await prefs.remove('token');
  //   // Navigator.of(context).pop();
    
  // try {
  //   await SyncService.sincronizarTodo();
  // } catch (e) {
  //   if (e.toString().contains("Expired token")) {
  //     // Si el servicio nos dice que el token murió, cerramos sesión
  //     if (context.mounted) {
  //       await ApiService().cerrarSesion(context);
  //     }
  //   }
  // }

  // }


//   Future<void> _logout() async {
//   // Mostramos un diálogo de confirmación (opcional pero recomendado)
//   bool? confirmar = await showDialog(
//     context: context,
//     builder: (context) => AlertDialog(
//       title: const Text("Cerrar Sesión"),
//       content: const Text("¿Estás seguro de que quieres salir?"),
//       actions: [
//         TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
//         TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Salir", style: TextStyle(color: Colors.red))),
//       ],
//     ),
//   );

//   if (confirmar == true) {
//     await _apiService.cerrarSesion(context);
//   }
// }

Future<void> _logout() async {
  bool? confirmar = await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Text("Cerrar Sesión", 
        style: TextStyle(color: AgriPalette.greenMain, fontWeight: FontWeight.bold)
      ),
      content: const Text("¿Estás seguro de que quieres salir de AgriAPP?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text("CANCELAR", style: TextStyle(color: AgriPalette.greyMain)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AgriPalette.greenMain,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text("SALIR", style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );

  if (confirmar == true) {
    try {
      // Intentamos una última sincro antes de irnos
      await SyncService.sincronizarTodo();
      if (mounted) await _apiService.cerrarSesion(context);
    } catch (e) {
      // Si falla por token, cerramos sesión igualmente
      if (e.toString().contains("Expired token") && mounted) {
        await _apiService.cerrarSesion(context);
      }
    }
  }
}

// Y para la sincronización manual o automática, usamos tu lógica de detección:
Future<void> _intentarSincroManual() async {
  try {
    mensajeEmergente(context, "Comprobando conexión...", tipo: 'info');
    await SyncService.sincronizarTodo();
  } catch (e) {
    if (e.toString().contains("Expired token") || e.toString().contains("401")) {
      mensajeEmergente(context, "Tu sesión ha caducado. Identifícate de nuevo.", tipo: 'error');
      if (mounted) await _apiService.cerrarSesion(context);
    } else {
      mensajeEmergente(context, "Sin conexión o error de red", tipo: 'error');
    }
  }
}


  /// Ejecuta todas las actualizaciones de datos a la vez.
  Future<void> _refreshAll() async {
    await _refreshAlbaranes();
    // await _refreshFincas();
    await _refreshGastos();
    await _refreshOperaciones();
  }

  /// Pide al servidor la lista actualizada de albaranes.
  Future<void> _refreshAlbaranes() async {
          _albaranes = (await _apiService.fetchParticular('albaranesv2'))
          .map((json) => Albaran.fromJson(json)).toList();
     mensajeEmergente(context, 'Albaranes Actualizados', segundos: 1);

  }


  Future<void> _superRefresh() async {
    // 1. Primero intentamos subir lo que haya pendiente
    await SyncService.sincronizarTodo();
    
    // 2. Después bajamos lo último del servidor
    await _refreshAlbaranes();
    
    // 3. El IconoSync se actualizará solo por su Stream interno
    setState(() {}); 
  }

  // Los métodos _refreshGastos y _refreshOperaciones están preparados 
  // para cuando crees sus respectivos endpoints en tu servidor PHP.
  Future<void> _refreshGastos() async {
    mensajeEmergente(context, 'Simulando refresco de Gastos...',segundos: 1 );
    //"Simulando refresco de Gastos...");
  }

  Future<void> _refreshOperaciones() async {
    mensajeEmergente(context, 'Simulando refresco de Operaciones...',segundos: 1);
  }

  /// Lógica para realizar el borrado lógico (marcar como eliminado_bit = 1)
  Future<void> _confirmDeleteAlbaran(String kalbaran) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar Albarán?'),
        content: const Text('Se ocultará el albarán y sus productos asociados.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colorAccion),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar', style: TextStyle(color: colorFondo)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Marcar cabecera como eliminada en la BD
        await _apiService.putGeneric('tblalbaran', kalbaran, {'eliminado_bit': 1});

        // Marcar sus detalles como eliminados en la BD
        final albaranActual = _albaranes.firstWhere((a) => a.kalbaran == kalbaran);
        for (var detalle in albaranActual.detalles) {
          if (detalle.kalbarandetalle.isNotEmpty) {
            await _apiService.putGeneric('tblalbarandetalle', detalle.kalbarandetalle, {'eliminado_bit': 1});
          }
        }

        // Quitar de la lista visual
        setState(() {
          _albaranes.removeWhere((a) => a.kalbaran == kalbaran);
        });
      } catch (e) {
        // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: colorEliminar));
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'), 
              backgroundColor: colorEliminar,
              behavior: SnackBarBehavior.floating, // Hace que flote sobre los botones
              margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20),
            ),
          );
      }
    }
  }

  /// Navega a la pantalla de edición/creación de Albarán.
  void _goToAlbaran({Albaran? albaran}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PageAlbaran(
          almacenes: widget.almacen,
          tiposPrecio: widget.tipodeprecio,
          productos: widget.producto,
          fincas: widget.fincas,
          albaran: albaran,
          albaranesTotales: _albaranes, // Pasamos la lista para calcular el último almacén usado
        ),
      ),
    );

    // Si al volver de la página de albaranes nos devuelve 'true', refrescamos la lista.
    if (result == true) { await _refreshAlbaranes(); }
  }

  /// Navega de vuelta a la ficha del perfil del Agricultor.
  void _goToUsuario() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => UsuarioPage(
            usuario: widget.usuario, 
            fincas: widget.fincas, 
            tiposGasto: widget.tiposGasto, 
            almacen: widget.almacen, 
            producto: widget.producto, 
            tipodeprecio: widget.tipodeprecio, 
            tipooperacion: widget.tipooperacion, 
            trabajador: widget.trabajador, 
            albaranes: widget.albaranes),
      ),
    );
  }

// @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//               centerTitle: false,
//               // En lugar de usar 'leading', ponemos todo en el 'title' 
//               // para que fluya de forma natural hacia la derecha.
//               title: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   AppTheme.buildLogo(fontSize: 22), // El logo mixto
//                   const SizedBox(width: 22),        // Un poco de separación
//                   Expanded(
//                     child: Text(
//                       '${widget.usuario.nombre} ${widget.usuario.apellidos}',
//                       style:  Theme.of(context).textTheme.titleMedium, //const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
//                       overflow: TextOverflow.ellipsis, // Por si el nombre es muy largo
//                     ),
//                   ),
//                 ],
//               ),

//         // 3. ICONOS DE FUNCIÓN A LA DERECHA (se mantienen en actions)
//         actions: [
//           const IconoSync(),
//           IconButton(
//             icon: const Icon(Icons.sync),
//             tooltip: 'Sincronizar', // Ayuda al usuario
//             onPressed: _superRefresh, // _refreshAll,
//           ),
//           IconButton(
//             icon: const Icon(Icons.edit),
//             tooltip: 'Editar Perfil',
//             onPressed: _goToUsuario,
//           ),
//           IconButton(
//             icon: const Icon(Icons.logout),
//             tooltip: 'Cerrar Sesión',
//             onPressed: _logout,
//           ),
//         ],
//       ),
//       body: ListView(
//         padding: const EdgeInsets.all(16),
//         children: [
//           // Sección principal de Albaranes (con cálculos de kilos)
//           //_buildAlbaranesSection(),
//           StreamBuilder<List<Albaran>>(
//               stream: _getAlbaranesStream(),
//               builder: (context, snapshot) {
//                 if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
//                 // Actualizamos nuestra lista interna para que el resto de funciones sigan funcionando
//                 _albaranes = snapshot.data!; 
                
//                 return _buildAlbaranesSection(); // Tu método actual ahora usará la lista combinada
//               },
//             ),
//           _buildAlbaranes2Section(),
//           // Secciones secundarias (TODO: Implementar sus páginas específicas)
//           _buildSection('Gastos', onAdd: () {}),
//           _buildSection('Operaciones', onAdd: () {}),
//           _buildSection('Jornadas', onAdd: () {}, extra: const Text("Último día: 2025/05/19")),
//           _buildSection('Notas', onAdd: () {}),
//         ],
//       ),
//     );
//   }

@override
  Widget build(BuildContext context) {
    // 1. Aplanamos todo
    final todosLosMovimientos = _aplanarMovimientos();

    // 2. SEPARAMOS POR TIPO DE DOCUMENTO
    final ingresos = todosLosMovimientos
        .where((m) => m.albaranPadre.ktipoalbaran == "b42f149b-6744-11f0-ac9b-e2b6c6b4d8df")
        .toList();
        
    final gastos = todosLosMovimientos
        .where((m) => m.albaranPadre.ktipoalbaran == "c4755f6d-6744-11f0-ac9b-e2b6c6b4d8df")
        .toList();

    // 3. CALCULAMOS TOTALES (Kilos para ingresos, Euros para gastos)
    final totalKgIngresos = ingresos.fold<double>(0, (sum, item) => sum + item.kg);
    
    // El gasto total es la suma de (cantidad * precio) de cada línea
    final totalEurosGastos = gastos.fold<double>(0, (sum, item) => sum + (item.kg * (item.detalleOriginal.precio ?? 0.0)));

    return Scaffold(
    appBar: AppBar(
      centerTitle: false,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTheme.buildLogo(fontSize: 22), 
          const SizedBox(width: 22),        
          Expanded(
            child: Text(
              '${widget.usuario.nombre} ${widget.usuario.apellidos}',
              style: Theme.of(context).textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        const IconoSync(),
        IconButton(
          icon: const Icon(Icons.sync),
          tooltip: 'Sincronizar', 
          onPressed: _superRefresh, 
        ),
        IconButton(
          icon: const Icon(Icons.edit),
          tooltip: 'Editar Perfil',
          onPressed: _goToUsuario,
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Cerrar Sesión',
          onPressed: _logout,
        ),
      ],
    ),
    // --- REESTRUCTURACIÓN DE SEGURIDAD ---
    body: StreamBuilder<List<Albaran>>(
      stream: _getAlbaranesStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        // Asignación segura dentro del flujo asíncrono
        _albaranes = snapshot.data!; 
        
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // _buildAlbaranesSection(), // Tarjeta 1 (Original)
            // _buildAlbaranes2Section(), // Tarjeta 2 (Zona de pruebas dinámica)
            // _buildSection(
            //   'Gastos', 
            //   onAdd: () async {
            //     final result = await Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => PageAlbaran(
            //           almacenes: widget.almacen,
            //           tiposPrecio: widget.tipodeprecio,
            //           productos: widget.producto,
            //           fincas: widget.fincas,
            //           albaranesTotales: _albaranes,
            //           // CLAVE: Inyectamos el UUID de Gasto de tu BD para que mute el formulario automáticamente
            //           ktipoalbaran: "c4755f6d-6744-11f0-ac9b-e2b6c6b4d8df", 
            //         ),
            //       ),
            //     );
            //     if (result == true) { _refreshAlbaranes(); }
            //   }
            // ),
            // _buildSection('Gastos', onAdd: () {}),
            _buildSection(
              'Albaranes: ${totalKgIngresos.toStringAsFixed(2)} kg',
              onAdd: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PageAlbaran(
                    almacenes: widget.almacen, tiposPrecio: widget.tipodeprecio,
                    productos: widget.producto, fincas: widget.fincas, albaranesTotales: _albaranes,
                    ktipoalbaran: "b42f149b-6744-11f0-ac9b-e2b6c6b4d8df", // INGRESO
                  )),
                );
                if (result == true) { _refreshAlbaranes(); }
              },
              child: ingresos.isEmpty 
                  ? const Padding(padding: EdgeInsets.all(16), child: Text('No hay ingresos registrados'))
                  // Inyectamos el árbol dinámico de ingresos
                  : _construirNivelDinamicamente(ingresos, widget.usuario.prefAgrupacion.split(','), 0),
            ),

            // --- SECCIÓN: GASTOS (EGRESOS) ---
            _buildSection(
              'Gastos: ${totalEurosGastos.toStringAsFixed(2)} €',
              onAdd: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PageAlbaran(
                    almacenes: widget.almacen, tiposPrecio: widget.tipodeprecio,
                    productos: widget.producto, fincas: widget.fincas, albaranesTotales: _albaranes,
                    ktipoalbaran: "c4755f6d-6744-11f0-ac9b-e2b6c6b4d8df", // GASTO
                  )),
                );
                if (result == true) { _refreshAlbaranes(); }
              },
              child: gastos.isEmpty 
                  ? const Padding(padding: EdgeInsets.all(16), child: Text('No hay gastos registrados'))
                  // Inyectamos el árbol dinámico de GASTOS (usando su propia preferencia)
                  : _construirNivelDinamicamente(gastos, widget.usuario.prefAgrupacionGastos.split(','), 0),
            ),
            _buildSection('Operaciones', onAdd: () {}),
            _buildSection('Jornadas', onAdd: () {}, extra: const Text("Último día: 2025/05/19")),
            _buildSection('Notas', onAdd: () {}),
          ],
        );
      },
    ),
  );
}
  /// [buildAlbaranesSection] es la parte más compleja: calcula totales y agrupa por finca.
  Widget _buildAlbaranesSection() {
    // 1. Extraemos todos los renglones (detalles) de todos los albaranes en una sola lista.
    final detalles = _albaranes.expand((a) => a.detalles);
    
    // 2. Sumamos todos los kilos totales.
    final totalKg = detalles.fold<double>(0, (sum, d) => sum + d.kg);

    // 3. Agrupamos los detalles por Finca (Creamos un mapa donde la clave es el ID de finca).
    final Map<String, List<AlbaranDetalle>> fincaDetalles = {};
    for (var d in detalles) {
      fincaDetalles.putIfAbsent(d.kfinca, () => []).add(d);
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell( // InkWell permite que toda la fila sea pulsable para expandir
    onTap: () => setState(() => _albaranesExpanded = !_albaranesExpanded),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0), // Ajuste fino de altura
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Albaranes (Antiguo): ${totalKg.toStringAsFixed(2)} kg', 
            style: Theme.of(context).textTheme.titleLarge,
          ),
          IconButton(
            icon: const Icon(Icons.add), 
            color: AgriPalette.greenMain, 
            onPressed: () => _goToAlbaran(),
          ),
        ],
      ),
    ),
  ),
            // Cabecera de la sección: Muestra el total de kilos de la explotación.
            // ListTile(
            //   title: Text('Albaranes: ${totalKg.toStringAsFixed(2)} kg', 
            //       //style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            //   style: Theme.of(context).textTheme.titleLarge),
            //   trailing: Row(
            //     mainAxisSize: MainAxisSize.min,
            //     children: [
            //       IconButton(icon: const Icon(Icons.add), color: AgriPalette.greenMain, onPressed: () => _goToAlbaran()),
            //       // IconButton(
            //       //   icon: Icon(_albaranesExpanded ? Icons.expand_less : Icons.expand_more), 
            //       //   onPressed: () => setState(() => _albaranesExpanded = !_albaranesExpanded)
            //       // ),
            //     ],
            //   ),
            //   onTap: () => setState(() => _albaranesExpanded = !_albaranesExpanded),
            // ),
            
            // Si la sección está expandida, mostramos el desglose por Finca
            if (_albaranesExpanded)
              ...fincaDetalles.entries.map((entry) {
                // Buscamos el nombre de la finca usando su ID
                final fincaObj = widget.fincas.firstWhere(
                  (f) => f.kfinca == entry.key,
                  orElse: () => finca(kfinca: '', kfincapadre: '', nombreStr: 'Desconocido', descripcionStr: '', kagricultor: '', ubicacionStr: '', aream2Flt: 0, campo1Str: '', campo2Str: '', fecha: DateTime.now(), fechaultimouso: DateTime.now())
                );

                // Cálculo de Rendimiento: kg totales de la finca / metros cuadrados.
                final fincaKg = entry.value.fold<double>(0, (sum, d) => sum + d.kg);
                final fincaM2 = fincaObj.aream2Flt > 0 ? fincaObj.aream2Flt : 1;
                final kgM2 = fincaKg / fincaM2;
                final isExpanded = _expandedFincas[entry.key] ?? false;

                // Sub-agrupación: Agrupamos los detalles por Albarán dentro de esta finca.
                final albaranMap = <String, List<AlbaranDetalle>>{};
                for (var d in entry.value) {
                  albaranMap.putIfAbsent(d.kalbaran, () => []).add(d);
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título de la Finca con su rendimiento (kg/m²)
                    ListTile(
                      title: Text('${fincaObj.nombreStr} ${fincaKg.toStringAsFixed(0)} kg (${kgM2.toStringAsFixed(1)} kg/m²)', 
                          style:  Theme.of(context).textTheme.titleMedium),//const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      onTap: () => setState(() => _expandedFincas[entry.key] = !isExpanded),
                    ),
                    
                    // Si la finca está expandida, mostramos los albaranes individuales
                    if (isExpanded)
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0),
                        child: Column(
                          children: albaranMap.entries.map((aEntry) {
                            //final albaran = _albaranes.firstWhere((a) => a.kalbaran == aEntry.key);
                            // Buscamos el albarán, pero con un "Plan B" por si no existe
                            final albaran = _albaranes.firstWhere(
                              (a) => a.kalbaran == aEntry.key,
                              orElse: () => Albaran(
                                kalbaran: '', // Marcamos como vacío
                                fecha: DateTime.now(),
                                kalmacen: '',
                                detalles: [],
                                archivos: [],
                                ktipoalbaran: 'b42f149b-6744-11f0-ac9b-e2b6c6b4d8df',
                              ),
                            );

                            // Si el albarán devuelto es el "vacío", saltamos este paso y no pintamos nada
                            if (albaran.kalbaran.isEmpty) return const SizedBox.shrink();
                            final albaranKg = aEntry.value.fold<double>(0, (sum, d) => sum + d.kg);
                            final expanded = _expandedAlbaranes[aEntry.key] ?? false;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  title: Text(
                                            '${albaran.fecha.day.toString().padLeft(2, '0')}/${albaran.fecha.month.toString().padLeft(2, '0')}/${albaran.fecha.year} - ${albaranKg.toStringAsFixed(0)} kg', 
                                            style: Theme.of(context).textTheme.bodyLarge,
                                          ),
                                    trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(icon: const Icon(Icons.edit),  color: AgriPalette.greenMain, onPressed: () => _goToAlbaran(albaran: albaran)),
                                      IconButton(icon: const Icon(Icons.delete),  color: AgriPalette.greenMain, onPressed: () => _confirmDeleteAlbaran(albaran.kalbaran)),
                                    ],
                                  ),
                                  onTap: () => setState(() => _expandedAlbaranes[aEntry.key] = !expanded),
                                ),
                                
                                // Si el albarán está expandido, mostramos los productos específicos de ese día
                                if (expanded)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 16.0),
                                    child: Column(
                                      children: aEntry.value.map((d) {
                                        // Buscamos el producto en la lista que tiene el Dashboard
                                        final producto = widget.producto.firstWhere(
                                          (p) => p.kproducto == d.kproducto,
                                          // Ajustamos el 'orElse' para que coincida con tu nuevo modelo Producto
                                          orElse: () => Producto(
                                            kproducto: '', 
                                            productoStr: 'Desconocido', 
                                            fecha: DateTime.now(),
                                            ktipoalbaran: '', // <--- Corregido el parámetro obligatorio
                                            // ktipoproducto: '',      // <--- Nuevo campo obligatorio
                                            // tipoproductoStr: '',    // <--- Nuevo campo obligatorio
                                          ),
                                        );
                                        
                                        return ListTile(
                                          dense: true,
                                          // Mostramos la línea, el nombre del producto y los kg
                                          title: Text('Línea ${d.linea}: ${producto.productoStr} -> ${d.kg.toStringAsFixed(2)} kg',style:  Theme.of(context).textTheme.bodyMedium,),
                                          // Opcional: Podrías añadir el tipo de producto como subtítulo si quieres
                                          // subtitle: Text(producto.tipoproductoStr, style:  Theme.of(context).textTheme.bodySmall),//const TextStyle(fontSize: 10)),
                                          subtitle: const Text(''),
                                        );
                                      }).toList(),
                                    ),
                                  )
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                );
              })
          ],
        ),
      ),
    );
  }

  /// [buildSection] Crea una tarjeta estándar para Gastos, Operaciones, etc.
Widget _buildSection(String title, {required VoidCallback onAdd, Widget? extra, Widget? child}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                IconButton(icon: const Icon(Icons.add), color: AgriPalette.greenMain, onPressed: onAdd),
              ],
            ),
            if (extra != null) extra, // Si pasamos un widget extra (como la fecha de jornadas).
            if (child != null) child, // AQUÍ SE DIBUJARÁ EL ÁRBOL DINÁMICO.
          ],
        ),
      ),
    );
  }

// ==========================================================================
  // MOTOR DE AGRAUPACIÓN DINÁMICA (ALBARANES 2)
  // ==========================================================================

  /// 1. Aplana la estructura de Albaranes -> Detalles a una lista independiente
List<MovimientoVisual> _aplanarMovimientos() {
    List<MovimientoVisual> listaPlana = [];

    // INDEXACIÓN EXPRESO (O(1)): Convertimos listas a Mapas antes de iterar
    final Map<String, Almacen> mapAlmacenes = {for (var a in widget.almacen) a.kalmacen: a};
    final Map<String, finca> mapFincas = {for (var f in widget.fincas) f.kfinca: f};
    final Map<String, Producto> mapProductos = {for (var p in widget.producto) p.kproducto: p};

    for (var alb in _albaranes) {
      // Búsqueda directa instantánea sin recorrer la lista entera
      final almObj = mapAlmacenes[alb.kalmacen] ?? 
          Almacen(kalmacen: '', nombreStr: 'Sin Almacén', fecha: DateTime.now(), kagricultor: '', ktipoalbaran: '');

      for (var det in alb.detalles) {
        final fincaObj = mapFincas[det.kfinca] ?? 
            finca(kfinca: '', kfincapadre: '', nombreStr: 'Finca Desconocida', descripcionStr: '', kagricultor: '', ubicacionStr: '', aream2Flt: 1, campo1Str: '', campo2Str: '', fecha: DateTime.now(), fechaultimouso: DateTime.now());

        final prodObj = mapProductos[det.kproducto] ?? 
            Producto(kproducto: '', productoStr: 'Desconocido', fecha: DateTime.now(), ktipoalbaran: '');

        final fincaM2 = fincaObj.aream2Flt > 0 ? fincaObj.aream2Flt : 1;

        listaPlana.add(MovimientoVisual(
          idFinca: det.kfinca,
          nombreFinca: fincaObj.nombreStr,
          idProducto: det.kproducto,
          nombreProducto: prodObj.productoStr,
          idAlmacen: alb.kalmacen,
          nombreAlmacen: almObj.nombreStr,
          fecha: alb.fecha,
          kg: det.kg,
          rendimientoM2: det.kg / fincaM2,
          albaranPadre: alb,
          detalleOriginal: det,
        ));
      }
    }
    return listaPlana;
  }

  // List<MovimientoVisual> _aplanarMovimientos() {
  //   List<MovimientoVisual> listaPlana = [];

  //   for (var alb in _albaranes) {
  //     final almObj = widget.almacen.firstWhere(
  //       (a) => a.kalmacen == alb.kalmacen,
  //       orElse: () => Almacen(kalmacen: '', nombreStr: 'Sin Almacén', fecha: DateTime.now(), kagricultor: '', ktipoalbaran: ''),
  //     );

  //     for (var det in alb.detalles) {
  //       final fincaObj = widget.fincas.firstWhere(
  //         (f) => f.kfinca == det.kfinca,
  //         orElse: () => finca(kfinca: '', kfincapadre: '', nombreStr: 'Finca Desconocida', descripcionStr: '', kagricultor: '', ubicacionStr: '', aream2Flt: 1, campo1Str: '', campo2Str: '', fecha: DateTime.now(), fechaultimouso: DateTime.now()),
  //       );

  //      final prodObj = widget.producto.firstWhere(
  //         (p) => p.kproducto == det.kproducto,
  //         orElse: () => Producto(
  //           kproducto: '', 
  //           productoStr: 'Desconocido', 
  //           fecha: DateTime.now(), 
  //           ktipoalbaran: '', // <--- Cambiado al nuevo parámetro obligatorio
  //         ),
  //       );

  //       final fincaM2 = fincaObj.aream2Flt > 0 ? fincaObj.aream2Flt : 1;

  //       listaPlana.add(MovimientoVisual(
  //         idFinca: det.kfinca,
  //         nombreFinca: fincaObj.nombreStr,
  //         idProducto: det.kproducto,
  //         nombreProducto: prodObj.productoStr,
  //         idAlmacen: alb.kalmacen,
  //         nombreAlmacen: almObj.nombreStr,
  //         fecha: alb.fecha,
  //         kg: det.kg,
  //         rendimientoM2: det.kg / fincaM2,
  //         albaranPadre: alb,
  //         detalleOriginal: det,
  //       ));
  //     }
  //   }
  //   return listaPlana;
  // }

  /// 2. Construye la tarjeta contenedora de Albaranes 2
  // Widget _buildAlbaranes2Section() {
  //   final movimientos = _aplanarMovimientos();
  //   final totalKg = movimientos.fold<double>(0, (sum, m) => sum + m.kg);

  //   // Recuperamos tu nueva propiedad del objeto usuario (o un fallback por defecto)
  //   // NOTA: Asegúrate de que el modelo Usuario tenga mapeado 'prefAgrupacionStr'
  //   // String configRaw = widget.usuario.prefAgrupacion ?? "finca,cultivo,fecha";
  //   String configRaw = widget.usuario.prefAgrupacion.isEmpty 
  //       ? "finca,cultivo,fecha" 
  //       : widget.usuario.prefAgrupacion;
  //   List<String> criterios = configRaw.split(',');

  //   return Card(
  //     color: AgriPalette.background.withValues(alpha: 0.5), // Un tono sutilmente diferente para distinguirlo
  //     elevation: 3,
  //     margin: const EdgeInsets.symmetric(vertical: 10),
  //     child: Padding(
  //       padding: const EdgeInsets.all(12.0),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           InkWell(
  //             onTap: () => setState(() => _albaranes2Expanded = !_albaranes2Expanded),
  //             child: Padding(
  //               padding: const EdgeInsets.symmetric(vertical: 8.0),
  //               child: Row(
  //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                 children: [
  //                   Row(
  //                     children: [
  //                       // const Icon(Icons.layers_outlined, color: AgriPalette.greenMain),
  //                       const SizedBox(width: 8),
  //                       Text(
  //                         'ALBARANES: ${totalKg.toStringAsFixed(0)} kg', 
  //                         style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
  //                       ),
  //                     ],
  //                   ),
  //                   IconButton(
  //                     icon: const Icon(Icons.add_box_outlined), 
  //                     color: AgriPalette.greenMain, 
  //                     onPressed: () => _goToAlbaran(),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ),
  //           if (_albaranes2Expanded)
  //             _construirNivelDinamicamente(movimientos, criterios, 0),
  //         ],
  //       ),
  //     ),
  //   );
  // }

/// 2. Construye la tarjeta contenedora de Albaranes 2 (Estética unificada)
  // Widget _buildAlbaranes2Section() {
  //   final movimientos = _aplanarMovimientos();
  //   final totalKg = movimientos.fold<double>(0, (sum, m) => sum + m.kg);

  //   // Salvaguarda contra cadenas vacías desde SQLite/Base de datos
  //   String configRaw = widget.usuario.prefAgrupacion.isEmpty 
  //       ? "finca,cultivo,fecha" 
  //       : widget.usuario.prefAgrupacion;
  //   List<String> criterios = configRaw.split(',');

  //   return Card(
  //     elevation: 2,
  //     margin: const EdgeInsets.symmetric(vertical: 10),
  //     child: Padding(
  //       padding: const EdgeInsets.all(12.0),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           // Cabecera Principal con el formato de texto exacto del original
  //           InkWell(
  //             onTap: () => setState(() => _albaranes2Expanded = !_albaranes2Expanded),
  //             child: Padding(
  //               padding: const EdgeInsets.symmetric(vertical: 8.0),
  //               child: Row(
  //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                 children: [
  //                   Text(
  //                     'Albaranes (Dinámico): ${totalKg.toStringAsFixed(2)} kg', 
  //                     style: Theme.of(context).textTheme.titleLarge,
  //                   ),
  //                   IconButton(
  //                     icon: const Icon(Icons.add), 
  //                     color: AgriPalette.greenMain, 
  //                     onPressed: () => _goToAlbaran(),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ),
  //           if (_albaranes2Expanded)
  //             _construirNivelDinamicamente(movimientos, criterios, 0),
  //         ],
  //       ),
  //     ),
  //   );
  // }


/// 2. Construye la tarjeta contenedora de Albaranes 2 (Estética unificada)
Widget _buildAlbaranes2Section() {
  final movimientos = _aplanarMovimientos();
  final totalKg = movimientos.fold<double>(0, (sum, m) => sum + m.kg);

  String configRaw = widget.usuario.prefAgrupacion.isEmpty 
      ? "finca,cultivo,fecha" 
      : widget.usuario.prefAgrupacion;
  List<String> criterios = configRaw.split(',');

  return Card(
    elevation: 2,
    margin: const EdgeInsets.symmetric(vertical: 10),
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Copiado idéntico del formato estético original
          InkWell( 
            onTap: () => setState(() => _albaranes2Expanded = !_albaranes2Expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0), 
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Albaranes: ${totalKg.toStringAsFixed(2)} kg', 
                      style: Theme.of(context).textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add), 
                    color: AgriPalette.greenMain, 
                    onPressed: () => _goToAlbaran(),
                  ),
                ],
              ),
            ),
          ),
          if (_albaranes2Expanded)
            _construirNivelDinamicamente(movimientos, criterios, 0),
        ],
      ),
    ),
  );
}
  /// 3. Función recursiva encargada de anidar ExpansionTiles dinámicamente
/// 3. Función recursiva de anidamiento limpia (Corrige Crash de Scroll y Estética)
  // Widget _construirNivelDinamicamente(List<MovimientoVisual> datosNodo, List<String> criterios, int indexCriterio) {
  //   // CONDICIÓN TERMINAL: Renderizado de las hojas finales (Líneas de producto)
  //   if (indexCriterio >= criterios.length) {
  //     return Column(
  //       children: datosNodo.map((m) {
  //         return ListTile(
  //           dense: true,
  //           contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
  //           title: Text(
  //             'Línea ${m.detalleOriginal.linea}: ${m.nombreProducto} -> ${m.kg.toStringAsFixed(2)} kg',
  //             style: Theme.of(context).textTheme.bodyMedium,
  //           ),
  //           subtitle: Text(
  //             'Doc: ${m.albaranPadre.idalbaranstr} | Almacén: ${m.nombreAlmacen}',
  //             style: Theme.of(context).textTheme.bodySmall,
  //           ),
  //           trailing: Row(
  //             mainAxisSize: MainAxisSize.min,
  //             children: [
  //               IconButton(
  //                 icon: const Icon(Icons.edit, size: 20, color: AgriPalette.greenMain),
  //                 onPressed: () => _goToAlbaran(albaran: m.albaranPadre),
  //               ),
  //               IconButton(
  //                 icon: const Icon(Icons.delete, size: 20, color: AgriPalette.greenMain),
  //                 onPressed: () => _confirmDeleteAlbaran(m.albaranPadre.kalbaran),
  //               ),
  //             ],
  //           ),
  //         );
  //       }).toList(),
  //     );
  //   }

  //   String criterioActual = criterios[indexCriterio].trim().toLowerCase();

  //   Map<String, List<MovimientoVisual>> agrupados = {};
  //   Map<String, String> etiquetasLegibles = {};

  //   for (var m in datosNodo) {
  //     String key = "";
  //     String etiqueta = "";

  //     switch (criterioActual) {
  //       case 'finca':
  //         key = m.idFinca;
  //         etiqueta = m.nombreFinca;
  //         break;
  //       case 'cultivo':
  //         key = m.idProducto;
  //         etiqueta = m.nombreProducto;
  //         break;
  //       case 'almacen':
  //         key = m.idAlmacen;
  //         etiqueta = m.nombreAlmacen;
  //         break;
  //       case 'fecha':
  //         key = "${m.fecha.year}-${m.fecha.month}-${m.fecha.day}";
  //         etiqueta = '${m.fecha.day.toString().padLeft(2,'0')}/${m.fecha.month.toString().padLeft(2,'0')}/${m.fecha.year}';
  //         break;
  //       default:
  //         key = "desconocido";
  //         etiqueta = "Otros";
  //     }
      
  //     // Aseguramos claves limpias ante posibles nulos locales
  //     if (key.isEmpty) key = "vacio_$indexCriterio";
      
  //     agrupados.putIfAbsent(key, () => []).add(m);
  //     etiquetasLegibles[key] = etiqueta;
  //   }

  //   return Column(
  //     children: agrupados.entries.map((entry) {
  //       final subLista = entry.value;
  //       final subTotalKg = subLista.fold<double>(0, (sum, m) => sum + m.kg);
        
  //       String tituloFinal = '${etiquetasLegibles[entry.key]} ${subTotalKg.toStringAsFixed(0)} kg';
  //       if (criterioActual == 'finca' && subLista.isNotEmpty) {
  //         tituloFinal = '${etiquetasLegibles[entry.key]} ${subTotalKg.toStringAsFixed(0)} kg (${subLista.first.rendimientoM2.toStringAsFixed(1)} kg/m²)';
  //       }

  //       // CORRECCIÓN CRÍTICA DE CRASH: Llave inequívoca con prefijo de nivel
  //       final String llaveUnica = "nivel_${indexCriterio}_${entry.key}_$criterioActual";

  //       return Padding(
  //         padding: const EdgeInsets.only(left: 4.0), // Sangrado sutil para mantener el orden sin desbordar el ancho
  //         child: Theme(
  //           // Eliminamos las salpicaduras de color y fondos raros que mete ExpansionTile por defecto
  //           data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
  //           child: ExpansionTile(
  //             key: ValueKey(llaveUnica), // ValueKey con alcance controlado soluciona el crash de SliverMultiBox
  //             shape: const Border(), // Quita la línea superior interna cuando está abierto
  //             collapsedShape: const Border(), // Quita la línea cuando está cerrado
  //             tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
  //             title: Text(
  //               tituloFinal, 
  //               style: indexCriterio == 0 
  //                   ? Theme.of(context).textTheme.titleMedium // Primer nivel idéntico al original
  //                   : Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500), // Subniveles estilizados
  //             ),
  //             children: [
  //               _construirNivelDinamicamente(subLista, criterios, indexCriterio + 1),
  //             ],
  //           ),
  //         ),
  //       );
  //     }).toList(),
  //   );
  // }
/// 3. Función recursiva encargada de anidar ExpansionTiles dinámicamente (Cálculo de Totales corregido)
  Widget _construirNivelDinamicamente(List<MovimientoVisual> datosNodo, List<String> criterios, int indexCriterio) {
    // CONDICIÓN TERMINAL: Si ya procesamos las agrupaciones, pintamos las hojas (las líneas) con sus acciones
    if (indexCriterio >= criterios.length) {
      return Column(
        children: datosNodo.map((m) {
          return ListTile(
            dense: true,
            leading: const Icon(Icons.arrow_right, color: AgriPalette.greyMain),
            title: Text(
              // Mostramos el precio total de la línea si existe
              'Línea ${m.detalleOriginal.linea}: ${m.nombreProducto} -> ' +
              (m.albaranPadre.ktipoalbaran == "c4755f6d-6744-11f0-ac9b-e2b6c6b4d8df" 
                ? '${(m.kg * (m.detalleOriginal.precio ?? 0.0)).toStringAsFixed(2)} €'
                : '${m.kg.toStringAsFixed(1)} kg'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            subtitle: Text(
              'Doc: ${m.albaranPadre.idalbaranstr} | Almacén: ${m.nombreAlmacen}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20, color: AgriPalette.greenMain),
                  onPressed: () => _goToAlbaran(albaran: m.albaranPadre),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: AgriPalette.greenMain),
                  onPressed: () => _confirmDeleteAlbaran(m.albaranPadre.kalbaran),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    String criterioActual = criterios[indexCriterio].trim().toLowerCase();

    // Agrupación dinámica por el criterio del nivel actual
    Map<String, List<MovimientoVisual>> agrupados = {};
    Map<String, String> etiquetasLegibles = {};

    for (var m in datosNodo) {
      String key = "";
      String etiqueta = "";

      switch (criterioActual) {
        case 'finca':
          key = m.idFinca;
          etiqueta = m.nombreFinca; // Dejamos solo el nombre limpio, el total va al final
          break;
        case 'cultivo':
          key = m.idProducto;
          etiqueta = m.nombreProducto;
          break;
        case 'almacen':
          key = m.idAlmacen;
          etiqueta = m.nombreAlmacen;
          break;
        case 'fecha':
          key = "${m.fecha.year}-${m.fecha.month}-${m.fecha.day}";
          etiqueta = '${m.fecha.day.toString().padLeft(2,'0')}/${m.fecha.month.toString().padLeft(2,'0')}/${m.fecha.year}';
          break;
        default:
          key = "desconocido";
          etiqueta = "Otros";
      }
      
      if (key.isEmpty) key = "vacio_$indexCriterio";
      
      agrupados.putIfAbsent(key, () => []).add(m);
      etiquetasLegibles[key] = etiqueta;
    }

    return Column(
      children: agrupados.entries.map((entry) {
        final subLista = entry.value;
        
        // 1. DETECTAMOS SI EL NODO ES DE GASTOS O INGRESOS
        final bool esGasto = subLista.isNotEmpty && subLista.first.albaranPadre.ktipoalbaran == "c4755f6d-6744-11f0-ac9b-e2b6c6b4d8df";
        
        // 2. CALCULAMOS AMBOS TOTALES
        final subTotalKg = subLista.fold<double>(0, (sum, m) => sum + m.kg);
        final subTotalEuros = subLista.fold<double>(0, (sum, m) => sum + (m.kg * (m.detalleOriginal.precio ?? 0.0)));
        
        String tituloFinal = '';

        // 3. LÓGICA CONDICIONAL DE PRESENTACIÓN
        if (esGasto) {
          // Presentación para Gastos: Solo Dinero (€)
          tituloFinal = '${etiquetasLegibles[entry.key]}: ${subTotalEuros.toStringAsFixed(2)} €';
          
          // Cálculo de coste por metro cuadrado (solo si la agrupación actual es por Finca)
          if (criterioActual == 'finca') {
            final fincaObj = widget.fincas.firstWhere(
              (f) => f.kfinca == entry.key,
              orElse: () => finca(kfinca: '', kfincapadre: '', nombreStr: '', descripcionStr: '', kagricultor: '', ubicacionStr: '', aream2Flt: 1, campo1Str: '', campo2Str: '', fecha: DateTime.now(), fechaultimouso: DateTime.now()),
            );
            
            final double areaFinca = fincaObj.aream2Flt > 0 ? fincaObj.aream2Flt : 1;
            final double costePorM2 = subTotalEuros / areaFinca;
            
            // Usamos 3 decimales (0.000 €/m²) porque los costes por metro pueden ser céntimos
            tituloFinal = '${etiquetasLegibles[entry.key]}: ${subTotalEuros.toStringAsFixed(2)} € (${costePorM2.toStringAsFixed(3)} €/m²)';
          }
        } else {
          // Presentación para Ingresos: Kilos puros
          tituloFinal = '${etiquetasLegibles[entry.key]}: ${subTotalKg.toStringAsFixed(0)} kg';
          
          // Cálculo de rendimiento (solo si es Finca y es Ingreso)
          if (criterioActual == 'finca') {
            final fincaObj = widget.fincas.firstWhere(
              (f) => f.kfinca == entry.key,
              orElse: () => finca(kfinca: '', kfincapadre: '', nombreStr: '', descripcionStr: '', kagricultor: '', ubicacionStr: '', aream2Flt: 1, campo1Str: '', campo2Str: '', fecha: DateTime.now(), fechaultimouso: DateTime.now()),
            );
            
            final double areaFinca = fincaObj.aream2Flt > 0 ? fincaObj.aream2Flt : 1;
            final double rendimientoReal = subTotalKg / areaFinca;
            
            tituloFinal = '${etiquetasLegibles[entry.key]}: ${subTotalKg.toStringAsFixed(0)} kg (${rendimientoReal.toStringAsFixed(1)} kg/m²)';
          }
        }

        final String llaveUnica = "nivel_${indexCriterio}_${entry.key}_$criterioActual";

        return Padding(
          padding: const EdgeInsets.only(left: 4.0), 
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: ValueKey(llaveUnica), 
              shape: const Border(), 
              collapsedShape: const Border(), 
              tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              title: Text(
                tituloFinal, 
                style: indexCriterio == 0 
                    ? Theme.of(context).textTheme.titleMedium 
                    : Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500), 
              ),
              children: [
                _construirNivelDinamicamente(subLista, criterios, indexCriterio + 1),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}