import 'package:agriapp/pages/page_usuario.dart';
import 'package:agriapp/utils/ui_utils.dart';
import 'package:agriapp/widgets/icono_sync.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  
  // Lista local de albaranes que podemos refrescar sin salir de la página.
  List<Albaran> _albaranes = [];
  
  // Motor de conexión con la API
  final ApiService _apiService = ApiService();

  // Colores constantes para mantener la estética uniforme.
  static const Color colorAccion = Colors.green;
  static const Color colorEliminar = Colors.red;
  static const Color colorFondo = Colors.white;

  @override
  void initState() {
    super.initState();
    // Al iniciar, cargamos los albaranes que nos pasaron desde el login.
    _albaranes = widget.albaranes;
  }

  /// [logout] Borra el token de seguridad del teléfono y vuelve atrás.
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    Navigator.of(context).pop();
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
          _albaranes = (await _apiService.fetchParticular('albaranes'))
          .map((json) => Albaran.fromJson(json)).toList();
     mensajeEmergente(context, 'Albaranes Actualizados', segundos: 1);

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

@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
              centerTitle: false,
              // En lugar de usar 'leading', ponemos todo en el 'title' 
              // para que fluya de forma natural hacia la derecha.
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTheme.buildLogo(fontSize: 22), // El logo mixto
                  const SizedBox(width: 22),        // Un poco de separación
                  Expanded(
                    child: Text(
                      '${widget.usuario.nombre} ${widget.usuario.apellidos}',
                      style:  Theme.of(context).textTheme.titleMedium, //const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                      overflow: TextOverflow.ellipsis, // Por si el nombre es muy largo
                    ),
                  ),
                ],
              ),

        // 3. ICONOS DE FUNCIÓN A LA DERECHA (se mantienen en actions)
        actions: [
          const IconoSync(),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sincronizar', // Ayuda al usuario
            onPressed: _refreshAll,
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sección principal de Albaranes (con cálculos de kilos)
          _buildAlbaranesSection(),
          
          // Secciones secundarias (TODO: Implementar sus páginas específicas)
          _buildSection('Gastos', onAdd: () {}),
          _buildSection('Operaciones', onAdd: () {}),
          _buildSection('Jornadas', onAdd: () {}, extra: const Text("Último día: 2025/05/19")),
          _buildSection('Notas', onAdd: () {}),
        ],
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
            'Albaranes: ${totalKg.toStringAsFixed(2)} kg', 
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
                            final albaran = _albaranes.firstWhere((a) => a.kalbaran == aEntry.key);
                            final albaranKg = aEntry.value.fold<double>(0, (sum, d) => sum + d.kg);
                            final expanded = _expandedAlbaranes[aEntry.key] ?? false;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  title: Text('${albaran.fecha.day}/${albaran.fecha.month}/${albaran.fecha.year} - ${albaranKg.toStringAsFixed(0)} kg', style:  Theme.of(context).textTheme.bodyLarge,),
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
                                            ktipoproducto: '',      // <--- Nuevo campo obligatorio
                                            tipoproductoStr: '',    // <--- Nuevo campo obligatorio
                                          ),
                                        );
                                        
                                        return ListTile(
                                          dense: true,
                                          // Mostramos la línea, el nombre del producto y los kg
                                          title: Text('Línea ${d.linea}: ${producto.productoStr} -> ${d.kg.toStringAsFixed(2)} kg',style:  Theme.of(context).textTheme.bodyMedium,),
                                          // Opcional: Podrías añadir el tipo de producto como subtítulo si quieres
                                          subtitle: Text(producto.tipoproductoStr, style:  Theme.of(context).textTheme.bodySmall),//const TextStyle(fontSize: 10)),
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
  Widget _buildSection(String title, {required VoidCallback onAdd, Widget? extra}) {
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
                Text(title, style:  Theme.of(context).textTheme.titleLarge),//const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.add),  color: AgriPalette.greenMain, onPressed: onAdd),
              ],
            ),
            if (extra != null) extra, // Si pasamos un widget extra (como la fecha de jornadas), se muestra aquí.
          ],
        ),
      ),
    );
  }
}