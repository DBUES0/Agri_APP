import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/record_trabajador.dart';
import '../services/api_service.dart';
import '../utils/ui_utils.dart';

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
  
  // Mapas para controlar el estado y textos de cada trabajador individualmente
  final Map<String, bool> _checksTrabajadores = {};
  final Map<String, TextEditingController> _obsControllers = {};
  final Map<String, TextEditingController> _horasIndividualesControllers = {};

  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _inicializarPantalla();
  }

  Future<void> _inicializarPantalla() async {
    await _cargarUltimoHorario();
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
        _filtrarTrabajadoresPorFecha();
      });
    }
  }

  void _toggleSeleccionarTodos(bool? valor) {
    setState(() {
      _seleccionarTodos = valor ?? false;
      for (var t in _activosEnFecha) {
        _checksTrabajadores[t.ktrabajador] = _seleccionarTodos;
        // Al seleccionar, copiamos las horas globales al trabajador individual
        if (_seleccionarTodos) {
          _horasIndividualesControllers[t.ktrabajador]!.text = _horasGlobalController.text;
        } else {
          _horasIndividualesControllers[t.ktrabajador]!.clear();
        }
      }
    });
  }

  void _toggleTrabajador(String ktrabajador, bool valor) {
    setState(() {
      _checksTrabajadores[ktrabajador] = valor;
      // Al marcar uno individualmente, hereda las horas de la cabecera
      if (valor) {
        _horasIndividualesControllers[ktrabajador]!.text = _horasGlobalController.text;
      } else {
        _horasIndividualesControllers[ktrabajador]!.clear();
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

        // Leemos las horas desde el controlador individual
        final horasStr = _horasIndividualesControllers[t.ktrabajador]?.text.replaceAll(',', '.') ?? '';

        final data = {
          'kjornada': const Uuid().v4(),
          'ktrabajador': t.ktrabajador,
          'fecha_dtm': fechaStr,
          'horario_str': _horarioController.text.trim(),
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

          // --- LISTA DE TRABAJADORES (COMPACTA Y EN LÍNEA) ---
          Expanded(
            child: _activosEnFecha.isEmpty
                ? const Center(child: Text("No hay trabajadores activos en esta fecha"))
                : ListView.builder(
                    itemCount: _activosEnFecha.length,
                    itemBuilder: (context, index) {
                      final t = _activosEnFecha[index];
                      final bool seleccionado = _checksTrabajadores[t.ktrabajador] ?? false;

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
                            
                            // NOMBRE DEL TRABAJADOR
                            Expanded(
                              flex: 4,
                              child: Text(
                                t.nombreStr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                            
                            // HORAS Y OBSERVACIONES (Solo visibles si está seleccionado)
                            if (seleccionado) ...[
                              const SizedBox(width: 4),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _horasIndividualesControllers[t.ktrabajador],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(fontSize: 13),
                                  decoration: const InputDecoration(
                                    hintText: 'H.',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                flex: 5,
                                child: TextField(
                                  controller: _obsControllers[t.ktrabajador],
                                  style: const TextStyle(fontSize: 13),
                                  decoration: const InputDecoration(
                                    hintText: 'Obs.',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ]
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