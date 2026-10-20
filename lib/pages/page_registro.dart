// lib/pages/page_registro.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../services/api_service.dart';
import '../utils/app_palette.dart';
import '../utils/app_theme.dart';
import '../utils/ui_utils.dart';

class PageRegistro extends StatefulWidget {
  const PageRegistro({super.key});

  @override
  State<PageRegistro> createState() => _PageRegistroState();
}

class _PageRegistroState extends State<PageRegistro> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _apellidosController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _dniController = TextEditingController();
  final TextEditingController _fincaController = TextEditingController(text: 'General');
  final TextEditingController _areaController = TextEditingController(text: '10000');

  bool _isLoading = false;
  String _error = '';

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidosController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _dniController.dispose();
    _fincaController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  String _generarCodigoValidacion() {
    final random = Random();
    final numero = random.nextInt(900000) + 100000;
    return numero.toString();
  }

  Future<void> _registrarUsuario() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final String kagricultor = const Uuid().v4();
      final String kfinca = const Uuid().v4();
      final String codigoValidacion = _generarCodigoValidacion();

      String nombreFinca = _fincaController.text.trim();
      if (nombreFinca.isEmpty) nombreFinca = 'General';

      double areaFinca = double.tryParse(_areaController.text.trim()) ?? 10000.0;

      final Map<String, dynamic> datosRegistro = {
        'kagricultor': kagricultor,
        'nombre_str': _nombreController.text.trim(),
        'apellidos_str': _apellidosController.text.trim(),
        'email_str': _emailController.text.trim(),
        'password_str': _passwordController.text,
        'dni_str': _dniController.text.trim(),
        'codigo_validacion_str': codigoValidacion,
        'validado_bit': 0,
        'nombre_finca_str': nombreFinca,
        'kfinca': kfinca,
        'aream2_flt': areaFinca,
      };

      const String urlRegistro = 'https://api.bueso.duckdns.org/api/registro';

      print('🚀 [REGISTRO] POST URL: $urlRegistro');
      print('📦 [REGISTRO] Body: ${jsonEncode(datosRegistro)}');

      final response = await http.post(
        Uri.parse(urlRegistro),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(datosRegistro),
      );

      print('📡 [REGISTRO] Status Code: ${response.statusCode}');
      print('📥 [REGISTRO] Response Body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        final Map<String, dynamic> resMap = jsonDecode(response.body);
        throw resMap['error'] ?? resMap['mensaje'] ?? 'Error (${response.statusCode})';
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      _mostrarDialogoValidacion(codigoValidacion);
    } catch (e) {
      print('❌ [REGISTRO ERROR]: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Error en el registro: $e';
        _isLoading = false;
      });
    }
  }

  void _mostrarDialogoValidacion(String codigo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.send_rounded, color: AgriPalette.greenMain),
            SizedBox(width: 10),
            Text('Validación requerida'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Para activar tu cuenta, debes enviar tu código de validación al bot de Telegram:',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AgriPalette.greenMain.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AgriPalette.greenMain),
              ),
              child: SelectableText(
                codigo,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  color: AgriPalette.greenMain,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Haz clic abajo para abrir el bot y enviar la orden de activación.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0088CC),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.telegram),
            label: const Text('ABRIR TELEGRAM'),
            onPressed: () async {
              final Uri urlTelegram = Uri.parse('https://t.me/agri_APP_bot?start=$codigo');
              if (await canLaunchUrl(urlTelegram)) {
                await launchUrl(urlTelegram, mode: LaunchMode.externalApplication);
              } else {
                if (context.mounted) {
                  mensajeEmergente(context, 'No se pudo abrir Telegram');
                }
              }
              if (context.mounted) Navigator.pop(context);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Cuenta'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTheme.buildLogo(fontSize: 36),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(labelText: 'Nombre *'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Campo obligatorio' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _apellidosController,
                  decoration: const InputDecoration(labelText: 'Apellidos *'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Campo obligatorio' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _dniController,
                  decoration: const InputDecoration(labelText: 'DNI / NIF *'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Campo obligatorio' : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo electrónico *'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
                    if (!v.contains('@')) return 'Correo no válido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña *'),
                  validator: (v) => v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null,
                ),
                const SizedBox(height: 20),

                const Divider(),
                const SizedBox(height: 10),
                Text(
                  'Datos de la primera Finca',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AgriPalette.greenMain,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _fincaController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la Finca',
                    hintText: 'Por defecto: General',
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _areaController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Superficie (m²)',
                    hintText: 'Ej: 10000',
                  ),
                ),

                const SizedBox(height: 24),

                if (_error.isNotEmpty) ...[
                  Text(
                    _error,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],

                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _registrarUsuario,
                        child: const Text('REGISTRARSE Y ACTIVAR'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}