// //lib/pages/page_trabajador.dart
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart'; // Mantén este para el plan B
import 'dart:convert'; // Para que funcione jsonDecode
import 'package:shared_preferences/shared_preferences.dart'; // Para leer los datos guardados
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/record_trabajador.dart';
import '../services/api_service.dart';
import '../utils/app_palette.dart';
import 'package:agriapp/utils/app_theme.dart';
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

// --- 1. VENTANA EMERGENTE PARA DEFINIR CONTRASEÑA ---
  Future<void> _cambiarPasswordTrabajador(Trabajador t) async {
    final TextEditingController pass1Controller = TextEditingController();
    final TextEditingController pass2Controller = TextEditingController();
    final theme = Theme.of(context);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Contraseña para ${t.nombreStr}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pass1Controller,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nueva contraseña', isDense: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pass2Controller,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Repetir contraseña', isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor),
            onPressed: () async {
              if (pass1Controller.text.isEmpty || pass1Controller.text != pass2Controller.text) {
                mensajeEmergente(context, 'Las contraseñas no coinciden o están vacías', tipo: 'error');
                return;
              }

              try {
                // Guardamos la contraseña en la tabla tbltrabajador
                await _apiService.putGeneric('tbltrabajador', t.ktrabajador, {
                  'password_str': pass1Controller.text.trim()
                });
                if (!mounted) return;
                Navigator.pop(context);
                mensajeEmergente(context, 'Contraseña guardada correctamente', tipo: 'success');
              } catch (e) {
                mensajeEmergente(context, 'Error al guardar contraseña: $e', tipo: 'error');
              }
            },
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- 2. COMPARTIR ENLACE DE MARCAJE ---
  Future<void> _compartirMarcaje(Trabajador t) async {
    if (t.dniStr == null || t.dniStr!.isEmpty) {
      mensajeEmergente(context, 'El trabajador no tiene DNI asignado', tipo: 'warning');
      return;
    }

    try {
      // Obtenemos los datos del agricultor logueado para sacar su 'nombrefincamarcaje_str'
      // Asumimos que tienes guardado el usuario en SharedPreferences o puedes consultarlo
      final prefs = await SharedPreferences.getInstance();
      final usuarioJson = prefs.getString('usuario_json');
      
      if (usuarioJson == null) {
        mensajeEmergente(context, 'No se encontró la información de la empresa', tipo: 'error');
        return;
      }

      final usuarioData = jsonDecode(usuarioJson);
      final String fincaMarcaje = usuarioData['nombrefincamarcaje_str'] ?? '';

      if (fincaMarcaje.isEmpty) {
        mensajeEmergente(context, 'La empresa no tiene configurada la finca de marcaje', tipo: 'error');
        return;
      }

      // Construimos la URL personalizada
      final String urlMarcaje = "${ApiService.dominioWeb}/marcaje.php?finca=$fincaMarcaje&dni=${t.dniStr}";
      
      // Texto amigable para enviar por WhatsApp
      final String mensaje = "Hola ${t.nombreStr}, haz clic en el siguiente enlace para registrar tu jornada:\n$urlMarcaje";

      // Abrimos el menú nativo del móvil para compartir (WhatsApp, Email, etc.)
      await Share.share(mensaje);

    } catch (e) {
      mensajeEmergente(context, 'Error al generar enlace: $e', tipo: 'error');
    }
  }

Future<void> _compartirMarcajeWhatsApp(Trabajador t) async {
    if (t.dniStr == null || t.dniStr!.isEmpty) {
      mensajeEmergente(context, 'El trabajador no tiene DNI asignado', tipo: 'warning');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final usuarioJson = prefs.getString('usuario_json');
      
      if (usuarioJson == null) {
        mensajeEmergente(context, 'No se encontró la información de la empresa', tipo: 'error');
        return;
      }

      final usuarioData = jsonDecode(usuarioJson);
      final String fincaMarcaje = usuarioData['nombrefincamarcaje_str'] ?? '';

      if (fincaMarcaje.isEmpty) {
        mensajeEmergente(context, 'La empresa no tiene configurada la finca de marcaje', tipo: 'error');
        return;
      }

      final String urlMarcaje = "${ApiService.dominioWeb}/marcaje.php?finca=$fincaMarcaje&dni=${t.dniStr}";
      final String mensaje = "Hola ${t.nombreStr}, haz clic en el siguiente enlace para registrar tu jornada:\n$urlMarcaje";

      // 1. Preparamos el enlace nativo de WhatsApp
      final Uri whatsappUrl = Uri.parse("whatsapp://send?text=${Uri.encodeComponent(mensaje)}");

      // 2. Intentamos abrir WhatsApp
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl);
      } else {
        // 3. Plan B: Si no tiene WhatsApp, abrimos el menú genérico
        await Share.share(mensaje);
      }

    } catch (e) {
      mensajeEmergente(context, 'Error al generar enlace: $e', tipo: 'error');
    }
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

// --- NUEVO: Dar de baja en una fecha específica ---
  Future<void> _bajaConFecha(Trabajador t) async {
    final DateTime? fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      // No dejamos que se den de baja antes de su fecha de alta
      firstDate: t.fechainicioultimocontratoDtm ?? DateTime(2000), 
      lastDate: DateTime(2101),
      builder: (context, child) {
        // Obligamos al calendario a heredar el tema de la aplicación
        return Theme(data: Theme.of(context), child: child!);
      },
    );

    if (fechaSeleccionada != null) {
      final dateStr = DateFormat('yyyy-MM-dd').format(fechaSeleccionada);
      try {
        await _apiService.putGeneric('tbltrabajador', t.ktrabajador, {
          'fechafinultimocontrato_dtm': dateStr
        });
        if (!mounted) return;
        mensajeEmergente(context, 'Trabajador dado de BAJA el $dateStr', tipo: 'warning');
        _cargarTrabajadores();
      } catch (e) {
        if (!mounted) return;
        mensajeEmergente(context, 'Error al cambiar estado: $e', tipo: 'error');
      }
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
            style: ElevatedButton.styleFrom(backgroundColor: AgriPalette.greenMain),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Eliminar', style: TextStyle(color: AgriPalette.white )),
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
    // 1. Extraemos el tema global de la app
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Gestión de personal")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5.0),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 45, 
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Buscar por nombre...',
                        prefixIcon: Icon(Icons.search, color: theme.primaryColor), // Usamos el color del tema
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
                        activeColor: theme.primaryColor, // Usamos el color del tema
                        visualDensity: VisualDensity.compact, 
                        onChanged: (valor) {
                          setState(() {
                            _mostrarSoloActivos = valor ?? true;
                            _filtrarYOrdenar();
                          });
                        },
                      ),
                      Text("Activos", style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
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

                      return Container(
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
                          child: Row(
                            children: [
                              // Avatar
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: esActivo ? theme.primaryColor : theme.disabledColor,
                                child: const Icon(Icons.person, color: AgriPalette.white, size: 18),
                              ),
                              const SizedBox(width: 10),
                              
                              // Texto (Nombre y DNI) - Se expande para empujar los botones a la derecha
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.nombreStr,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        decoration: esActivo ? null : TextDecoration.lineThrough,
                                        color: esActivo ? theme.textTheme.bodyLarge?.color : theme.disabledColor,
                                      ),
                                    ),
                                    Text(
                                      t.dniStr != null && t.dniStr!.isNotEmpty ? t.dniStr! : "Sin DNI",
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),

                              // Fila compacta de botones
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.lock),
                                    color: AgriPalette.greenMain,
                                    tooltip: 'Definir Contraseña',
                                    onPressed: () => _cambiarPasswordTrabajador(t),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.share),
                                    color: AgriPalette.greenMain,
                                    tooltip: 'Compartir Marcaje',
                                    onPressed: () => _compartirMarcajeWhatsApp(t),
                                  ),
                                  IconButton(
                                    icon: Icon(esActivo ? Icons.person_remove : Icons.person_add),
                                    color: AgriPalette.greenMain,
                                    onPressed: () => _cambiarEstadoContrato(t, !esActivo),
                                  ),
                                  if (esActivo)
                                    IconButton(
                                      icon: const Icon(Icons.edit_calendar),
                                      color: AgriPalette.greenMain,
                                      onPressed: () => _bajaConFecha(t),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    color: AgriPalette.greenMain,
                                    onPressed: () => _eliminarTrabajador(t),
                                  ),
                                ],
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
        backgroundColor: theme.primaryColor,
        child: const Icon(Icons.add, color: AgriPalette.white),
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