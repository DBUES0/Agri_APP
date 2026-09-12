import 'dart:convert';
import 'package:agriapp/pages/page_usuario.dart';
import 'package:agriapp/services/db_service.dart';
import 'package:agriapp/services/sync_service.dart';
import 'package:agriapp/utils/ui_utils.dart';
import 'package:agriapp/widgets/icono_sync.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // <--- IMPORTANTE PARA EL FORMATEO DE MESES
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
  final Map<String, bool> _expandedFincas = {};
  final Map<String, bool> _expandedAlbaranes = {};
  
  bool _albaranesExpanded = false;
  bool _albaranes2Expanded = false;
  
  List<Albaran> _albaranes = [];
  
  // --- NUEVAS VARIABLES PARA JORNADAS ---
  List<Map<String, dynamic>> _jornadas = [];
  List<Trabajador> _trabajadores = [];
  
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _superRefresh();
    });

    SyncService.syncStream.listen((finalizadoOk) {
      if (finalizadoOk && mounted) {
        _refreshAlbaranes();
        _refreshJornadas(); // Recargamos jornadas si hay sincro
        _refreshTrabajadores(); // Recargamos trabajadores si hay sincro
      }
    });
  }

  // --- NUEVA FUNCIÓN: CARGAR TRABAJADORES ---
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
  // --- NUEVA FUNCIÓN: CARGAR JORNADAS ---
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
            onPressed: 
                       () => Navigator.pop(context, true),
            child: const Text("SALIR", style: TextStyle(color: Colors.white))
            ,
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await SyncService.sincronizarTodo();
        //DBService.instance.limpiarTodaLaBaseDeDatos();
        await DBService.instance.borrarBaseDeDatosFisica();
        if (mounted) await _apiService.cerrarSesion(context);
      } catch (e) {
        if (e.toString().contains("Expired token") && mounted) {
          await _apiService.cerrarSesion(context);
        }
      }
    }
  }

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

  Future<void> _refreshAll() async {
    await _refreshAlbaranes();
    await _refreshGastos();
    await _refreshOperaciones();
    await _refreshJornadas();
    DBService.instance.limpiarTodaLaBaseDeDatos();
  }

  Future<void> _refreshAlbaranes() async {
    _albaranes = (await _apiService.fetchParticular('albaranesv2'))
        .map((json) => Albaran.fromJson(json))
        .toList();
        
    mensajeEmergente(context, 'Datos Actualizados', segundos: 1);
    setState(() {}); 
  }

  // Método para refrescar todos los datos de la app, incluyendo albaranes, gastos, operaciones y jornadas. Se puede llamar desde un botón de sincronización manual.
  Future<void> _superRefresh() async {
    await SyncService.sincronizarTodo();
    await _refreshAlbaranes();
    await _refreshTrabajadores(); // <--- AÑADIR ESTA LÍNEA
    await _refreshJornadas();
    setState(() {}); 
  }

  Future<void> _refreshGastos() async {
    mensajeEmergente(context, 'Simulando refresco de Gastos...',segundos: 1 );
  }

  Future<void> _refreshOperaciones() async {
    mensajeEmergente(context, 'Simulando refresco de Operaciones...',segundos: 1);
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
            // 1. Usamos deleteGeneric: tu API ya marca eliminado_bit = 1 y fechaeliminacion_dtm
            await _apiService.deleteGeneric('tblalbaran', albaran.kalbaran);

            for (var detalle in albaran.detalles) {
              if (detalle.kalbarandetalle.isNotEmpty) {
                await _apiService.deleteGeneric('tblalbarandetalle', detalle.kalbarandetalle);
              }
            }

            // 2. Si usas tabla SQLite local, borramos el registro para que el Stream no lo resucite
            final db = await DBService.instance.database;
            await db.delete('pendientes_sincro', where: 'id = ?', whereArgs: [albaran.kalbaran]);

            // 3. Forzamos la recarga de datos frescos del servidor
            await _refreshAlbaranes();

            if (mounted) {
              mensajeEmergente(context, "Albarán eliminado correctamente");
            }
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
              
              _buildSection('Operaciones', onAdd: () {}),
              
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
                          builder: (context) => PageJornadaAdd(trabajadores: widget.trabajador),
                        ),
                      );
                    },
                  ),
                ],
                // Sustituimos el texto estático por el bloque dinámico de los últimos 12 meses
                child: _cargandoJornadas 
                  ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())) 
                  : Column(children: _construirHistorialJornadas()),
              ),

              _buildSection('Notas', onAdd: () {}),
            ],
          );
        },
      ),
    );
  }

  // ==========================================================================
  // MOTOR DEL HISTORIAL Y CALENDARIO DE JORNADAS
  // ==========================================================================

  List<Widget> _construirHistorialJornadas() {
    List<Widget> mesesUI = [];
    DateTime ahora = DateTime.now();
    
    for (int i = 0; i < 12; i++) {
      // Dart maneja automáticamente los cambios de año si le restamos meses (ej: 0 es diciembre del año anterior)
      DateTime mesActual = DateTime(ahora.year, ahora.month - i, 1);
      String labelMes = DateFormat('yyyy/MM').format(mesActual);
      
      // Filtrar jornadas que correspondan a este año y mes, y no estén borradas
      var jornadasMes = _jornadas.where((j) {
         DateTime? d = DateTime.tryParse(j['fecha_dtm']?.toString() ?? '');
         return d != null && 
                d.year == mesActual.year && 
                d.month == mesActual.month && 
                j['eliminado_bit'] != 1 && 
                j['eliminado_bit'] != true;
      }).toList();
      
      // Calculamos: 22D, 2337h, 7p
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
            visualDensity: const VisualDensity(vertical: -3), // Reduce la altura vertical al mínimo
            tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            // Ponemos fecha y resumen en la misma línea
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

  Widget _construirCalendarioMensual(int year, int month, List<Map<String,dynamic>> jornadasMes) {
    int daysInMonth = DateTime(year, month + 1, 0).day;
    int firstWeekday = DateTime(year, month, 1).weekday; // 1 = Lunes, 7 = Domingo
    
    List<Widget> dayWidgets = [];
    
    // Cabeceras (L M X J V S D)
    List<String> diasSemana = ['L','M','X','J','V','S','D'];
    for(var d in diasSemana) {
      dayWidgets.add(Center(child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12))));
    }
    
    // Espacios vacíos antes del primer día del mes
    for(int i = 1; i < firstWeekday; i++) {
      dayWidgets.add(const SizedBox());
    }
    
    // Días del mes
    for(int d = 1; d <= daysInMonth; d++) {
      String dateStr = "$year-${month.toString().padLeft(2,'0')}-${d.toString().padLeft(2,'0')}";
      
      // Extraemos todas las jornadas registradas ese día
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
              Text("Jornada del ${fechaStr.split('-').reversed.join('/')}", style: Theme.of(context).textTheme.titleLarge),
              const Divider(),
              const SizedBox(height: 8),
              Flexible( // Flexible evita que ListView reviente la altura del BottomSheet
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: jornadasDia.length,
                  itemBuilder: (context, index) {
                    final j = jornadasDia[index];
                    // Normalizamos el ID de la jornada a minúsculas y sin espacios
                    final String tId = (j['ktrabajador'] ?? '').toString().trim().toLowerCase();
                    //final tId = j['ktrabajador'];
                    
                    // Cruzamos con el maestro de trabajadores para obtener el nombre
                    // final trabajador = widget.trabajador.firstWhere(
                    //   (t) => t.ktrabajador == tId, 
                    //   orElse: () => Trabajador(ktrabajador: '', nombreStr: 'Desconocido', kagricultor: '', eliminadoBit: 0, fechaDtm: DateTime.now())
                    // );
                    // Buscamos en _trabajadores comparando en minúsculas
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

  // ==========================================================================
  // BLOQUE DE UI DE SECCIONES ESTÁNDAR Y ALBARANES
  // ==========================================================================

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
                  //onPressed: () => _confirmDeleteAlbaran(m.albaranPadre),
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