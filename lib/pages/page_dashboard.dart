//page_dashboard.dart
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
import '../pages/page_trabajador.dart';
import '../pages/page_jornada_add.dart';


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

  // 1. FORZAR ACTUALIZACIÓN FRESCA AL ENTRAR
  // Esto asegura que, aunque DashboardCarga traiga datos viejos, 
  // en cuanto el Dashboard abre, se traen los reales.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _superRefresh();
  });

  // 2. ESCUCHA DE SINCRONIZACIÓN
  SyncService.syncStream.listen((finalizadoOk) {
    if (finalizadoOk && mounted) {
      _refreshAlbaranes();
    }
  });
}

Stream<List<Albaran>> _getAlbaranesStream() async* {
  while (true) {
    // 1. Albaranes de la caché (API)
    //final localData = await DBService.instance.getAllFromLocal('albaranes');
    final localData = await DBService.instance.getAllFromLocal('albaranesv2'); 
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
      DBService.instance.limpiarTodaLaBaseDeDatos();
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
    DBService.instance.limpiarTodaLaBaseDeDatos();
  }

/// Pide al servidor la lista actualizada de albaranes.
  // Future<void> _refreshAlbaranes() async {
  //   // CAMBIO: Usamos 'albaranes' para que coincida con la tabla de la caché y el Stream
  //   _albaranes = (await _apiService.fetchParticular('albaranes'))
  //       .map((json) => Albaran.fromJson(json))
  //       .toList();
        
  //   mensajeEmergente(context, 'Albaranes Actualizados', segundos: 1);
  //   setState(() {}); 
  // }

  Future<void> _refreshAlbaranes() async {
    // ¡OBLIGATORIO USAR albaranesv2!
    _albaranes = (await _apiService.fetchParticular('albaranesv2'))
        .map((json) => Albaran.fromJson(json))
        .toList();
        
    mensajeEmergente(context, 'Datos Actualizados', segundos: 1);
    setState(() {}); 
  }


  // Future<void> _superRefresh() async {
  //   // 1. Primero intentamos subir lo que haya pendiente
  //   await SyncService.sincronizarTodo();
    
  //   // 2. Después bajamos lo último del servidor
  //   await _refreshAlbaranes();
    
  //   // 3. El IconoSync se actualizará solo por su Stream interno
  //   setState(() {}); 
  //   DBService.instance.limpiarTodaLaBaseDeDatos();
  // }

/// Sincroniza todo al iniciar o al pulsar el botón
  Future<void> _superRefresh() async {
    // 1. Primero intentamos subir lo que haya pendiente
    await SyncService.sincronizarTodo();
    
    // 2. Después bajamos lo último del servidor con el endpoint correcto
    await _refreshAlbaranes();
    
    // 3. Refrescamos la pantalla
    setState(() {}); 
    
    // ELIMINADO: DBService.instance.limpiarTodaLaBaseDeDatos(); 
    // ¡Nunca borres la caché aquí o romperás el modo offline!
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
  /// Lógica para realizar el borrado lógico (marcar como eliminado_bit = 1)
  /// Lógica para realizar el borrado lógico (marcar como eliminado_bit = 1)
  Future<void> _confirmDeleteAlbaran(Albaran albaran) async {
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
        // 1. Marcar cabecera como eliminada en la BD
        await _apiService.putGeneric('tblalbaran', albaran.kalbaran, {'eliminado_bit': 1});

        // 2. Marcar sus detalles como eliminados usando los datos que ya tenemos
        for (var detalle in albaran.detalles) {
          if (detalle.kalbarandetalle.isNotEmpty) {
            await _apiService.putGeneric('tblalbarandetalle', detalle.kalbarandetalle, {'eliminado_bit': 1});
          }
        }

        // 3. Quitar de la lista visual local
        setState(() {
          _albaranes.removeWhere((a) => a.kalbaran == albaran.kalbaran);
        });

        mensajeEmergente(context, "Albarán eliminado correctamente");
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'), 
            backgroundColor: colorEliminar,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          ),
        );
      }
    }
  }
  // Future<void> _confirmDeleteAlbaran(String kalbaran) async {
  //   final confirm = await showDialog<bool>(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('¿Eliminar Albarán?'),
  //       content: const Text('Se ocultará el albarán y sus productos asociados.'),
  //       actions: [
  //         TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
  //         ElevatedButton(
  //           style: ElevatedButton.styleFrom(backgroundColor: colorAccion),
  //           onPressed: () => Navigator.pop(context, true),
  //           child: const Text('Confirmar', style: TextStyle(color: colorFondo)),
  //         ),
  //       ],
  //     ),
  //   );


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

  // 2. FILTROS EXPLICITOS
  // IMPORTANTE: Asegúrate de que estos UUIDs sean los correctos. 
  // Si los tomates (Ingresos) se van a gastos, es porque este UUID es el de Gastos.
  final String uuidIngreso =  "b42f149b-6744-11f0-ac9b-e2b6c6b4d8df"; // CAMBIA ESTO SI HACE FALTA
  final String uuidGasto = "c4755f6d-6744-11f0-ac9b-e2b6c6b4d8df";   // CAMBIA ESTO SI HACE FALTA

  final ingresos = todosLosMovimientos.where((m) => m.albaranPadre.ktipoalbaran == uuidIngreso).toList();
  final gastos = todosLosMovimientos.where((m) => m.albaranPadre.ktipoalbaran == uuidGasto).toList();

  // 3. CÁLCULOS SEGUROS
  final totalKgIngresos = ingresos.fold<double>(0, (sum, item) => sum + item.kg);
  // Cálculo de gastos: kg * precio
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
    body: StreamBuilder<List<Albaran>>(
      stream: _getAlbaranesStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        _albaranes = snapshot.data!; 
        
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- SECCIÓN INGRESOS ---
            _buildSection(
              'Albaranes: ${totalKgIngresos.toStringAsFixed(2)} kg',
              onAdd: () async {
                 final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => PageAlbaran(
                    almacenes: widget.almacen, tiposPrecio: widget.tipodeprecio,
                    productos: widget.producto, fincas: widget.fincas, albaranesTotales: _albaranes,
                    ktipoalbaran: uuidIngreso,
                 )));
                 if (result == true) _refreshAlbaranes();
              },
              child: ingresos.isEmpty ? const Padding(padding: EdgeInsets.all(16), child: Text('No hay ingresos')) 
                  : _construirNivelDinamicamente(ingresos, widget.usuario.prefAgrupacion.split(','), 0),
            ),

            // --- SECCIÓN GASTOS ---
            _buildSection(
              'Gastos: ${totalEurosGastos.toStringAsFixed(2)} €',
              onAdd: () async {
                 final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => PageAlbaran(
                    almacenes: widget.almacen, tiposPrecio: widget.tipodeprecio,
                    productos: widget.producto, fincas: widget.fincas, albaranesTotales: _albaranes,
                    ktipoalbaran: uuidGasto,
                 )));
                 if (result == true) _refreshAlbaranes();
              },
              child: gastos.isEmpty ? const Padding(padding: EdgeInsets.all(16), child: Text('No hay gastos')) 
                  : _construirNivelDinamicamente(gastos, widget.usuario.prefAgrupacionGastos.split(','), 0),
            ),            _buildSection('Operaciones', onAdd: () {}),
            //_buildSection2('Jornadas', onAdd: () {}, child: const Text("Último día: 2025/05/19")),
            
            _buildSection2(
              'Jornadas',
              actions: [
                IconButton(
                  icon: const Icon(Icons.analytics_outlined),
                  color: AgriPalette.greyMain,
                  tooltip: 'Informes',
                  onPressed: () { /* Navegar a Informes */ },
                ),
                IconButton(
                  icon: const Icon(Icons.people_outline),
                  color: AgriPalette.greenMain,
                  tooltip: 'Gestión Personal',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PageTrabajadores())),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  color: AgriPalette.greenMain,
                  tooltip: 'Añadir Jornada',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        // 'widget.trabajador' asume que en tu Dashboard tienes esa lista disponible
                        builder: (context) => PageJornadaAdd(trabajadores: widget.trabajador),
                      ),
                    );
                  },
                ),
              ],
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text("Historial de jornadas próximamente..."),
              ),
            ),

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
                                      // IconButton(icon: const Icon(Icons.delete),  color: AgriPalette.greenMain, onPressed: () => _confirmDeleteAlbaran(albaran.kalbaran)),
                                      IconButton(icon: const Icon(Icons.delete),  color: AgriPalette.greenMain, onPressed: () => _confirmDeleteAlbaran(albaran)),
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
Widget _buildSection(String title, {required VoidCallback onAdd, Widget? child}) {
  return Card(
    elevation: 2,
    margin: const EdgeInsets.symmetric(vertical: 10),
    child: ExpansionTile( // <--- CAMBIAMOS COLUMNA POR EXPANSIONTILE
      title: Text(title, style: Theme.of(context).textTheme.titleLarge),
      trailing: IconButton(
        icon: const Icon(Icons.add), 
        color: AgriPalette.greenMain, 
        onPressed: onAdd
      ),
      children: [
        if (child != null) child,
      ],
    ),
  );
}

Widget _buildSection2(String title, {List<Widget>? actions, Widget? child}) {
  return Card(
    elevation: 2,
    margin: const EdgeInsets.symmetric(vertical: 10),
    child: ExpansionTile(
      title: Text(title, style: Theme.of(context).textTheme.titleLarge),
      // Si enviamos acciones, las mostramos; si no, dejamos espacio libre o vacío
      trailing: actions != null 
          ? Row(mainAxisSize: MainAxisSize.min, children: actions) 
          : null,
      children: [
        if (child != null) child,
      ],
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
//   Widget _construirNivelDinamicamente(List<MovimientoVisual> datosNodo, List<String> criterios, int indexCriterio) {
//     // CONDICIÓN TERMINAL: Si ya procesamos las agrupaciones, pintamos las hojas (las líneas) con sus acciones
//     if (indexCriterio >= criterios.length) {
//       return Column(
//         children: datosNodo.map((m) {
//           return ListTile(
//             dense: true,
//             leading: const Icon(Icons.arrow_right, color: AgriPalette.greyMain),
//             title: Text(
//               // Mostramos el precio total de la línea si existe
//               'Línea ${m.detalleOriginal.linea}: ${m.nombreProducto} -> ' +
//               (m.albaranPadre.ktipoalbaran == "c4755f6d-6744-11f0-ac9b-e2b6c6b4d8df" 
//                 ? '${(m.kg * (m.detalleOriginal.precio ?? 0.0)).toStringAsFixed(2)} €'
//                 : '${m.kg.toStringAsFixed(1)} kg'),
//               style: Theme.of(context).textTheme.bodyMedium,
//             ),
//             subtitle: Text(
//               'Doc: ${m.albaranPadre.idalbaranstr} | Almacén: ${m.nombreAlmacen}',
//               style: Theme.of(context).textTheme.bodySmall,
//             ),
//             trailing: Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 IconButton(
//                   icon: const Icon(Icons.edit, size: 20, color: AgriPalette.greenMain),
//                   onPressed: () => _goToAlbaran(albaran: m.albaranPadre),
//                 ),
//                 IconButton(
//                   icon: const Icon(Icons.delete, size: 20, color: AgriPalette.greenMain),
//                   onPressed: () => _confirmDeleteAlbaran(m.albaranPadre.kalbaran),
//                 ),
//               ],
//             ),
//           );
//         }).toList(),
//       );
//     }

//     String criterioActual = criterios[indexCriterio].trim().toLowerCase();

//     // Agrupación dinámica por el criterio del nivel actual
//     Map<String, List<MovimientoVisual>> agrupados = {};
//     Map<String, String> etiquetasLegibles = {};

//     for (var m in datosNodo) {
//       String key = "";
//       String etiqueta = "";

//       switch (criterioActual) {
//         case 'finca':
//           key = m.idFinca;
//           etiqueta = m.nombreFinca; // Dejamos solo el nombre limpio, el total va al final
//           break;
//         case 'cultivo':
//           key = m.idProducto;
//           etiqueta = m.nombreProducto;
//           break;
//         case 'almacen':
//           key = m.idAlmacen;
//           etiqueta = m.nombreAlmacen;
//           break;
//         case 'fecha':
//           key = "${m.fecha.year}-${m.fecha.month}-${m.fecha.day}";
//           etiqueta = '${m.fecha.day.toString().padLeft(2,'0')}/${m.fecha.month.toString().padLeft(2,'0')}/${m.fecha.year}';
//           break;
//         default:
//           key = "desconocido";
//           etiqueta = "Otros";
//       }
      
//       if (key.isEmpty) key = "vacio_$indexCriterio";
      
//       agrupados.putIfAbsent(key, () => []).add(m);
//       etiquetasLegibles[key] = etiqueta;
//     }

//   return Column(
//       children: agrupados.entries.map((entry) {
//         final subLista = entry.value;
        
//         // 1. DETECTAMOS SI EL NODO ES DE GASTOS O INGRESOS
//         final bool esGasto = subLista.isNotEmpty && subLista.first.albaranPadre.ktipoalbaran == "c4755f6d-6744-11f0-ac9b-e2b6c6b4d8df";
        
//         // 2. CALCULAMOS AMBOS TOTALES
//         final subTotalKg = subLista.fold<double>(0, (sum, m) => sum + m.kg);
//         final subTotalEuros = subLista.fold<double>(0, (sum, m) => sum + (m.kg * (m.detalleOriginal.precio ?? 0.0)));
        
//         String tituloFinal = '';

// // Si es el nivel 0 (el primero que entra), en lugar de crear un ExpansionTile, 
//         // simplemente pintamos las filas de datos o el siguiente nivel.
//         // Esto evita tener un título repetido "Gastos" y dentro "Gastos".
        
//         if (indexCriterio == 0) {
//            return _construirNivelDinamicamente(subLista, criterios, indexCriterio + 1);
//         }
//         // 3. LÓGICA CONDICIONAL DE PRESENTACIÓN
//         if (esGasto) {
//           // Presentación para Gastos: Solo Dinero (€)
//           tituloFinal = '${etiquetasLegibles[entry.key]}: ${subTotalEuros.toStringAsFixed(2)} €';
          
//           // Cálculo de coste por metro cuadrado (solo si la agrupación actual es por Finca)
//           if (criterioActual == 'finca') {
//             final fincaObj = widget.fincas.firstWhere(
//               (f) => f.kfinca == entry.key,
//               orElse: () => finca(kfinca: '', kfincapadre: '', nombreStr: '', descripcionStr: '', kagricultor: '', ubicacionStr: '', aream2Flt: 1, campo1Str: '', campo2Str: '', fecha: DateTime.now(), fechaultimouso: DateTime.now()),
//             );
            
//             final double areaFinca = fincaObj.aream2Flt > 0 ? fincaObj.aream2Flt : 1;
//             final double costePorM2 = subTotalEuros / areaFinca;
            
//             // Usamos 3 decimales (0.000 €/m²) porque los costes por metro pueden ser céntimos
//             tituloFinal = '${etiquetasLegibles[entry.key]}: ${subTotalEuros.toStringAsFixed(2)} € (${costePorM2.toStringAsFixed(2)} €/m²)';
//           }
//         } else {
//           // Presentación para Ingresos: Kilos puros
//           tituloFinal = '${etiquetasLegibles[entry.key]}: ${subTotalKg.toStringAsFixed(0)} kg';
          
//           // Cálculo de rendimiento (solo si es Finca y es Ingreso)
//           if (criterioActual == 'finca') {
//             final fincaObj = widget.fincas.firstWhere(
//               (f) => f.kfinca == entry.key,
//               orElse: () => finca(kfinca: '', kfincapadre: '', nombreStr: '', descripcionStr: '', kagricultor: '', ubicacionStr: '', aream2Flt: 1, campo1Str: '', campo2Str: '', fecha: DateTime.now(), fechaultimouso: DateTime.now()),
//             );
            
//             final double areaFinca = fincaObj.aream2Flt > 0 ? fincaObj.aream2Flt : 1;
//             final double rendimientoReal = subTotalKg / areaFinca;
            
//             tituloFinal = '${etiquetasLegibles[entry.key]}: ${subTotalKg.toStringAsFixed(0)} kg (${rendimientoReal.toStringAsFixed(1)} kg/m²)';
//           }
//         }

//         final String llaveUnica = "nivel_${indexCriterio}_${entry.key}_$criterioActual";

//         return Padding(
//           padding: const EdgeInsets.only(left: 4.0), 
//           child: Theme(
//             data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
//             child: ExpansionTile(
//               key: ValueKey(llaveUnica), 
//               shape: const Border(), 
//               collapsedShape: const Border(), 
//               tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
//               title: Text(
//                 tituloFinal, 
//                 style: indexCriterio == 0 
//                     ? Theme.of(context).textTheme.titleMedium 
//                     : Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500), 
//               ),
//               children: [
//                 _construirNivelDinamicamente(subLista, criterios, indexCriterio + 1),
//               ],
//             ),
//           ),
//         );
//       }).toList(),
//     );
//   }
/// Función recursiva encargada de anidar ExpansionTiles dinámicamente.
  /// Ahora gestiona el cálculo de totales, rendimiento (kg/m²) y coste (€/m²) según el tipo de documento.
  // Widget _construirNivelDinamicamente(List<MovimientoVisual> datosNodo, List<String> criterios, int indexCriterio) {
  //   // CONDICIÓN TERMINAL: Renderizado de las hojas finales (Líneas de producto)
  //   if (indexCriterio >= criterios.length) {
  //     return Column(
  //       children: datosNodo.map((m) {
  //         return ListTile(
  //           dense: true,
  //           leading: const Icon(Icons.arrow_right, color: AgriPalette.greyMain),
  //           title: Text(
  //             'Línea ${m.detalleOriginal.linea}: ${m.nombreProducto} -> ' +
  //             (m.albaranPadre.ktipoalbaran == "c4755f6d-6744-11f0-ac9b-e2b6c6b4d8df" 
  //               ? '${(m.kg * (m.detalleOriginal.precio ?? 0.0)).toStringAsFixed(2)} €'
  //               : '${m.kg.toStringAsFixed(1)} kg'),
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

  //   // Agrupación dinámica
  //   Map<String, List<MovimientoVisual>> agrupados = {};
  //   Map<String, String> etiquetasLegibles = {};

  //   for (var m in datosNodo) {
  //     String key = "";
  //     String etiqueta = "";

  //     switch (criterioActual) {
  //       case 'finca': key = m.idFinca; etiqueta = m.nombreFinca; break;
  //       case 'cultivo': key = m.idProducto; etiqueta = m.nombreProducto; break;
  //       case 'almacen': key = m.idAlmacen; etiqueta = m.nombreAlmacen; break;
  //       case 'fecha':
  //         key = "${m.fecha.year}-${m.fecha.month}-${m.fecha.day}";
  //         etiqueta = '${m.fecha.day.toString().padLeft(2,'0')}/${m.fecha.month.toString().padLeft(2,'0')}/${m.fecha.year}';
  //         break;
  //       default: key = "desconocido"; etiqueta = "Otros";
  //     }
      
  //     if (key.isEmpty) key = "vacio_$indexCriterio";
  //     agrupados.putIfAbsent(key, () => []).add(m);
  //     etiquetasLegibles[key] = etiqueta;
  //   }

  //   return Column(
  //     children: agrupados.entries.map((entry) {
  //       final subLista = entry.value;
        
  //       //final bool esGasto = subLista.isNotEmpty && subLista.first.albaranPadre.ktipoalbaran == "c4755f6d-6744-11f0-ac9b-e2b6c6b4d8df";
  //       // Dentro de _construirNivelDinamicamente, sustituye la línea del boolean esGasto por esta:

  //       final bool esGasto = subLista.every((m) => m.albaranPadre.ktipoalbaran == "c4755f6d-6744-11f0-ac9b-e2b6c6b4d8df");
  //       final subTotalKg = subLista.fold<double>(0, (sum, m) => sum + m.kg);
  //       final subTotalEuros = subLista.fold<double>(0, (sum, m) => sum + (m.kg * (m.detalleOriginal.precio ?? 0.0)));
        
  //       String etiquetaNombre = etiquetasLegibles[entry.key] ?? "Sin nombre";
  //       String tituloFinal = '';

  //       // LÓGICA DE NIVEL:
  //       // Si es el nivel 0 (el primero), mostramos Nombre + Total.
  //       // Si es un nivel interno (1, 2...), solo mostramos Nombre + Total.
  //       // El problema actual es que el nivel 1 "parece" el nivel 0. 
  //       // Vamos a mantener el total solo en el nivel 0 y los hijos solo el nombre.
        
  //       if (indexCriterio == 0) {
  //          // Nivel superior: Mostramos Nombre y Total
  //          tituloFinal = esGasto 
  //             ? '$etiquetaNombre: ${subTotalEuros.toStringAsFixed(2)} €' 
  //             : '$etiquetaNombre: ${subTotalKg.toStringAsFixed(0)} kg';
  //       } else {
  //          // Niveles internos: Solo Nombre (queda más limpio)
  //          tituloFinal = etiquetaNombre;
  //       }

  //       if (esGasto) {
  //         tituloFinal = '${etiquetasLegibles[entry.key]}: ${subTotalEuros.toStringAsFixed(2)} €';
  //         if (criterioActual == 'finca') {
  //           final fincaObj = widget.fincas.firstWhere((f) => f.kfinca == entry.key, orElse: () => finca(kfinca: '', kfincapadre: '', nombreStr: '', descripcionStr: '', kagricultor: '', ubicacionStr: '', aream2Flt: 1, campo1Str: '', campo2Str: '', fecha: DateTime.now(), fechaultimouso: DateTime.now()));
  //           final double areaFinca = fincaObj.aream2Flt > 0 ? fincaObj.aream2Flt : 1;
  //           tituloFinal = '${etiquetasLegibles[entry.key]}: ${subTotalEuros.toStringAsFixed(2)} € (${(subTotalEuros / areaFinca).toStringAsFixed(3)} €/m²)';
  //         }
  //       } else {
  //         tituloFinal = '${etiquetasLegibles[entry.key]}: ${subTotalKg.toStringAsFixed(0)} kg';
  //         if (criterioActual == 'finca') {
  //           final fincaObj = widget.fincas.firstWhere((f) => f.kfinca == entry.key, orElse: () => finca(kfinca: '', kfincapadre: '', nombreStr: '', descripcionStr: '', kagricultor: '', ubicacionStr: '', aream2Flt: 1, campo1Str: '', campo2Str: '', fecha: DateTime.now(), fechaultimouso: DateTime.now()));
  //           final double areaFinca = fincaObj.aream2Flt > 0 ? fincaObj.aream2Flt : 1;
  //           tituloFinal = '${etiquetasLegibles[entry.key]} ${subTotalKg.toStringAsFixed(0)} kg (${(subTotalKg / areaFinca).toStringAsFixed(1)} kg/m²)';
  //         }
  //       }

  //       final String llaveUnica = "nivel_${indexCriterio}_${entry.key}_$criterioActual";

  //       return Padding(
  //         padding: EdgeInsets.only(left: indexCriterio == 0 ? 0 : 4.0),
  //         child: ExpansionTile(
  //           key: ValueKey(llaveUnica),
  //           tilePadding: const EdgeInsets.symmetric(horizontal: 12),
  //           title: Text(
  //             tituloFinal, 
  //             style: indexCriterio == 0 
  //                 ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold) 
  //                 : Theme.of(context).textTheme.bodyLarge,
  //           ),
  //           children: [
  //             _construirNivelDinamicamente(subLista, criterios, indexCriterio + 1),
  //           ],
  //         ),
  //       );
  //     }).toList(),
  //   );
  // }
Widget _construirNivelDinamicamente(List<MovimientoVisual> datosNodo, List<String> criterios, int indexCriterio) {
    // CONDICIÓN TERMINAL: Renderizado de las hojas finales (Líneas de producto)
    if (indexCriterio >= criterios.length) {
      return Column(
        children: datosNodo.map((m) {
          return ListTile(
            dense: true,
            leading: const Icon(Icons.arrow_right, color: AgriPalette.greyMain),
            title: Text(
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
                  // onPressed: () => _confirmDeleteAlbaran(m.albaranPadre.kalbaran),
                  onPressed: () => _confirmDeleteAlbaran(m.albaranPadre),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    String criterioActual = criterios[indexCriterio].trim().toLowerCase();
    //print("DEBUG: Nivel $indexCriterio | Criterio recibido: '$criterioActual'"); // <--- ESTO ES VITAL
    Map<String, List<MovimientoVisual>> agrupados = {};
    Map<String, String> etiquetasLegibles = {};

    for (var m in datosNodo) {
      String key = "";
      String etiqueta = "";
      switch (criterioActual) {
        case 'finca': key = m.idFinca; etiqueta = m.nombreFinca; break;
        case 'cultivo': key = m.idProducto; etiqueta = m.nombreProducto; break;
        case 'almacen': key = m.idAlmacen; etiqueta = m.nombreAlmacen; break;
        case 'mes':
          // Clave sortable: 2026-05
          key = "${m.fecha.year}-${m.fecha.month.toString().padLeft(2, '0')}";
          // Etiqueta legible: Mayo 2026
          etiqueta = "${m.fecha.year}-${m.fecha.month.toString().padLeft(2, '0')}"; //'${_nombreMes(m.fecha.month)} ${m.fecha.year}';
          break;
        case 'fecha':
          // Añadimos padLeft(2, '0') para que sea siempre YYYY-MM-DD
          key = "${m.fecha.year}-${m.fecha.month.toString().padLeft(2, '0')}-${m.fecha.day.toString().padLeft(2, '0')}";
          etiqueta = '${m.fecha.day.toString().padLeft(2,'0')}/${m.fecha.month.toString().padLeft(2,'0')}/${m.fecha.year}';
          break;
        default: key = "desconocido"; etiqueta = "Otros";
      }
      if (key.isEmpty) key = "vacio_$indexCriterio";
      agrupados.putIfAbsent(key, () => []).add(m);
      etiquetasLegibles[key] = etiqueta;
    }

    // return Column(
    //   children: agrupados.entries.map((entry) {
    //     final subLista = entry.value;
// 1. Convertimos las entradas del mapa a una lista para poder ordenarla
    var listaEntradas = agrupados.entries.toList();

    // 2. Lógica de ordenación
    if (criterioActual == 'fecha' || criterioActual == 'mes') {
      // Si es fecha, ordenamos de forma descendente (Más recientes primero)
      // Como el formato de clave es YYYY-MM-DD, un compareTo simple funciona perfecto
      listaEntradas.sort((a, b) => b.key.compareTo(a.key));
    } else {
      // Si no es fecha, ordenamos alfabéticamente por la etiqueta
      listaEntradas.sort((a, b) => etiquetasLegibles[a.key]!.compareTo(etiquetasLegibles[b.key]!));
    }

    // 3. Ahora usamos listaEntradas en lugar de agrupados.entries
    return Column(
      children: listaEntradas.map((entry) {
        final subLista = entry.value;
        final bool esGasto = subLista.every((m) => m.albaranPadre.ktipoalbaran == "c4755f6d-6744-11f0-ac9b-e2b6c6b4d8df");
        
        final subTotalKg = subLista.fold<double>(0, (sum, m) => sum + m.kg);
        final subTotalEuros = subLista.fold<double>(0, (sum, m) => sum + (m.kg * (m.detalleOriginal.precio ?? 0.0)));
        
        // --- AQUÍ ESTÁ EL CAMBIO PRINCIPAL ---
        String tituloFinal = etiquetasLegibles[entry.key] ?? "Sin nombre";

        // Solo añadimos cálculos si estamos en el nivel raíz (index 0)
        if (indexCriterio == 0) {
           if (esGasto) {
              tituloFinal += ': ${subTotalEuros.toStringAsFixed(2)} €';
              if (criterioActual == 'finca') {
                final fincaObj = widget.fincas.firstWhere((f) => f.kfinca == entry.key, orElse: () => finca(kfinca: '', kfincapadre: '', nombreStr: '', descripcionStr: '', kagricultor: '', ubicacionStr: '', aream2Flt: 1, campo1Str: '', campo2Str: '', fecha: DateTime.now(), fechaultimouso: DateTime.now()));
                final double areaFinca = fincaObj.aream2Flt > 0 ? fincaObj.aream2Flt : 1;
                tituloFinal += ' (${(subTotalEuros / areaFinca).toStringAsFixed(2)} €/m²)';
              }
           } else {
              tituloFinal += ': ${subTotalKg.toStringAsFixed(0)} kg';
              if (criterioActual == 'finca') {
                final fincaObj = widget.fincas.firstWhere((f) => f.kfinca == entry.key, orElse: () => finca(kfinca: '', kfincapadre: '', nombreStr: '', descripcionStr: '', kagricultor: '', ubicacionStr: '', aream2Flt: 1, campo1Str: '', campo2Str: '', fecha: DateTime.now(), fechaultimouso: DateTime.now()));
                final double areaFinca = fincaObj.aream2Flt > 0 ? fincaObj.aream2Flt : 1;
                tituloFinal += ' (${(subTotalKg / areaFinca).toStringAsFixed(1)} kg/m²)';
              }
           }
        }

        final String llaveUnica = "nivel_${indexCriterio}_${entry.key}_$criterioActual";

        return Padding(
          padding: EdgeInsets.only(left: indexCriterio == 0 ? 0 : 8.0),
          child: ExpansionTile(
            key: ValueKey(llaveUnica),
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            title: Text(
              tituloFinal, 
              style: indexCriterio == 0 
                  ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold) 
                  : Theme.of(context).textTheme.bodyLarge,
            ),
            children: [
              _construirNivelDinamicamente(subLista, criterios, indexCriterio + 1),
            ],
          ),
        );
      }).toList(),
    );
  }
}