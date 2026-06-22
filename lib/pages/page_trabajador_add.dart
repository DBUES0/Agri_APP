import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/ui_utils.dart';
import 'package:intl/intl.dart'; // Importa intl para formatear fechas si lo tienes, o usa toIso8601String()
import 'package:uuid/uuid.dart';

class PageTrabajadorForm extends StatefulWidget {
  const PageTrabajadorForm({Key? key}) : super(key: key);

  @override
  State<PageTrabajadorForm> createState() => _PageTrabajadorFormState();
}

class _PageTrabajadorFormState extends State<PageTrabajadorForm> {
  final _formKey = GlobalKey<FormState>();
  
  // Controladores
  final _nombreController = TextEditingController();
  final _dniController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  final _fechaInicioController = TextEditingController();
  final _fechaFinController = TextEditingController();

  // Variables para guardar las fechas reales
  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  final ApiService _apiService = ApiService();

  Future<void> _selectDate(BuildContext context, bool esInicio) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (esInicio) {
          _fechaInicio = picked;
          _fechaInicioController.text = DateFormat('yyyy-MM-dd').format(picked);
        } else {
          _fechaFin = picked;
          _fechaFinController.text = DateFormat('yyyy-MM-dd').format(picked);
        }
      });
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    // GENERAR UUID LOCALMENTE
    final String nuevoId = const Uuid().v4();

    try {
        final nuevoTrabajador = {
          'ktrabajador': nuevoId, // Enviamos el ID ya generado
          'nombre_str': _nombreController.text,
          'dni_str': _dniController.text,
          'telefono_str': _telefonoController.text,
          'email_str': _emailController.text,
          'fechainicioultimocontrato_dtm': _fechaInicio?.toIso8601String(),
          'fechafinultimocontrato_dtm': _fechaFin?.toIso8601String(),
          'eliminado_bit': 0, // ENVIAR SIEMPRE COMO INT (0)
        };

      await _apiService.postGeneric('tbltrabajador', nuevoTrabajador);
      
      if (!mounted) return;
      mensajeEmergente(context, "Trabajador creado correctamente");
      Navigator.pop(context, true);
    } catch (e) {
      mensajeEmergente(context, "Error: $e", tipo: 'error');
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _dniController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _fechaInicioController.dispose();
    _fechaFinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nuevo Trabajador")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView( // ListView evita problemas con el teclado
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: 'Nombre Completo', icon: Icon(Icons.person)),
                validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
              ),
              TextFormField(
                controller: _dniController,
                decoration: const InputDecoration(labelText: 'DNI / NIE', icon: Icon(Icons.badge)),
              ),
              TextFormField(
                controller: _telefonoController,
                decoration: const InputDecoration(labelText: 'Teléfono', icon: Icon(Icons.phone)),
                keyboardType: TextInputType.phone,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email', icon: Icon(Icons.email)),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _fechaInicioController,
                readOnly: true, // No dejar escribir manualmente
                decoration: const InputDecoration(labelText: 'Fecha Inicio Contrato', icon: Icon(Icons.calendar_today)),
                onTap: () => _selectDate(context, true),
              ),
              TextFormField(
                controller: _fechaFinController,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Fecha Fin Contrato (Opcional)', icon: Icon(Icons.calendar_today)),
                onTap: () => _selectDate(context, false),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _guardar,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                child: const Text("GUARDAR TRABAJADOR"),
              )
            ],
          ),
        ),
      ),
    );
  }
}