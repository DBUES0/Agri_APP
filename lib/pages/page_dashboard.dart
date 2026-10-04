//page_dashboard.dart
import 'dart:convert';
import 'package:agriapp/pages/page_usuario.dart';
import 'package:agriapp/services/db_service.dart';
import 'package:agriapp/services/sync_service.dart';
import 'package:agriapp/utils/ui_utils.dart';
import 'package:agriapp/widgets/icono_sync.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <--- IMPORT AÑADIDO PARA SOLUCIONAR EL ERROR
import '../services/api_service.dart';
import 'package:agriapp/utils/app_theme.dart';
import 'package:agriapp/utils/app_palette.dart';

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
import '../pages/page_login.dart';
import '../pages/page_nota.dart'; 
import '../pages/page_operacion.dart';


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
  List<Albaran> _albaranes = [];
  List<Map<String, dynamic>> _jornadas = [];
  List<Trabajador> _trabajadores = [];
  List<Map<String, dynamic>> _notas = [];
  List<Map<String, dynamic>> _operaciones = []; // <--- AÑADE ESTA LÍNEA
  List<finca> _fincas = []; // <-- CORREGIDO AL TIPO DE OBJETO CORRECTO
  
  bool _cargandoJornadas = true;
  final ApiService _apiService = ApiService();

  static const Color colorAccion = Colors.green;
  static const Color colorEliminar = Colors.red;
  static const Color colorFondo = Colors.white;

  @override
  void initState() {
    super.initState();
    _albaranes = widget.albaranes;
    _trabajadores = widget.trabajador;
    _fincas = widget.fincas;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _superRefresh();
    });

    SyncService.syncStream.listen((finalizadoOk) {
      if (finalizadoOk && mounted) {
        _refreshAlbaranes();
        _refreshJornadas(); 
        _refreshTrabajadores(); 
      }
    });
  }

  Future<void> _forzarCierreSesion({String? mensaje}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => LoginPage(
            mensajeError: mensaje ?? 'Tu sesión ha caducado. Es necesario hacer login de nuevo.',
          ),
        ),
        (route) => false,
      );
    }
  }

  Future<void> _refreshTrabajadores() async {
    try {
      final raw = await _apiService.fetchList('tbltrabajador');
      if (mounted) {
        setState(() {
          _trabajadores = raw.map((json) => Trabajador.fromJson(json)).toList();
        });
      }
    } catch (e) {
      print("Error cargando trabajadores: $e");
    }
  }

  Future<void> _refreshJornadas() async {
    try {
      final raw = await _apiService.fetchList('tbljornada');
      if (mounted) {
        setState(() {
          _jornadas = List<Map<String, dynamic>>.from(raw);
          _cargandoJornadas = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargandoJornadas = false);
      print("Error cargando jornadas: $e");
    }
  }

Future<void> _refreshNotas() async {
    try {
      // Usamos fetchParticular para llamar a /api/notas
      final raw = await _apiService.fetchParticular('notas');
      if (mounted) {
        setState(() {
          _notas = List<Map<String, dynamic>>.from(raw);
          // Ordenamos localmente por si acaso
          _notas.sort((a, b) {
            DateTime dA = DateTime.tryParse(a['fecha_dtm']?.toString() ?? '') ?? DateTime(2000);
            DateTime dB = DateTime.tryParse(b['fecha_dtm']?.toString() ?? '') ?? DateTime(2000);
            return dB.compareTo(dA); 
          });
        });
      }
    } catch (e) {
      print("Error cargando notas: $e");
    }
  }

// Variables de estado para el Dashboard (Asegúrate de declararlas arriba en la clase)
  // List<Map<String, dynamic>> _operaciones = [];

  Future<void> _refreshOperaciones() async {
    try {
      final raw = await _apiService.fetchParticular('operacionesv2');
      if (mounted) {
        setState(() {
          _operaciones = List<Map<String, dynamic>>.from(raw);
        });
      }
    } catch (e) {
      print("Error cargando operaciones: $e");
    }
  }

List<Widget> _construirAgendaOperaciones() {
    if (_operaciones.isEmpty) {
      return [const Padding(padding: EdgeInsets.all(16), child: Text("No hay tareas registradas"))];
    }

    Map<String, Map<String, List<Map<String, dynamic>>>> agenda = {};

    for (var op in _operaciones) {
      String rawDate = op['fechainicio_dtm']?.toString() ?? op['fecha_dtm']?.toString() ?? '';
      DateTime dt = DateTime.tryParse(rawDate) ?? DateTime.now();
      
      String mesStr = DateFormat('MM/yyyy').format(dt); 
      String diaStr = DateFormat('dd/MM/yyyy').format(dt);

      agenda.putIfAbsent(mesStr, () => {});
      agenda[mesStr]!.putIfAbsent(diaStr, () => []).add(op);
    }

    var mesesOrdenados = agenda.keys.toList()..sort((a, b) {
      var pA = a.split('/');
      var pB = b.split('/');
      var dA = DateTime(int.parse(pA[1]), int.parse(pA[0]));
      var dB = DateTime(int.parse(pB[1]), int.parse(pB[0]));
      return dB.compareTo(dA);
    });

    List<Widget> ui = [];
    String mesActual = DateFormat('MM/yyyy').format(DateTime.now());

    for (String mes in mesesOrdenados) {
      bool isCurrentMonth = (mes == mesActual);
      var diasMap = agenda[mes]!;

      var diasOrdenados = diasMap.keys.toList()..sort((a, b) {
        var pA = a.split('/');
        var pB = b.split('/');
        var dA = DateTime(int.parse(pA[2]), int.parse(pA[1]), int.parse(pA[0]));
        var dB = DateTime(int.parse(pB[2]), int.parse(pB[1]), int.parse(pB[0]));
        return dB.compareTo(dA);
      });

      List<Widget> diasUI = [];
      
      for (String dia in diasOrdenados) {
        var opsDelDia = diasMap[dia]!;
        
        // CADA DÍA ES AHORA UN ACORDEÓN EXPANDIBLE
        diasUI.add(
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: true, // Desplegado por defecto
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
             title: Text(
                dia, 
                style: const TextStyle(fontWeight: FontWeight.bold, color: AgriPalette.textoVerdeOscuro),
              ),
              children: opsDelDia.map((op) {
                String tipoNombre = "Operación";
                try {
                  tipoNombre = widget.tipooperacion.firstWhere((t) => t.ktipooperacion == op['ktipooperacion']).tipooperacionStr;
                } catch (_) {}

                List trabs = op['trabajadores'] ?? [];

                return ListTile(
                  dense: true, 
                  visualDensity: const VisualDensity(vertical: -2), 
                  // ELIMINADA LA LÍNEA 'leading:' PARA QUITAR EL ICONO
                  title: Text(
                    tipoNombre, 
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AgriPalette.textoVerdeOscuro),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_outline, size: 16, color: AgriPalette.greyMain),
                      const SizedBox(width: 4),
                      Text('${trabs.length}', style: const TextStyle(color: AgriPalette.greyMain, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      const Icon(Icons.arrow_forward_ios, size: 12, color: AgriPalette.greyMain),
                    ],
                  ),
                  onTap: () async {
                    final result = await Navigator.push(context, MaterialPageRoute(
                      builder: (context) => PageOperacion(
                        usuario: widget.usuario,
                        // ¡IMPORTANTE! Pasamos _trabajadores (dinámico) en vez de widget.trabajador (estático)
                        trabajadores: _trabajadores, 
                        tiposOperacion: widget.tipooperacion,
                        operacion: op,
                        operacionesTotales: _operaciones,
                        //fincas: _fincas, // <--- AÑADIDO PARA QUE LA PÁGINA DE OPERACIÓN TENGA ACCESO A LAS FINCAS
                        fincas: _fincas.map((f) => {
                          'kfinca': f.kfinca, 
                          'nombre_str': f.nombreStr
                        }).toList(),
                      )
                    ));
                    if (result == true) _superRefresh(); 
                  },
                );
              }).toList(),
            ),
          )
        );
      }

      ui.add(
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: isCurrentMonth,
            title: Text("Mes: $mes", style: const TextStyle(fontWeight: FontWeight.w900, color: AgriPalette.textoVerdeOscuro)),
            children: diasUI,
          ),
        )
      );
    }

    return ui;
  }

//   List<Widget> _construirAgendaOperaciones() {
//     if (_operaciones.isEmpty) {
//       return [const Padding(padding: EdgeInsets.all(16), child: Text("No hay tareas registradas"))];
//     }

//     // Estructura: Mes -> (Día -> Lista de Operaciones)
//     Map<String, Map<String, List<Map<String, dynamic>>>> agenda = {};

//     for (var op in _operaciones) {
//       // Usamos fechainicio_dtm, si es nulo tiramos de fecha_dtm (fecha de creación)
//       String rawDate = op['fechainicio_dtm']?.toString() ?? op['fecha_dtm']?.toString() ?? '';
//       DateTime dt = DateTime.tryParse(rawDate) ?? DateTime.now();
      
//       String mesStr = DateFormat('MM/yyyy').format(dt); 
//       String diaStr = DateFormat('dd/MM/yyyy').format(dt);

//       agenda.putIfAbsent(mesStr, () => {});
//       agenda[mesStr]!.putIfAbsent(diaStr, () => []).add(op);
//     }

//     // ORDENACIÓN EXPLÍCITA DE MESES (De más reciente a más antiguo)
//     var mesesOrdenados = agenda.keys.toList()..sort((a, b) {
//       var pA = a.split('/');
//       var pB = b.split('/');
//       var dA = DateTime(int.parse(pA[1]), int.parse(pA[0]));
//       var dB = DateTime(int.parse(pB[1]), int.parse(pB[0]));
//       return dB.compareTo(dA);
//     });

//     List<Widget> ui = [];
//     String mesActual = DateFormat('MM/yyyy').format(DateTime.now());

//     for (String mes in mesesOrdenados) {
//       bool isCurrentMonth = (mes == mesActual);
//       var diasMap = agenda[mes]!;

//       // ORDENACIÓN EXPLÍCITA DE DÍAS (De más reciente a más antiguo)
//       var diasOrdenados = diasMap.keys.toList()..sort((a, b) {
//         var pA = a.split('/');
//         var pB = b.split('/');
//         var dA = DateTime(int.parse(pA[2]), int.parse(pA[1]), int.parse(pA[0]));
//         var dB = DateTime(int.parse(pB[2]), int.parse(pB[1]), int.parse(pB[0]));
//         return dB.compareTo(dA);
//       });

//       List<Widget> diasUI = [];
      
//       for (String dia in diasOrdenados) {
//         var opsDelDia = diasMap[dia]!;
        
//         diasUI.add(
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // --- CABECERA DEL DÍA (Más visual y compacta) ---
//               Container(
//                 width: double.infinity,
//                 margin: const EdgeInsets.only(top: 8),
//                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
//                 decoration: BoxDecoration(
//                   color: AgriPalette.greyMain.withOpacity(0.1), // Suave para diferenciar el día
//                   border: const Border(left: BorderSide(color: AgriPalette.greenMain, width: 4)),
//                 ),
//                 child: Text(
//                   dia, 
//                   style: const TextStyle(fontWeight: FontWeight.bold, color: AgriPalette.textoVerdeOscuro),
//                 ),
//               ),
              
//               // --- TAREAS COMPACTAS DEL DÍA ---
//               ...opsDelDia.map((op) {
//                 String tipoNombre = "Operación";
//                 try {
//                   tipoNombre = widget.tipooperacion.firstWhere((t) => t.ktipooperacion == op['ktipooperacion']).tipooperacionStr;
//                 } catch (_) {}

//                 List trabs = op['trabajadores'] ?? [];

//                 return ListTile(
//                   dense: true, 
//                   visualDensity: const VisualDensity(vertical: -2), // Compactación al máximo
//                   leading: const Icon(Icons.assignment_outlined, color: AgriPalette.greenMain, size: 20),
//                   title: Text(
//                     tipoNombre, 
//                     style: const TextStyle(fontWeight: FontWeight.w600, color: AgriPalette.textoVerdeOscuro),
//                   ),
//                   trailing: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       const Icon(Icons.people_outline, size: 16, color: AgriPalette.greyMain),
//                       const SizedBox(width: 4),
//                       Text('${trabs.length}', style: const TextStyle(color: AgriPalette.greyMain, fontWeight: FontWeight.bold)),
//                       const SizedBox(width: 10),
//                       const Icon(Icons.arrow_forward_ios, size: 12, color: AgriPalette.greyMain),
//                     ],
//                   ),
//                   onTap: () async {
//                     final result = await Navigator.push(context, MaterialPageRoute(
//                       builder: (context) => PageOperacion(
//                         usuario: widget.usuario,
//                         trabajadores: widget.trabajador,
//                         tiposOperacion: widget.tipooperacion,
//                         operacion: op,
//                         operacionesTotales: _operaciones,
//                       )
//                     ));
//                     if (result == true) _superRefresh(); 
//                   },
//                 );
//               }).toList(),
//             ],
//           )
//         );
//       }

//       ui.add(
//         Theme(
//           data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
//           child: ExpansionTile(
//             initiallyExpanded: isCurrentMonth,
//             title: Text("Mes: $mes", style: const TextStyle(fontWeight: FontWeight.w900, color: AgriPalette.textoVerdeOscuro)),
//             children: diasUI,
//           ),
//         )
//       );
//     }

//     return ui;
//   }
// // List<Widget> _construirAgendaOperaciones() {
//     if (_operaciones.isEmpty) {
//       return [const Padding(padding: EdgeInsets.all(16), child: Text("No hay tareas registradas"))];
//     }

//     Map<String, Map<String, List<Map<String, dynamic>>>> agenda = {};

//     for (var op in _operaciones) {
//       DateTime dt = DateTime.tryParse(op['fechainicio_dtm']?.toString() ?? '') ?? DateTime.now();
//       String mesStr = DateFormat('MM/yyyy').format(dt); 
//       String diaStr = DateFormat('dd/MM/yyyy').format(dt);

//       agenda.putIfAbsent(mesStr, () => {});
//       agenda[mesStr]!.putIfAbsent(diaStr, () => []).add(op);
//     }

//     List<Widget> ui = [];
//     String mesActual = DateFormat('MM/yyyy').format(DateTime.now());

//     agenda.forEach((mes, diasMap) {
//       bool isCurrentMonth = (mes == mesActual);

//       List<Widget> diasUI = [];
//       diasMap.forEach((dia, opsDelDia) {
//         diasUI.add(
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Barra del Día
//               Container(
//                 width: double.infinity,
//                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
//                 color: AgriPalette.greyMain.withValues(alpha: 0.1), // Usamos la paleta para el gris suave
//                 child: Text(
//                   dia, 
//                   style: const TextStyle(fontWeight: FontWeight.bold, color: AgriPalette.textoVerdeOscuro),
//                 ),
//               ),
//               // Lista compacta de Tareas del día
//               ...opsDelDia.map((op) {
//                 String tipoNombre = "Operación";
//                 try {
//                   tipoNombre = widget.tipooperacion.firstWhere((t) => t.ktipooperacion == op['ktipooperacion']).tipooperacionStr;
//                 } catch (_) {}

//                 List trabs = op['trabajadores'] ?? [];

//                 return ListTile(
//                   dense: true, // Reduce aún más la altura del elemento
//                   visualDensity: const VisualDensity(vertical: -2), // Compactación máxima permitida por Material
//                   leading: const Icon(Icons.assignment_outlined, color: AgriPalette.greenMain, size: 20),
//                   title: Text(
//                     tipoNombre, 
//                     style: const TextStyle(fontWeight: FontWeight.w600, color: AgriPalette.textoVerdeOscuro),
//                   ),
//                   trailing: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       const Icon(Icons.people_outline, size: 16, color: AgriPalette.greyMain),
//                       const SizedBox(width: 4),
//                       Text(
//                         '${trabs.length}', 
//                         style: const TextStyle(color: AgriPalette.greyMain, fontWeight: FontWeight.bold),
//                       ),
//                       const SizedBox(width: 10),
//                       const Icon(Icons.arrow_forward_ios, size: 12, color: AgriPalette.greyMain),
//                     ],
//                   ),
//                   onTap: () async {
//                     final result = await Navigator.push(context, MaterialPageRoute(
//                       builder: (context) => PageOperacion(
//                         usuario: widget.usuario,
//                         trabajadores: widget.trabajador,
//                         tiposOperacion: widget.tipooperacion,
//                         operacion: op,
//                         operacionesTotales: _operaciones,
//                       )
//                     ));
//                     if (result == true) _superRefresh(); 
//                   },
//                 );
//               }).toList(),
//             ],
//           )
//         );
//       });

//       ui.add(
//         Theme(
//           data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
//           child: ExpansionTile(
//             initiallyExpanded: isCurrentMonth,
//             title: Text(
//               "Mes: $mes", 
//               style: const TextStyle(fontWeight: FontWeight.w900, color: AgriPalette.textoVerdeOscuro),
//             ),
//             children: diasUI,
//           ),
//         )
//       );
//     });

//     return ui;
//   }


  Stream<List<Albaran>> _getAlbaranesStream() async* {
    while (true) {
      final localData = await DBService.instance.getAllFromLocal('albaranesv2'); 
      List<Albaran> albaranesAPI = localData.map((json) => Albaran.fromJson(json)).toList();

      final db = await DBService.instance.database;
      final resPendientes = await db.query('pendientes_sincro', where: 'entidad = ?', whereArgs: ['albaran']);
      
      List<Albaran> albaranesPendientes = resPendientes.map((item) {
        final Map<String, dynamic> datos = jsonDecode(item['datos_json'] as String);
        return Albaran.fromJson(datos);
      }).toList();

      List<Albaran> listaTotal = [...albaranesPendientes, ...albaranesAPI];
      listaTotal.sort((a, b) => b.fecha.compareTo(a.fecha));

      yield listaTotal;
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  Future<void> _logout() async {
    bool? confirmar = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Cerrar Sesión", 
          style: TextStyle(color: AgriPalette.greenMain, fontWeight: FontWeight.bold)
        ),
        content: const Text("¿Estás seguro de que quieres salir de AgriAPP?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCELAR", style: TextStyle(color: AgriPalette.greyMain)),
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
        await SyncService.sincronizarTodo();
        await DBService.instance.borrarBaseDeDatosFisica();
        await _forzarCierreSesion(mensaje: ''); 
      } catch (e) {
        if (e.toString().contains("Expired token") || e.toString().contains("401")) {
          await _forzarCierreSesion();
        }
      }
    }
  }

  Future<void> _refreshAlbaranes() async {
    _albaranes = (await _apiService.fetchParticular('albaranesv2'))
        .map((json) => Albaran.fromJson(json))
        .toList();
        
    mensajeEmergente(context, 'Datos Actualizados', segundos: 1);
    setState(() {}); 
  }

  Future<void> _superRefresh() async {
    try {
      await SyncService.sincronizarTodo();
      await _refreshAlbaranes();
      await _refreshTrabajadores(); 
      await _refreshJornadas();
      await _refreshNotas();
      await _refreshOperaciones(); 
      setState(() {}); 
    } catch (e) {
      if (e.toString().contains("Expired token") || e.toString().contains("401")) {
        await _forzarCierreSesion();
      }
    }
  }

  Future<void> _confirmDeleteDetalle(MovimientoVisual m) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar línea?'),
        content: Text('Se eliminará la línea ${m.detalleOriginal.linea} (${m.nombreProducto} - ${m.kg} kg).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colorEliminar),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: colorFondo)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiService.deleteGeneric('tblalbarandetalle', m.detalleOriginal.kalbarandetalle);
        await _refreshAlbaranes();
        if (mounted) {
          mensajeEmergente(context, "Línea eliminada correctamente");
        }
      } catch (e) {
        if (!mounted) return;
        mensajeEmergente(context, 'Error al eliminar línea: $e', tipo: 'error');
      }
    }
  }

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
          albaranesTotales: _albaranes,
        ),
      ),
    );

    if (result == true) { await _refreshAlbaranes(); }
  }

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

  @override
  Widget build(BuildContext context) {
    final todosLosMovimientos = _aplanarMovimientos();

    final String uuidIngreso =  "b42f149b-6744-11f0-ac9b-e2b6c6b4d8df"; 
    final String uuidGasto = "c4755f6d-6744-11f0-ac9b-e2b6c6b4d8df";   

    final ingresos = todosLosMovimientos.where((m) => m.albaranPadre.ktipoalbaran == uuidIngreso).toList();
    final gastos = todosLosMovimientos.where((m) => m.albaranPadre.ktipoalbaran == uuidGasto).toList();

    final totalKgIngresos = ingresos.fold<double>(0, (sum, item) => sum + item.kg);
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
              ),            
              
              //_buildSection('Operaciones', onAdd: () {}),
            _buildSection2(
                'Operaciones',
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    color: AgriPalette.greenMain,
                    onPressed: () async {
                      final result = await Navigator.push(context, MaterialPageRoute(
                        builder: (context) => PageOperacion(
                          usuario: widget.usuario,
                          trabajadores: _trabajadores, // <--- AQUÍ TAMBIÉN (estaba widget.trabajador)
                          tiposOperacion: widget.tipooperacion,
                          //fincas: _fincas, // <--- AÑADIDO EN LOS DOS SITIOS (Botón + y edición)
                          fincas: _fincas.map((f) => {
                          'kfinca': f.kfinca, 
                          'nombre_str': f.nombreStr
                        }).toList(),
                          operacionesTotales: _operaciones,
                        )
                      ));
                      if (result == true) _superRefresh();
                    },
                  ),
                ],
                child: Column(children: _construirAgendaOperaciones()),
              ),


              _buildSection2(
                'Jornadas',
                actions: [
                  IconButton(
                    icon: const Icon(Icons.analytics_outlined),
                    color: AgriPalette.greyMain,
                    tooltip: 'Informes',
                    onPressed: () { /* Navegar a Informes */ },
                  ),
                  // IconButton(
                  //   icon: const Icon(Icons.people_outline),
                  //   color: AgriPalette.greenMain,
                  //   tooltip: 'Gestión Personal',
                  //   onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PageTrabajadores())),
                  // ),
                  IconButton(
                    icon: const Icon(Icons.people_outline),
                    color: AgriPalette.greenMain,
                    tooltip: 'Gestión Personal',
                    onPressed: () async { // <-- 1. Añade 'async'
                      final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const PageTrabajadores()));
                      
                      
                      // 3. Cuando la pantalla se cierre y vuelva al Dashboard, forzamos el refresco:
                      if (result == true) { 
                        await _superRefresh(); 
                      } else {
                        // Por si acaso no devuelves 'true' al hacer pop en la otra pantalla, 
                        // puedes simplemente forzarlo siempre poniendo solo: await _superRefresh();
                        await _superRefresh();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    color: AgriPalette.greenMain,
                    tooltip: 'Añadir Jornada',
                    onPressed: () async {
                      final bool? guardadoOk = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PageJornadaAdd(trabajadores: _trabajadores),
                        ),
                      );

                      if (guardadoOk == true) {
                        _refreshJornadas(); 
                      }
                    },
                  ),
                ],
                child: _cargandoJornadas 
                  ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())) 
                  : Column(children: _construirHistorialJornadas()),
              ),

              // _buildSection('Notas', onAdd: () {}),
              _buildSection2(
                'Notas',
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    color: AgriPalette.greenMain,
                    tooltip: 'Añadir Nota',
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => PageNota(usuario: widget.usuario)),
                      );
                      if (result == true) _refreshNotas();
                    },
                  ),
                ],
                child: Column(children: _construirHistorialNotas()),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _construirHistorialJornadas() {
    List<Widget> mesesUI = [];
    DateTime ahora = DateTime.now();
    
    for (int i = 0; i < 12; i++) {
      DateTime mesActual = DateTime(ahora.year, ahora.month - i, 1);
      String labelMes = DateFormat('yyyy/MM').format(mesActual);
      
      var jornadasMes = _jornadas.where((j) {
         DateTime? d = DateTime.tryParse(j['fecha_dtm']?.toString() ?? '');
         return d != null && 
                d.year == mesActual.year && 
                d.month == mesActual.month && 
                j['eliminado_bit'] != 1 && 
                j['eliminado_bit'] != true;
      }).toList();
      
      Set<String> diasUnicos = {};
      double horasTotales = 0;
      int totalRegistrosPersonas = jornadasMes.length;
      
      for(var j in jornadasMes) {
         diasUnicos.add(j['fecha_dtm'].toString());
         horasTotales += double.tryParse(j['horas_flt']?.toString() ?? '0') ?? 0;
      }
      
      int dias = diasUnicos.length;
      double personasMedia = dias > 0 ? (totalRegistrosPersonas / dias) : 0.0;
      String personasStr = (personasMedia % 1 == 0) 
        ? personasMedia.toInt().toString() 
        : personasMedia.toStringAsFixed(1);
      
      mesesUI.add(
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            dense: true,
            visualDensity: const VisualDensity(vertical: -3), 
            tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            title: Row(
              children: [
                Text(
                  labelMes, 
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)
                ),
                const SizedBox(width: 12),
                Text(
                  "${dias}D, ${horasTotales.toStringAsFixed(0)}h, ${personasStr}p",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AgriPalette.greyMain),
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                child: _construirCalendarioMensual(mesActual.year, mesActual.month, jornadasMes),
              )
            ],
          ),
        )
      );
    }
    return mesesUI;
  }

List<Widget> _construirHistorialNotas() {
    if (_notas.isEmpty) {
      return [const Padding(padding: EdgeInsets.all(16), child: Text("No hay notas registradas"))];
    }

    Map<String, List<Map<String, dynamic>>> notasAgrupadas = {};
    for (var n in _notas) {
      DateTime d = DateTime.tryParse(n['fecha_dtm']?.toString() ?? '') ?? DateTime.now();
      String mesStr = DateFormat('yyyy/MM').format(d);
      notasAgrupadas.putIfAbsent(mesStr, () => []).add(n);
    }

    String mesActualStr = DateFormat('yyyy/MM').format(DateTime.now());
    List<Widget> mesesUI = [];

    for (var entry in notasAgrupadas.entries) {
      String mes = entry.key;
      List<Map<String, dynamic>> notasMes = entry.value;
      bool isCurrentMonth = (mes == mesActualStr);

      mesesUI.add(
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: isCurrentMonth,
            title: Text(mes, style: const TextStyle(fontWeight: FontWeight.bold)),
            children: notasMes.map((nota) {
              String titulo = nota['titulo_str'] ?? 'Sin título';
              String fecha = '';
              if (nota['fecha_dtm'] != null) {
                fecha = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(nota['fecha_dtm']));
              }
              
              return ListTile(
                dense: true, // Reduce el tamaño general de las fuentes y márgenes
                visualDensity: const VisualDensity(vertical: -4), // Reduce el interlineado/altura al máximo
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0.0), // Elimina padding interno
                // ELIMINADA LA LÍNEA 'leading' CON EL ICONO
                title: Text(titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(fecha),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () async {
                  // NAVEGACIÓN CORREGIDA PARA PUNTO 2
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PageNota(
                        usuario: widget.usuario,
                        // Pasamos el Map 'nota' completo que estamos iterando
                        nota: nota, 
                      ),
                    ),
                  );
                  // Si vuelve con true, recargamos la lista
                  if (result == true) _refreshNotas();
                },
              );
            }).toList(),
          ),
        ),
      );
    }
    return mesesUI;
  }

  Widget _construirCalendarioMensual(int year, int month, List<Map<String,dynamic>> jornadasMes) {
    int daysInMonth = DateTime(year, month + 1, 0).day;
    int firstWeekday = DateTime(year, month, 1).weekday; 
    
    List<Widget> dayWidgets = [];
    
    List<String> diasSemana = ['L','M','X','J','V','S','D'];
    for(var d in diasSemana) {
      dayWidgets.add(Center(child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12))));
    }
    
    for(int i = 1; i < firstWeekday; i++) {
      dayWidgets.add(const SizedBox());
    }
    
    for(int d = 1; d <= daysInMonth; d++) {
      String dateStr = "$year-${month.toString().padLeft(2,'0')}-${d.toString().padLeft(2,'0')}";
      
      var jornadasDia = jornadasMes.where((j) => j['fecha_dtm']?.toString().startsWith(dateStr) == true).toList();
      bool hasData = jornadasDia.isNotEmpty;
      
      dayWidgets.add(
        InkWell(
          onTap: hasData ? () => _mostrarDetalleJornada(dateStr, jornadasDia) : null,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: hasData ? AgriPalette.greenMain : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$d', 
                style: TextStyle(
                  fontWeight: hasData ? FontWeight.bold : FontWeight.normal,
                  color: hasData ? Colors.white : Colors.black87
                )
              )
            ),
          )
        )
      );
    }
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      childAspectRatio: 1.2,
      children: dayWidgets,
    );
  }

  void _mostrarDetalleJornada(String fechaStr, List<Map<String, dynamic>> jornadasDia) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Jornada del ${fechaStr.split('-').reversed.join('/')}", 
                    style: Theme.of(context).textTheme.titleLarge
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_calendar),
                    color: AgriPalette.greenMain,
                    tooltip: 'Editar Jornada',
                    onPressed: () async {
                      Navigator.pop(context); 
                      
                      final bool? guardadoOk = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PageJornadaAdd(
                            trabajadores: _trabajadores,
                            fechaInicial: DateTime.parse(fechaStr), 
                            jornadasExistentes: jornadasDia,        
                          ),
                        ),
                      );

                      if (guardadoOk == true) {
                        _refreshJornadas();
                      }
                    },
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              Flexible( 
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: jornadasDia.length,
                  itemBuilder: (context, index) {
                    final j = jornadasDia[index];
                    final String tId = (j['ktrabajador'] ?? '').toString().trim().toLowerCase();
                    
                    final trabajador = _trabajadores.firstWhere(
                      (t) => t.ktrabajador.trim().toLowerCase() == tId, 
                      orElse: () => Trabajador(
                        ktrabajador: '', 
                        nombreStr: 'Desconocido', 
                        kagricultor: '', 
                        eliminadoBit: 0, 
                        fechaDtm: DateTime.now()
                      )
                    );

                    final horas = j['horas_flt']?.toString() ?? '0';
                    final obs = j['observaciones_str']?.toString() ?? '';
                    
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(backgroundColor: AgriPalette.greenMain, child: const Icon(Icons.person, color: Colors.white, size: 20)),
                      title: Text(trabajador.nombreStr, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(obs.isNotEmpty ? "Horas: $horas | Obs: $obs" : "Horas: $horas"),
                    );
                  }
                )
              )
            ]
          )
        );
      }
    );
  }

  Widget _buildSection(String title, {required VoidCallback onAdd, Widget? child}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ExpansionTile( 
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
        trailing: actions != null 
            ? Row(mainAxisSize: MainAxisSize.min, children: actions) 
            : null,
        children: [
          if (child != null) child,
        ],
      ),
    );
  }

  List<MovimientoVisual> _aplanarMovimientos() {
    List<MovimientoVisual> listaPlana = [];
    final Map<String, Almacen> mapAlmacenes = {for (var a in widget.almacen) a.kalmacen: a};
    final Map<String, finca> mapFincas = {for (var f in widget.fincas) f.kfinca: f};
    final Map<String, Producto> mapProductos = {for (var p in widget.producto) p.kproducto: p};

    for (var alb in _albaranes) {
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

  Widget _construirNivelDinamicamente(List<MovimientoVisual> datosNodo, List<String> criterios, int indexCriterio) {
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
                  onPressed: () => _confirmDeleteDetalle(m),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    String criterioActual = criterios[indexCriterio].trim().toLowerCase();
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
          key = "${m.fecha.year}-${m.fecha.month.toString().padLeft(2, '0')}";
          etiqueta = "${m.fecha.year}-${m.fecha.month.toString().padLeft(2, '0')}"; 
          break;
        case 'fecha':
          key = "${m.fecha.year}-${m.fecha.month.toString().padLeft(2, '0')}-${m.fecha.day.toString().padLeft(2, '0')}";
          etiqueta = '${m.fecha.day.toString().padLeft(2,'0')}/${m.fecha.month.toString().padLeft(2,'0')}/${m.fecha.year}';
          break;
        default: key = "desconocido"; etiqueta = "Otros";
      }
      if (key.isEmpty) key = "vacio_$indexCriterio";
      agrupados.putIfAbsent(key, () => []).add(m);
      etiquetasLegibles[key] = etiqueta;
    }

    var listaEntradas = agrupados.entries.toList();

    if (criterioActual == 'fecha' || criterioActual == 'mes') {
      listaEntradas.sort((a, b) => b.key.compareTo(a.key));
    } else {
      listaEntradas.sort((a, b) => etiquetasLegibles[a.key]!.compareTo(etiquetasLegibles[b.key]!));
    }

    return Column(
      children: listaEntradas.map((entry) {
        final subLista = entry.value;
        final bool esGasto = subLista.every((m) => m.albaranPadre.ktipoalbaran == "c4755f6d-6744-11f0-ac9b-e2b6c6b4d8df");
        
        final subTotalKg = subLista.fold<double>(0, (sum, m) => sum + m.kg);
        final subTotalEuros = subLista.fold<double>(0, (sum, m) => sum + (m.kg * (m.detalleOriginal.precio ?? 0.0)));
        
        String tituloFinal = etiquetasLegibles[entry.key] ?? "Sin nombre";

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