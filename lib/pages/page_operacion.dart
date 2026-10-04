import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/record_usuario.dart';
import '../models/record_trabajador.dart';
import '../models/record_tipooperacion.dart';
import '../services/api_service.dart';
import '../utils/app_palette.dart';
import '../utils/ui_utils.dart';

class PageOperacion extends StatefulWidget {
  final Usuario usuario;
  final List<Trabajador> trabajadores;
  final List<Tipooperacion> tiposOperacion;
  final List<dynamic> fincas; // AÑADIDO: Lista de fincas
  final Map<String, dynamic>? operacion; 
  final List<Map<String, dynamic>> operacionesTotales; 

  const PageOperacion({
    Key? key,
    required this.usuario,
    required this.trabajadores,
    required this.tiposOperacion,
    required this.fincas, // REQUERIDO
    this.operacion,
    required this.operacionesTotales,
  }) : super(key: key);

  @override
  State<PageOperacion> createState() => _PageOperacionState();
}

class _PageOperacionState extends State<PageOperacion> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descripcionController = TextEditingController();
  
  late String _koperacion;
  DateTime _fecha = DateTime.now();
  TimeOfDay? _horaDesde;
  TimeOfDay? _horaHasta;
  String? _selectedTipoOperacion;
  String? _selectedFinca; // AÑADIDO: Variable para Finca
  
  List<String> _trabajadoresSeleccionados = [];
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    if (widget.operacion != null) {
      final op = widget.operacion!;
      _koperacion = op['koperacion'];
      _selectedTipoOperacion = op['ktipooperacion'];
      _selectedFinca = op['kfinca']; // Cargamos finca
      _descripcionController.text = op['descripcion_str'] ?? '';
      
      if (op['fechainicio_dtm'] != null) {
        final inicio = DateTime.parse(op['fechainicio_dtm']);
        _fecha = DateTime(inicio.year, inicio.month, inicio.day);
        if (inicio.hour != 0 || inicio.minute != 0) {
          _horaDesde = TimeOfDay(hour: inicio.hour, minute: inicio.minute);
        }
      }
      if (op['fechafin_dtm'] != null) {
        final fin = DateTime.parse(op['fechafin_dtm']);
        if (fin.hour != 0 || fin.minute != 0) {
          _horaHasta = TimeOfDay(hour: fin.hour, minute: fin.minute);
        }
      }
      if (op['trabajadores'] != null) {
        for (var t in op['trabajadores']) {
          _trabajadoresSeleccionados.add(t['ktrabajador']);
        }
      }
    } else {
      _koperacion = const Uuid().v4();
    }
  }

  bool _trabajadorActivoEnFecha(Trabajador t, DateTime fechaOperacion) {
    final inicio = t.fechainicioultimocontratoDtm ?? DateTime(2000);
    final fin = t.fechafinultimocontratoDtm;
    
    final inicioLimpio = DateTime(inicio.year, inicio.month, inicio.day);
    final fechaLimpia = DateTime(fechaOperacion.year, fechaOperacion.month, fechaOperacion.day);
    
    if (fechaLimpia.isBefore(inicioLimpio)) return false;
    
    if (fin != null) {
      final finLimpio = DateTime(fin.year, fin.month, fin.day);
      if (fechaLimpia.isAfter(finLimpio)) return false;
    }
    return true;
  }

  void _verificarSolapamiento(String idTrabajador, String nombre) {
    final fechaLimpia = DateFormat('yyyy-MM-dd').format(_fecha);
    for (var op in widget.operacionesTotales) {
      if (op['koperacion'] == _koperacion) continue; 
      final String opInicio = op['fechainicio_dtm'] ?? '';
      if (opInicio.startsWith(fechaLimpia)) {
        final trabaList = op['trabajadores'] as List<dynamic>? ?? [];
        bool loTiene = trabaList.any((t) => t['ktrabajador'] == idTrabajador);
        if (loTiene) {
          mensajeEmergente(
            context,
            'Aviso: $nombre ya tiene tareas el ${DateFormat('dd/MM/yyyy').format(_fecha)}.',
            tipo: 'warning',
            segundos: 3,
          );
          break; 
        }
      }
    }
  }

  Future<void> _guardarOperacion() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    try {
      TimeOfDay horaFin = _horaHasta ?? _horaDesde ?? const TimeOfDay(hour: 0, minute: 0);
      TimeOfDay horaIni = _horaDesde ?? const TimeOfDay(hour: 0, minute: 0);

      DateTime dtInicio = DateTime(_fecha.year, _fecha.month, _fecha.day, horaIni.hour, horaIni.minute);
      DateTime dtFin = DateTime(_fecha.year, _fecha.month, _fecha.day, horaFin.hour, horaFin.minute);

      if (dtFin.isBefore(dtInicio)) {
        dtFin = dtFin.add(const Duration(days: 1));
      }

      final payload = {
        'koperacion': _koperacion,
        'ktipooperacion': _selectedTipoOperacion,
        'kfinca': _selectedFinca, // AÑADIDO
        'fechainicio_dtm': dtInicio.toIso8601String(),
        'fechafin_dtm': dtFin.toIso8601String(),
        'descripcion_str': _descripcionController.text.trim(),
        'trabajadores': _trabajadoresSeleccionados, 
      };

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final url = Uri.parse('${ApiService.dominioWeb}/mergeoperacion');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(jsonDecode(response.body)['error'] ?? 'Error del servidor');
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      mensajeEmergente(context, 'Operación guardada', tipo: 'success');
    } catch (e) {
      mensajeEmergente(context, 'Error: $e', tipo: 'error');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _seleccionarHora(bool esDesde) async {
    final TimeOfDay? seleccion = await showTimePicker(
      context: context,
      initialTime: esDesde ? (_horaDesde ?? TimeOfDay.now()) : (_horaHasta ?? _horaDesde ?? TimeOfDay.now()),
    );
    if (seleccion != null) {
      setState(() {
        if (esDesde) {
          _horaDesde = seleccion;
          if (_horaHasta == null) _horaHasta = seleccion;
        } else {
          _horaHasta = seleccion;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activos = widget.trabajadores.where((t) => _trabajadorActivoEnFecha(t, _fecha) && t.eliminadoBit == 0).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.operacion == null ? 'Nueva Operación' : 'Editar Operación'),
        actions: [
          IconButton(
            icon: _guardando
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AgriPalette.greenMain, strokeWidth: 2))
                : const Icon(Icons.save),
            color: AgriPalette.greenMain,
            onPressed: _guardando ? null : _guardarOperacion, 
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          children: [
            // --- BLOQUE 1: FECHA Y FINCA (Sin marcos, textos simplificados) ---
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: InkWell(
                    onTap: () async {
                      final dt = await showDatePicker(
                        context: context,
                        initialDate: _fecha,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (dt != null) {
                        setState(() {
                          _fecha = dt;
                          _trabajadoresSeleccionados.removeWhere((id) {
                            final t = widget.trabajadores.firstWhere((tr) => tr.ktrabajador == id, orElse: () => Trabajador(ktrabajador: '', nombreStr: '', kagricultor: '', eliminadoBit: 0, fechaDtm: DateTime.now()));
                            return !_trabajadorActivoEnFecha(t, _fecha);
                          });
                        });
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: AgriPalette.greenMain, size: 20),
                          const SizedBox(width: 8),
                          Text(DateFormat('dd/MM/yyyy').format(_fecha), style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: DropdownButtonHideUnderline( // <-- Oculta la línea inferior del Dropdown
                    child: DropdownButton<String>( // <-- Usamos DropdownButton en vez de FormField para quitar bordes extra
                      value: _selectedFinca,
                      isExpanded: true,
                      hint: const Text('Sin Finca Asociada', style: TextStyle(color: Colors.black87)), // <-- Texto por defecto
                      icon: const Icon(Icons.arrow_drop_down, color: AgriPalette.greenMain),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Sin Finca Asociada')),
                        // CORRECCIÓN: Tratamos 'widget.fincas' como una lista de objetos o de mapas según lo que le pases
                        ...widget.fincas.map((f) {
                            // Adaptación para aceptar tanto el Map (como le pasaste antes) o el Objeto directo
                            String kfinca = f is Map ? f['kfinca'] : f.kfinca;
                            String nombre = f is Map ? f['nombre_str'] : f.nombreStr;
                            return DropdownMenuItem(
                              value: kfinca,
                              child: Text(nombre, overflow: TextOverflow.ellipsis),
                            );
                        }),
                      ],
                      onChanged: (v) => setState(() => _selectedFinca = v),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // --- BLOQUE 2: HORAS (Sin marcos) ---
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _seleccionarHora(true),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, color: AgriPalette.greenMain, size: 20),
                          const SizedBox(width: 8),
                          Text(_horaDesde != null ? _horaDesde!.format(context) : 'Hora Inicio', style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => _seleccionarHora(false),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_filled, color: AgriPalette.greenMain, size: 20),
                          const SizedBox(width: 8),
                          Text(_horaHasta != null ? _horaHasta!.format(context) : 'Hora Fin', style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // --- BLOQUE 3: TIPO Y DESCRIPCIÓN (Mantienen su diseño original) ---
            DropdownButtonFormField<String>(
              value: _selectedTipoOperacion,
              decoration: const InputDecoration(labelText: 'Tipo de Tarea *', border: OutlineInputBorder(), isDense: true),
              items: widget.tiposOperacion.map((t) => DropdownMenuItem(
                value: t.ktipooperacion,
                child: Text(t.tipooperacionStr),
              )).toList(),
              onChanged: (v) => setState(() => _selectedTipoOperacion = v),
              validator: (v) => v == null ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descripcionController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Descripción / Notas', border: OutlineInputBorder(), isDense: true),
            ),
            
            const SizedBox(height: 16),

            // --- BLOQUE 4: TRABAJADORES ULTRACOMPACTOS ---
            Text(
              'Trabajadores Asignados (${_trabajadoresSeleccionados.length})', 
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AgriPalette.greenMain, fontSize: 15)
            ),
            const Divider(height: 16),
            
            if (activos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('No hay trabajadores activos.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
              )
            else
              ...activos.map((t) {
                final isSelected = _trabajadoresSeleccionados.contains(t.ktrabajador);
                return CheckboxListTile(
                  dense: true,
                  visualDensity: const VisualDensity(horizontal: 0, vertical: -4), 
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading, 
                  title: Text(t.nombreStr, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                  value: isSelected,
                  activeColor: AgriPalette.greenMain,
                  onChanged: (bool? val) {
                    setState(() {
                      if (val == true) {
                        _trabajadoresSeleccionados.add(t.ktrabajador);
                        _verificarSolapamiento(t.ktrabajador, t.nombreStr);
                      } else {
                        _trabajadoresSeleccionados.remove(t.ktrabajador);
                      }
                    });
                  },
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
}