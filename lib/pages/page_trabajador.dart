// //lib/pages/page_trabajador.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/record_trabajador.dart';
import '../services/api_service.dart';
import '../utils/app_palette.dart';
import '../utils/ui_utils.dart'; // Para mensajeEmergente
import 'page_trabajador_add.dart';
import 'page_trabajador_perfil.dart'; // <--- Nueva página que crearemos

class PageTrabajadores extends StatefulWidget {
  const PageTrabajadores({Key? key}) : super(key: key);

  @override
  State<PageTrabajadores> createState() => _PageTrabajadoresState();
}

class _PageTrabajadoresState extends State<PageTrabajadores> {
  final ApiService _apiService = ApiService();
  
  List<Trabajador> _todosLosTrabajadores = [];
  List<Trabajador> _trabajadoresFiltrados = [];

  bool _cargando = true;
  bool _mostrarSoloActivos = true; 
  String _busqueda = "";
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarTrabajadores();
  }

  Future<void> _cargarTrabajadores() async {
    setState(() => _cargando = true);
    try {
      final rawData = await _apiService.fetchList('tbltrabajador');
      _todosLosTrabajadores = rawData.map((json) => Trabajador.fromJson(json)).toList();
      _filtrarYOrdenar();
    } catch (e) {
      print("Error cargando trabajadores: $e");
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _filtrarYOrdenar() {
    List<Trabajador> temp = _todosLosTrabajadores.where((t) {
      final nombreCoincide = t.nombreStr.toLowerCase().contains(_busqueda.toLowerCase());
      if (!nombreCoincide) return false;
      if (t.eliminadoBit == 1) return false; // Ocultar borrados lógicos

      bool esActivo = _calcularSiEsActivo(t);

      if (_mostrarSoloActivos && !esActivo) return false;

      return true; 
    }).toList();

    temp.sort((a, b) {
      final fechaA = a.fechaDtm ?? DateTime(2000);
      final fechaB = b.fechaDtm ?? DateTime(2000);
      return fechaB.compareTo(fechaA); 
    });

    setState(() {
      _trabajadoresFiltrados = temp;
    });
  }

  bool _calcularSiEsActivo(Trabajador t) {
    bool esActivo = false;
    final hoy = DateTime.now();
    final fechaHoyLimpia = DateTime(hoy.year, hoy.month, hoy.day);

    if (t.fechainicioultimocontratoDtm != null) {
      final inicio = DateTime(t.fechainicioultimocontratoDtm!.year, t.fechainicioultimocontratoDtm!.month, t.fechainicioultimocontratoDtm!.day);
      if (!inicio.isAfter(fechaHoyLimpia)) esActivo = true;
    }
    if (esActivo && t.fechafinultimocontratoDtm != null) {
      final fin = DateTime(t.fechafinultimocontratoDtm!.year, t.fechafinultimocontratoDtm!.month, t.fechafinultimocontratoDtm!.day);
      if (fin.isBefore(fechaHoyLimpia)) esActivo = false;
    }
    return esActivo;
  }

  // --- ACCIONES DE LOS TRABAJADORES ---

  Future<void> _cambiarEstadoContrato(Trabajador t, bool darDeAlta) async {
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    try {
      if (darDeAlta) {
        // Al dar de alta, actualizamos la fecha de inicio a hoy y limpiamos la fecha de fin
        await _apiService.putGeneric('tbltrabajador', t.ktrabajador, {
          'fechainicioultimocontrato_dtm': hoy,
          'fechafinultimocontrato_dtm': null
        });
        mensajeEmergente(context, 'Trabajador dado de ALTA correctamente', tipo: 'success');
      } else {
        // Al dar de baja, ponemos la fecha de fin a hoy
        await _apiService.putGeneric('tbltrabajador', t.ktrabajador, {
          'fechafinultimocontrato_dtm': hoy
        });
        mensajeEmergente(context, 'Trabajador dado de BAJA correctamente', tipo: 'warning');
      }
      _cargarTrabajadores();
    } catch (e) {
      mensajeEmergente(context, 'Error al cambiar estado: $e', tipo: 'error');
    }
  }

  Future<void> _eliminarTrabajador(Trabajador t) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar trabajador?'),
        content: Text('¿Seguro que deseas eliminar a ${t.nombreStr}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Eliminar', style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _apiService.deleteGeneric('tbltrabajador', t.ktrabajador);
        mensajeEmergente(context, 'Trabajador eliminado');
        _cargarTrabajadores();
      } catch (e) {
        mensajeEmergente(context, 'Error al eliminar: $e', tipo: 'error');
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gestión de personal")),
      body: Column(
        children: [
          // --- BARRA DE BÚSQUEDA Y CHECKBOX (MÁS COMPACTA) ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), // Menos padding vertical
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 45, // Forzamos una altura más pequeña
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Buscar por nombre...',
                        prefixIcon: const Icon(Icons.search, color: AgriPalette.greenMain),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (valor) {
                        _busqueda = valor;
                        _filtrarYOrdenar(); 
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    setState(() {
                      _mostrarSoloActivos = !_mostrarSoloActivos;
                      _filtrarYOrdenar();
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _mostrarSoloActivos,
                        activeColor: AgriPalette.greenMain,
                        visualDensity: VisualDensity.compact, // Checkbox más pequeño
                        onChanged: (valor) {
                          setState(() {
                            _mostrarSoloActivos = valor ?? true;
                            _filtrarYOrdenar();
                          });
                        },
                      ),
                      const Text("Activos", style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // --- LISTA DE TRABAJADORES ---
          Expanded(
            child: _cargando 
              ? const Center(child: CircularProgressIndicator())
              : _trabajadoresFiltrados.isEmpty
                  ? const Center(child: Text("No se encontraron trabajadores"))
                  : ListView.builder(
                      itemCount: _trabajadoresFiltrados.length,
                      itemBuilder: (context, index) {
                        final t = _trabajadoresFiltrados[index];
                        final bool esActivo = _calcularSiEsActivo(t);

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: esActivo ? AgriPalette.greenMain : Colors.grey.shade400,
                            child: const Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(
                            t.nombreStr, 
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: esActivo ? null : TextDecoration.lineThrough,
                              color: esActivo ? Colors.black87 : Colors.grey.shade600,
                            ),
                          ),
                          subtitle: Text(t.dniStr != null && t.dniStr!.isNotEmpty ? t.dniStr! : "Sin DNI"),
                          
                          // CLICK NORMAL: Ver Perfil
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => PageTrabajadorPerfil(trabajador: t, esActivo: esActivo)),
                            );
                          },

                          // CLICK EN TRES PUNTITOS: Acciones
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: AgriPalette.greyMain),
                            onSelected: (String result) async {
                              if (result == 'editar') {
                                final res = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => PageTrabajadorForm(trabajador: t)),
                                );
                                if (res == true) _cargarTrabajadores();
                              } else if (result == 'alta') {
                                _cambiarEstadoContrato(t, true);
                              } else if (result == 'baja') {
                                _cambiarEstadoContrato(t, false);
                              } else if (result == 'eliminar') {
                                _eliminarTrabajador(t);
                              }
                            },
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(
                                value: 'editar',
                                child: ListTile(leading: Icon(Icons.edit, color: AgriPalette.greenMain), title: Text('Editar'), contentPadding: EdgeInsets.zero, dense: true),
                              ),
                              if (!esActivo)
                                const PopupMenuItem<String>(
                                  value: 'alta',
                                  child: ListTile(leading: Icon(Icons.person_add, color: Colors.blue), title: Text('Dar de Alta'), contentPadding: EdgeInsets.zero, dense: true),
                                ),
                              if (esActivo)
                                const PopupMenuItem<String>(
                                  value: 'baja',
                                  child: ListTile(leading: Icon(Icons.person_remove, color: Colors.orange), title: Text('Dar de Baja'), contentPadding: EdgeInsets.zero, dense: true),
                                ),
                              const PopupMenuItem<String>(
                                value: 'eliminar',
                                child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Eliminar', style: TextStyle(color: Colors.red)), contentPadding: EdgeInsets.zero, dense: true),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AgriPalette.greenMain,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PageTrabajadorForm()),
          );
          if (result == true) {
            _cargarTrabajadores(); 
          }
        },
      ),
    );
  }
}


// import 'package:flutter/material.dart';
// import '../models/record_trabajador.dart';
// import '../services/api_service.dart';
// import '../utils/app_palette.dart';
// import '../pages/page_trabajador_add.dart';


// class PageTrabajadores extends StatefulWidget {
//   const PageTrabajadores({Key? key}) : super(key: key);

//   @override
//   State<PageTrabajadores> createState() => _PageTrabajadoresState();
// }

// class _PageTrabajadoresState extends State<PageTrabajadores> {
//   final ApiService _apiService = ApiService();
  
//   // Lista maestra que almacena TODOS los trabajadores bajados de la API
//   List<Trabajador> _todosLosTrabajadores = [];
  
//   // Lista dinámica que se dibuja en pantalla (cambia al escribir o pulsar el switch)
//   List<Trabajador> _trabajadoresFiltrados = [];

//   bool _cargando = true;
//   bool _mostrarSoloActivos = true; // Checkbox/Switch activado por defecto
//   String _busqueda = ""; // Lo que el usuario escribe
  
//   final TextEditingController _searchController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     _cargarTrabajadores();
//   }

//   Future<void> _cargarTrabajadores() async {
//     setState(() => _cargando = true);
//     try {
//       // 1. Cargamos TODOS los trabajadores usando tu endpoint genérico
//       final rawData = await _apiService.fetchList('tbltrabajador');
//       _todosLosTrabajadores = rawData.map((json) => Trabajador.fromJson(json)).toList();
      
//       // 2. Aplicamos filtros iniciales
//       _filtrarYOrdenar();
//     } catch (e) {
//       print("Error cargando trabajadores: $e");
//     } finally {
//       setState(() => _cargando = false);
//     }
//   }

//   /// Motor de filtrado en tiempo real
//   void _filtrarYOrdenar() {
//     List<Trabajador> temp = _todosLosTrabajadores.where((t) {
//       // A. Filtro por nombre (Texto a minúsculas para que no importe cómo escriban)
//       final nombreCoincide = t.nombreStr.toLowerCase().contains(_busqueda.toLowerCase());
//       if (!nombreCoincide) return false;

//       // B. Filtro por Activos / Inactivos
//       // Asumimos que eliminadoBit = true o 1 significa Inactivo. 
//       // ADAPTAR: Si tu modelo lo mapea como int o bool, ajústalo aquí.
//       bool estaEliminado = t.eliminado_bit == 1 || t.eliminado_bit == true;
      
//       if (_mostrarSoloActivos && estaEliminado) {
//         return false; // Si solo queremos activos y está eliminado, lo ocultamos
//       }

//       return true; // Pasa todos los filtros
//     }).toList();

//     // C. Ordenar del más nuevo al más antiguo 
//     // ADAPTAR: Si en tu Record_Trabajador no tienes mapeado 'fecha_dtm', deberás mapearlo.
//     // temp.sort((a, b) => b.fecha_dtm.compareTo(a.fecha_dtm));

//     setState(() {
//       _trabajadoresFiltrados = temp;
//     });
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Gestión de personal")),
//       body: Column(
//         children: [
//           // --- ZONA DE FILTROS ---
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: TextField(
//               controller: _searchController,
//               decoration: InputDecoration(
//                 labelText: 'Buscar por nombre...',
//                 prefixIcon: const Icon(Icons.search, color: AgriPalette.greenMain),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//               ),
//               onChanged: (valor) {
//                 // Al escribir, actualiza la variable y lanza el filtro
//                 _busqueda = valor;
//                 _filtrarYOrdenar();
//               },
//             ),
//           ),
//           SwitchListTile(
//             title: const Text("Mostrar solo trabajadores activos"),
//             value: _mostrarSoloActivos,
//             activeColor: AgriPalette.greenMain,
//             onChanged: (valor) {
//               setState(() {
//                 _mostrarSoloActivos = valor;
//                 _filtrarYOrdenar();
//               });
//             },
//           ),
//           const Divider(),
          
//           // --- ZONA DE RESULTADOS ---
//           Expanded(
//             child: _cargando 
//               ? const Center(child: CircularProgressIndicator())
//               : _trabajadoresFiltrados.isEmpty
//                   ? const Center(child: Text("No se encontraron trabajadores"))
//                   : ListView.builder(
//                       itemCount: _trabajadoresFiltrados.length,
//                       itemBuilder: (context, index) {
//                         final t = _trabajadoresFiltrados[index];
//                         final bool esInactivo = t.eliminado_bit == 1 || t.eliminado_bit == true;

//                         return ListTile(
//                           leading: CircleAvatar(
//                             backgroundColor: esInactivo ? Colors.grey : AgriPalette.greenMain,
//                             child: const Icon(Icons.person, color: Colors.white),
//                           ),
//                           title: Text(
//                             t.nombreStr, 
//                             style: TextStyle(
//                               fontWeight: FontWeight.bold,
//                               decoration: esInactivo ? TextDecoration.lineThrough : null,
//                             ),
//                           ),
//                           subtitle: Text(t.dniStr ?? "Sin DNI"),
//                           trailing: IconButton(
//                             icon: const Icon(Icons.edit, color: AgriPalette.greyMain),
//                             onPressed: () { /* Navegar a editar */ },
//                           ),
//                         );
//                       },
//                     ),
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         backgroundColor: AgriPalette.greenMain,
//         child: const Icon(Icons.add, color: Colors.white),
//         onPressed: () async {
//           final result = await Navigator.push(
//             context,
//             MaterialPageRoute(builder: (context) => const PageTrabajadorForm()),
//           );
//           if (result == true) {
//             _cargarTrabajadores(); // Refrescamos la lista si se creó uno nuevo
//           }
//         },
//       ),
//     );
//   }
// }


// import 'package:flutter/material.dart';
// import '../models/record_trabajador.dart';
// import '../services/api_service.dart';
// import '../utils/app_palette.dart';
// import '../pages/page_trabajador_add.dart';

// class PageTrabajadores extends StatefulWidget {
//   const PageTrabajadores({Key? key}) : super(key: key);

//   @override
//   State<PageTrabajadores> createState() => _PageTrabajadoresState();
// }

// class _PageTrabajadoresState extends State<PageTrabajadores> {
//   final ApiService _apiService = ApiService();
  
//   List<Trabajador> _todosLosTrabajadores = [];
//   List<Trabajador> _trabajadoresFiltrados = [];

//   bool _cargando = true;
//   bool _mostrarSoloActivos = true; // El Check empieza marcado
//   String _busqueda = "";
  
//   final TextEditingController _searchController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     _cargarTrabajadores();
//   }

//   Future<void> _cargarTrabajadores() async {
//     setState(() => _cargando = true);
//     try {
//       final rawData = await _apiService.fetchList('tbltrabajador');
//       _todosLosTrabajadores = rawData.map((json) => Trabajador.fromJson(json)).toList();
//       _filtrarYOrdenar();
//     } catch (e) {
//       print("Error cargando trabajadores: $e");
//     } finally {
//       if (mounted) setState(() => _cargando = false);
//     }
//   }

//   /// Motor de filtrado y ordenación
//   void _filtrarYOrdenar() {
//     List<Trabajador> temp = _todosLosTrabajadores.where((t) {
//       // 1. Filtro por nombre (en tiempo real)
//       final nombreCoincide = t.nombreStr.toLowerCase().contains(_busqueda.toLowerCase());
//       if (!nombreCoincide) return false;

//       // 2. Cálculo de Activo vs Inactivo
//       bool esActivo = false;
//       final hoy = DateTime.now();
//       final fechaHoyLimpia = DateTime(hoy.year, hoy.month, hoy.day); // Ignoramos las horas

//       if (t.fechaInicioContrato != null) {
//         final inicio = DateTime(t.fechaInicioContrato!.year, t.fechaInicioContrato!.month, t.fechaInicioContrato!.day);
//         // Si el contrato empezó hoy o en el pasado
//         if (!inicio.isAfter(fechaHoyLimpia)) {
//           esActivo = true;
//         }
//       }

//       if (esActivo && t.fechaFinContrato != null) {
//         final fin = DateTime(t.fechaFinContrato!.year, t.fechaFinContrato!.month, t.fechaFinContrato!.day);
//         // Si tiene fecha fin y ya pasó
//         if (fin.isBefore(fechaHoyLimpia)) {
//           esActivo = false;
//         }
//       }

//       // Si el check está marcado y NO está activo, lo ocultamos
//       if (_mostrarSoloActivos && !esActivo) {
//         return false;
//       }

//       return true; // Pasa los filtros
//     }).toList();

//     // 3. Ordenar siempre del más nuevo al más antiguo (fecha de creación)
//     temp.sort((a, b) {
//       final fechaA = a.fechaCreacion ?? DateTime(2000);
//       final fechaB = b.fechaCreacion ?? DateTime(2000);
//       return fechaB.compareTo(fechaA); // Orden descendente
//     });

//     setState(() {
//       _trabajadoresFiltrados = temp;
//     });
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Gestión de personal")),
//       body: Column(
//         children: [
//           // --- BARRA DE BÚSQUEDA Y CHECKBOX (EN LA MISMA FILA) ---
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Row(
//               children: [
//                 // Buscador ocupando el espacio izquierdo
//                 Expanded(
//                   child: TextField(
//                     controller: _searchController,
//                     decoration: InputDecoration(
//                       labelText: 'Buscar por nombre...',
//                       prefixIcon: const Icon(Icons.search, color: AgriPalette.greenMain),
//                       contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                     onChanged: (valor) {
//                       _busqueda = valor;
//                       _filtrarYOrdenar(); // Filtra instantáneamente
//                     },
//                   ),
//                 ),
//                 const SizedBox(width: 8),
                
//                 // Zona del Checkbox recortada a la derecha
//                 InkWell(
//                   onTap: () {
//                     setState(() {
//                       _mostrarSoloActivos = !_mostrarSoloActivos;
//                       _filtrarYOrdenar();
//                     });
//                   },
//                   borderRadius: BorderRadius.circular(8),
//                   child: Padding(
//                     padding: const EdgeInsets.all(8.0),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Checkbox(
//                           value: _mostrarSoloActivos,
//                           activeColor: AgriPalette.greenMain,
//                           onChanged: (valor) {
//                             setState(() {
//                               _mostrarSoloActivos = valor ?? true;
//                               _filtrarYOrdenar();
//                             });
//                           },
//                         ),
//                         const Text("Activos", style: TextStyle(fontWeight: FontWeight.bold)),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const Divider(height: 1),
          
//           // --- LISTA DE TRABAJADORES ---
//           Expanded(
//             child: _cargando 
//               ? const Center(child: CircularProgressIndicator())
//               : _trabajadoresFiltrados.isEmpty
//                   ? const Center(child: Text("No se encontraron trabajadores"))
//                   : ListView.builder(
//                       itemCount: _trabajadoresFiltrados.length,
//                       itemBuilder: (context, index) {
//                         final t = _trabajadoresFiltrados[index];

//                         // Volvemos a calcular el estado visual para pintar los inactivos de gris
//                         bool esActivo = false;
//                         final fechaHoyLimpia = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
//                         if (t.fechaInicioContrato != null) {
//                           final inicio = DateTime(t.fechaInicioContrato!.year, t.fechaInicioContrato!.month, t.fechaInicioContrato!.day);
//                           if (!inicio.isAfter(fechaHoyLimpia)) esActivo = true;
//                         }
//                         if (esActivo && t.fechaFinContrato != null) {
//                           final fin = DateTime(t.fechaFinContrato!.year, t.fechaFinContrato!.month, t.fechaFinContrato!.day);
//                           if (fin.isBefore(fechaHoyLimpia)) esActivo = false;
//                         }

//                         return ListTile(
//                           leading: CircleAvatar(
//                             backgroundColor: esActivo ? AgriPalette.greenMain : Colors.grey.shade400,
//                             child: const Icon(Icons.person, color: Colors.white),
//                           ),
//                           title: Text(
//                             t.nombreStr, 
//                             style: TextStyle(
//                               fontWeight: FontWeight.bold,
//                               // Si está inactivo, tachamos el nombre sutilmente
//                               decoration: esActivo ? null : TextDecoration.lineThrough,
//                               color: esActivo ? Colors.black87 : Colors.grey.shade600,
//                             ),
//                           ),
//                           subtitle: Text(t.dniStr != null && t.dniStr!.isNotEmpty ? t.dniStr! : "Sin DNI"),
//                           trailing: IconButton(
//                             icon: const Icon(Icons.edit, color: AgriPalette.greyMain),
//                             onPressed: () { /* Navegar a editar */ },
//                           ),
//                         );
//                       },
//                     ),
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         backgroundColor: AgriPalette.greenMain,
//         child: const Icon(Icons.add, color: Colors.white),
//         onPressed: () async {
//           final result = await Navigator.push(
//             context,
//             MaterialPageRoute(builder: (context) => const PageTrabajadorForm()),
//           );
//           if (result == true) {
//             _cargarTrabajadores();
//           }
//         },
//       ),
//     );
//   }
// }