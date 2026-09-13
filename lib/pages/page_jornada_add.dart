// lib/pages/page_jornada_add.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/record_trabajador.dart';
import '../services/api_service.dart';
import '../utils/ui_utils.dart';
import '../utils/app_palette.dart';

class PageJornadaAdd extends StatefulWidget {
  final List<Trabajador> trabajadores;

  const PageJornadaAdd({Key? key, required this.trabajadores}) : super(key: key);

  @override
  State<PageJornadaAdd> createState() => _PageJornadaAddState();
}

class _PageJornadaAddState extends State<PageJornadaAdd> {
  final ApiService _apiService = ApiService();
  
  DateTime _fechaSeleccionada = DateTime.now();
  final TextEditingController _horarioController = TextEditingController();
  final TextEditingController _horasGlobalController = TextEditingController();

  List<Trabajador> _activosEnFecha = [];
  bool _seleccionarTodos = false;
  
  // Mapas de control por cada trabajador
  final Map<String, bool> _checksTrabajadores = {};
  final Map<String, TextEditingController> _obsControllers = {};
  final Map<String, TextEditingController> _horasIndividualesControllers = {};
  final Map<String, TextEditingController> _horarioIndividualControllers = {};
  final Map<String, String> _marcajesPorTrabajador = {};

  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _inicializarPantalla();
  }

  Future<void> _inicializarPantalla() async {
    await _cargarUltimoHorario();
    await _cargarMarcajesDelDia();
    _filtrarTrabajadoresPorFecha();
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _cargarUltimoHorario() async {
    try {
      final jornadas = await _apiService.fetchList('tbljornada');
      if (jornadas.isNotEmpty) {
        jornadas.sort((a, b) => (b['fecha_dtm'] ?? '').compareTo(a['fecha_dtm'] ?? ''));
        
        final ultima = jornadas.firstWhere(
          (j) => j['horario_str'] != null && j['horario_str'].toString().isNotEmpty, 
          orElse: () => {}
        );

        if (ultima.isNotEmpty) {
          _horarioController.text = ultima['horario_str'].toString();
          _horasGlobalController.text = ultima['horas_flt']?.toString() ?? '';
        }
      }
    } catch (e) {
      print("Error cargando último horario: $e");
    }
  }

  // Consulta los marcajes existentes en la fecha seleccionada y genera el resumen HH:mm
Future<void> _cargarMarcajesDelDia() async {
    final fechaStr = DateFormat('yyyy-MM-dd').format(_fechaSeleccionada);
    try {
      final raw = await _apiService.fetchList('tblmarcaje');
      print("🔍 DEBUG MARCAJES: Recibidos ${raw.length} registros en total de tblmarcaje");

      final Map<String, List<String>> gruposHoras = {};

      for (var m in raw) {
        final rawFecha = (m['fechamarcaje_dtm'] ?? m['fecha_dtm'] ?? '').toString().trim();
        final bool esEliminado = m['eliminado_bit'] == 1 || m['eliminado_bit'] == true || m['eliminado_bit'] == '1';

        // Verificamos si es del día seleccionado y no está borrado
        if (rawFecha.startsWith(fechaStr) && !esEliminado) {
          final kId = (m['ktrabajador'] ?? '').toString().trim().toLowerCase();
          
          // Extraemos directamente HH:mm (ej: de "2026-09-13 10:44:15" saca "10:44")
          String horaMinuto = "";
          if (rawFecha.length >= 16) {
            horaMinuto = rawFecha.substring(11, 16);
          } else {
            final dt = DateTime.tryParse(rawFecha.replaceFirst(' ', 'T'));
            if (dt != null) horaMinuto = DateFormat('HH:mm').format(dt);
          }

          if (kId.isNotEmpty && horaMinuto.isNotEmpty) {
            gruposHoras.putIfAbsent(kId, () => []).add(horaMinuto);
          }
        }
      }

      _marcajesPorTrabajador.clear();
      for (var entry in gruposHoras.entries) {
        entry.value.sort(); // Orden cronológico de horas
        if (entry.value.length == 1) {
          _marcajesPorTrabajador[entry.key] = entry.value.first;
        } else if (entry.value.length >= 2) {
          _marcajesPorTrabajador[entry.key] = "${entry.value.first}-${entry.value.last}";
        }
      }

      print("🔍 DEBUG MARCAJES DEL DÍA ($fechaStr): $_marcajesPorTrabajador");
      if (mounted) setState(() {});
    } catch (e) {
      print("❌ Error cargando marcajes del día: $e");
    }
  }

  // Future<void> _cargarMarcajesDelDia() async {
  //   final fechaStr = DateFormat('yyyy-MM-dd').format(_fechaSeleccionada);
  //   try {
  //     final raw = await _apiService.fetchList('tblmarcaje');
  //     print("DEBUG MARCAJES: Descargados ${raw.length} registros de tblmarcaje");

  //     final DateFormat horaFormat = DateFormat('HH:mm');
  //     final Map<String, List<DateTime>> grupos = {};

  //     for (var m in raw) {
  //       // 1. Detectamos la columna de fecha (fechamarcaje_dtm o fecha_dtm)
  //       final rawFecha = (m['fechamarcaje_dtm'] ?? m['fecha_dtm'] ?? m['fechahora_dtm'] ?? '').toString().trim();
  //       final bool esEliminado = m['eliminado_bit'] == 1 || m['eliminado_bit'] == true || m['eliminado_bit'] == '1';

  //       if (rawFecha.isEmpty || esEliminado) continue;

  //       // 2. Normalizamos fecha y hora (reemplazando espacio por T para parseo ISO seguro)
  //       final dt = DateTime.tryParse(rawFecha.replaceFirst(' ', 'T'));
  //       final bool coincideFecha = rawFecha.startsWith(fechaStr) ||
  //           (dt != null && dt.year == _fechaSeleccionada.year && dt.month == _fechaSeleccionada.month && dt.day == _fechaSeleccionada.day);

  //       if (coincideFecha && dt != null) {
  //         // 3. Normalizamos el UUID del trabajador a minúsculas y sin espacios
  //         final kId = (m['ktrabajador'] ?? '').toString().trim().toLowerCase();
  //         if (kId.isNotEmpty) {
  //           grupos.putIfAbsent(kId, () => []).add(dt);
  //         }
  //       }
  //     }

  //     _marcajesPorTrabajador.clear();
  //     for (var entry in grupos.entries) {
  //       // Ordenamos las horas de entrada/salida cronológicamente
  //       entry.value.sort((a, b) => a.compareTo(b));

  //       if (entry.value.length == 1) {
  //         _marcajesPorTrabajador[entry.key] = horaFormat.format(entry.value.first);
  //       } else if (entry.value.length >= 2) {
  //         // Si tiene 2 o más, muestra entrada y salida (o todos separados por guion)
  //         _marcajesPorTrabajador[entry.key] = entry.value.map((d) => horaFormat.format(d)).join('-');
  //       }
  //     }

  //     print("DEBUG MARCAJES PROCESADOS: $_marcajesPorTrabajador");
  //     if (mounted) setState(() {});
  //   } catch (e) {
  //     print("Error cargando marcajes del día: $e");
  //   }
  // }
  // // Future<void> _cargarMarcajesDelDia() async {
  //   final fechaStr = DateFormat('yyyy-MM-dd').format(_fechaSeleccionada);
  //   try {
  //     final raw = await _apiService.fetchList('tblmarcaje');
      
  //     final marcajesHoy = raw.where((m) {
  //       final d = m['fechamarcaje_dtm']?.toString() ?? '';
  //       final elim = m['eliminado_bit'] == 1 || m['eliminado_bit'] == true;
  //       return d.startsWith(fechaStr) && !elim;
  //     }).toList();

  //     marcajesHoy.sort((a, b) => (a['fechamarcaje_dtm'] ?? '').compareTo(b['fechamarcaje_dtm'] ?? ''));

  //     final Map<String, List<DateTime>> grupos = {};
  //     for (var m in marcajesHoy) {
  //       final kId = (m['ktrabajador'] ?? '').toString();
  //       final dt = DateTime.tryParse(m['fechamarcaje_dtm'] ?? '');
  //       if (kId.isNotEmpty && dt != null) {
  //         grupos.putIfAbsent(kId, () => []).add(dt);
  //       }
  //     }

  //     final DateFormat horaFormat = DateFormat('HH:mm');
  //     _marcajesPorTrabajador.clear();
  //     for (var entry in grupos.entries) {
  //       if (entry.value.length == 1) {
  //         _marcajesPorTrabajador[entry.key] = horaFormat.format(entry.value.first);
  //       } else if (entry.value.length >= 2) {
  //         _marcajesPorTrabajador[entry.key] = 
  //             "${horaFormat.format(entry.value.first)}-${horaFormat.format(entry.value.last)}";
  //       }
  //     }
  //     if (mounted) setState(() {});
  //   } catch (e) {
  //     print("Error cargando marcajes del día: $e");
  //   }
  // }

  void _filtrarTrabajadoresPorFecha() {
    final fechaLimpia = DateTime(_fechaSeleccionada.year, _fechaSeleccionada.month, _fechaSeleccionada.day);

    _activosEnFecha = widget.trabajadores.where((t) {
      if (t.eliminadoBit == 1) return false;

      bool esActivo = false;
      if (t.fechainicioultimocontratoDtm != null) {
        final inicio = DateTime(t.fechainicioultimocontratoDtm!.year, t.fechainicioultimocontratoDtm!.month, t.fechainicioultimocontratoDtm!.day);
        if (!inicio.isAfter(fechaLimpia)) esActivo = true;
      }

      if (esActivo && t.fechafinultimocontratoDtm != null) {
        final fin = DateTime(t.fechafinultimocontratoDtm!.year, t.fechafinultimocontratoDtm!.month, t.fechafinultimocontratoDtm!.day);
        if (fin.isBefore(fechaLimpia)) esActivo = false;
      }
      return esActivo;
    }).toList();

    _seleccionarTodos = false;
    for (var t in _activosEnFecha) {
      _checksTrabajadores[t.ktrabajador] = false;
      _obsControllers[t.ktrabajador] ??= TextEditingController(); 
      _horasIndividualesControllers[t.ktrabajador] ??= TextEditingController();
      _horarioIndividualControllers[t.ktrabajador] ??= TextEditingController();
    }
    setState(() {});
  }

  Future<void> _seleccionarFecha() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(data: Theme.of(context), child: child!),
    );

    if (picked != null && picked != _fechaSeleccionada) {
      setState(() {
        _fechaSeleccionada = picked;
      });
      await _cargarMarcajesDelDia();
      _filtrarTrabajadoresPorFecha();
    }
  }

  void _toggleSeleccionarTodos(bool? valor) {
    setState(() {
      _seleccionarTodos = valor ?? false;
      for (var t in _activosEnFecha) {
        _checksTrabajadores[t.ktrabajador] = _seleccionarTodos;
        if (_seleccionarTodos) {
          _horasIndividualesControllers[t.ktrabajador]!.text = _horasGlobalController.text;
          _horarioIndividualControllers[t.ktrabajador]!.text = _horarioController.text;
        } else {
          _horasIndividualesControllers[t.ktrabajador]!.clear();
          _horarioIndividualControllers[t.ktrabajador]!.clear();
        }
      }
    });
  }

  void _toggleTrabajador(String ktrabajador, bool valor) {
    setState(() {
      _checksTrabajadores[ktrabajador] = valor;
      if (valor) {
        _horasIndividualesControllers[ktrabajador]!.text = _horasGlobalController.text;
        _horarioIndividualControllers[ktrabajador]!.text = _horarioController.text;
      } else {
        _horasIndividualesControllers[ktrabajador]!.clear();
        _horarioIndividualControllers[ktrabajador]!.clear();
      }
    });
  }

  Future<void> _guardarJornadas() async {
    final seleccionados = _activosEnFecha.where((t) => _checksTrabajadores[t.ktrabajador] == true).toList();

    if (seleccionados.isEmpty) {
      mensajeEmergente(context, 'Debes seleccionar al menos un trabajador', tipo: 'warning');
      return;
    }

    setState(() => _guardando = true);

    try {
      final fechaStr = DateFormat('yyyy-MM-dd').format(_fechaSeleccionada);
      
      final jornadasExistentes = await _apiService.fetchList('tbljornada');
      final Set<String> trabajadoresConJornadaHoy = jornadasExistentes
          .where((j) => j['fecha_dtm'] != null && j['fecha_dtm'].toString().startsWith(fechaStr) && j['eliminado_bit'] == 0)
          .map((j) => j['ktrabajador'].toString())
          .toSet();

      int guardados = 0;
      int duplicados = 0;

      for (var t in seleccionados) {
        if (trabajadoresConJornadaHoy.contains(t.ktrabajador)) {
          duplicados++;
          continue; 
        }

        final horasStr = _horasIndividualesControllers[t.ktrabajador]?.text.replaceAll(',', '.') ?? '';
        final horarioInd = _horarioIndividualControllers[t.ktrabajador]?.text.trim() ?? '';
        final horarioFinal = horarioInd.isNotEmpty ? horarioInd : _horarioController.text.trim();

        final data = {
          'kjornada': const Uuid().v4(),
          'ktrabajador': t.ktrabajador,
          'fecha_dtm': fechaStr,
          'horario_str': horarioFinal,
          'horas_flt': double.tryParse(horasStr),
          'observaciones_str': _obsControllers[t.ktrabajador]?.text.trim(),
          'eliminado_bit': 0,
        };

        await _apiService.postGeneric('tbljornada', data);
        guardados++;
      }

      if (!mounted) return;

      if (guardados > 0) {
        mensajeEmergente(context, '$guardados jornada(s) añadida(s) correctamente.', tipo: 'success');
        if (duplicados > 0) {
          mensajeEmergente(context, '$duplicados trabajador(es) omitido(s) porque ya tenían jornada registrada hoy.', tipo: 'warning');
        }
        Navigator.pop(context, true);
      } else {
        mensajeEmergente(context, 'No se ha guardado nada. Todos los seleccionados ya tenían jornada hoy.', tipo: 'error');
      }
    } catch (e) {
      if (!mounted) return;
      mensajeEmergente(context, 'Error al guardar: $e', tipo: 'error');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  void dispose() {
    _horarioController.dispose();
    _horasGlobalController.dispose();
    for (var ctrl in _obsControllers.values) {
      ctrl.dispose();
    }
    for (var ctrl in _horasIndividualesControllers.values) {
      ctrl.dispose();
    }
    for (var ctrl in _horarioIndividualControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Añadir Jornada')),
      body: Column(
        children: [
          // --- CABECERA ---
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.surface,
            child: Column(
              children: [
                InkWell(
                  onTap: _seleccionarFecha,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.primaryColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_month, color: theme.primaryColor),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat('yyyy-MM-dd').format(_fechaSeleccionada),
                          style: TextStyle(fontWeight: FontWeight.bold, color: theme.primaryColor),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: TextField(
                        controller: _horarioController,
                        decoration: const InputDecoration(
                          labelText: 'Horario (ej. 07:30 - 15:30)',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _horasGlobalController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Horas',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // --- CHECKBOX MASIVO ---
          CheckboxListTile(
            title: const Text("Seleccionar todos los trabajadores"),
            value: _seleccionarTodos,
            activeColor: theme.primaryColor,
            onChanged: _toggleSeleccionarTodos,
            controlAffinity: ListTileControlAffinity.leading,
            visualDensity: VisualDensity.compact,
          ),
          const Divider(height: 1),

          // --- LISTA DE TRABAJADORES CON CAMPOS COMPACTOS Y MARCAJES ---
          Expanded(
            child: _activosEnFecha.isEmpty
                ? const Center(child: Text("No hay trabajadores activos en esta fecha"))
                : ListView.builder(
                    itemCount: _activosEnFecha.length,
                    itemBuilder: (context, index) {
                      final t = _activosEnFecha[index];
                      final bool seleccionado = _checksTrabajadores[t.ktrabajador] ?? false;
                      
                      // CAMBIO: Buscamos con el UUID normalizado a minúsculas
                      final String tIdLimpio = t.ktrabajador.trim().toLowerCase();
                      final String? marcajeRef = _marcajesPorTrabajador[tIdLimpio];
                      // final t = _activosEnFecha[index];
                      // final bool seleccionado = _checksTrabajadores[t.ktrabajador] ?? false;
                      // final String? marcajeRef = _marcajesPorTrabajador[t.ktrabajador];

                      return Container(
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                          color: seleccionado ? theme.primaryColor.withOpacity(0.05) : Colors.transparent,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                        child: Row(
                          children: [
                            Checkbox(
                              visualDensity: VisualDensity.compact,
                              activeColor: theme.primaryColor,
                              value: seleccionado,
                              onChanged: (val) => _toggleTrabajador(t.ktrabajador, val ?? false),
                            ),
                            
                            // NOMBRE DEL TRABAJADOR Y MARCAJE (TEXTO INFORMATIVO)
                            // Expanded(
                            //   child: Column(
                            //     crossAxisAlignment: CrossAxisAlignment.start,
                            //     mainAxisSize: MainAxisSize.min,
                            //     children: [
                            //       Text(
                            //         t.nombreStr,
                            //         maxLines: 1,
                            //         overflow: TextOverflow.ellipsis,
                            //         style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            //       ),
                            //       if (marcajeRef != null && marcajeRef.isNotEmpty)
                            //         Text(
                            //           marcajeRef,
                            //           style: TextStyle(
                            //             fontSize: 11,
                            //             fontWeight: FontWeight.bold,
                            //             color: Colors.blueGrey.shade700,
                            //           ),
                            //         ),
                            //     ],
                            //   ),
                            // ),
                            
                            // NOMBRE DEL TRABAJADOR Y MARCAJE
                            // Expanded(
                            //   child: Column(
                            //     crossAxisAlignment: CrossAxisAlignment.start,
                            //     mainAxisSize: MainAxisSize.min,
                            //     children: [
                            //       Text(
                            //         t.nombreStr,
                            //         maxLines: 1,
                            //         overflow: TextOverflow.ellipsis,
                            //         style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            //       ),
                            //       if (marcajeRef != null && marcajeRef.isNotEmpty) ...[
                            //         const SizedBox(height: 2),
                            //         Row(
                            //           children: [
                            //             const Icon(Icons.schedule, size: 12, color: AgriPalette.greenMain),
                            //             const SizedBox(width: 4),
                            //             Text(
                            //               marcajeRef,
                            //               style: const TextStyle(
                            //                 fontSize: 11,
                            //                 fontWeight: FontWeight.bold,
                            //                 color: AgriPalette.greenMain,
                            //               ),
                            //             ),
                            //           ],
                            //         ),
                            //       ],
                            //     ],
                            //   ),
                            // ),                            
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    t.nombreStr,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  if (marcajeRef != null && marcajeRef.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.schedule, size: 12, color: theme.primaryColor),
                                          const SizedBox(width: 3),
                                          Text(
                                            marcajeRef,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: theme.primaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // CAMPOS COMPACTOS (SOLO VISIBLES SI ESTÁ MARCADO)
                            if (seleccionado) ...[
                              const SizedBox(width: 4),
                              
                              // 1. HORARIO INDIVIDUAL
                              SizedBox(
                                width: 82,
                                height: 36,
                                child: TextField(
                                  controller: _horarioIndividualControllers[t.ktrabajador],
                                  style: const TextStyle(fontSize: 12),
                                  decoration: const InputDecoration(
                                    hintText: 'Horario',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),

                              // 2. HORAS (COMPACTO)
                              SizedBox(
                                width: 44,
                                height: 36,
                                child: TextField(
                                  controller: _horasIndividualesControllers[t.ktrabajador],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                  decoration: const InputDecoration(
                                    hintText: 'H.',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),

                              // 3. OBSERVACIONES (COMPACTO)
                              SizedBox(
                                width: 62,
                                height: 36,
                                child: TextField(
                                  controller: _obsControllers[t.ktrabajador],
                                  style: const TextStyle(fontSize: 12),
                                  decoration: const InputDecoration(
                                    hintText: 'Obs.',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme.primaryColor,
        icon: _guardando 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
          : const Icon(Icons.save, color: Colors.white),
        label: Text(_guardando ? 'Guardando...' : 'Guardar Jornadas', style: const TextStyle(color: Colors.white)),
        onPressed: _guardando ? null : _guardarJornadas,
      ),
    );
  }
}