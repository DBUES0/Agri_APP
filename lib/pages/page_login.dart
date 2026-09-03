// lib/pages/page_login.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/db_service.dart';

import '../models/record_usuario.dart';
import '../models/record_finca.dart';
import '../models/record_almacen.dart';
import '../models/record_producto.dart';
import '../models/record_tipodeprecio.dart';
import '../models/record_tipogasto.dart';
import '../models/record_tipooperacion.dart';
import '../models/record_trabajador.dart';
import '../models/record_albaran.dart';
import '../utils/app_theme.dart';

// Importamos el Dashboard directamente
import 'page_dashboard.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController(text: 'v.galdeanofernandez@gmail.com');
  final TextEditingController _passwordController = TextEditingController(text: '');
  
  final ApiService _apiService = ApiService();

  String _error = '';
  bool _isLoading = false; 
  String? _mensajeInfo; // Variable para almacenar el texto del servidor

  @override
  void initState() {
    super.initState();
    _cargarInfoApp();
  }

  // Descarga el texto dinámico al arrancar la pantalla
  Future<void> _cargarInfoApp() async {
    final info = await _apiService.getAppInfo();
    if (info != null && mounted) {
      setState(() {
        _mensajeInfo = info;
      });
    }
  }

  Future<void> _login() async {
    setState(() {
      _error = '';
      _isLoading = true; 
    });

    try {
      final response = await _apiService.postLogin(
        _emailController.text.trim(),
        _passwordController.text,
      );

      final String token = response['token'];
      final Map<String, dynamic>? userData = response['usuario'];

      if (userData == null) {
        throw 'El servidor no devolvió los datos del usuario (clave "usuario" no encontrada).';
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('usuario_json', jsonEncode(userData));

      await DBService.instance.limpiarTodaLaBaseDeDatos();

      final usuario = Usuario.fromJson(userData);
      
      final fincas = (await _apiService.fetchListV('vfincas'))
          .map((json) => finca.fromJson(json)).toList();

      String idReal = usuario.kagricultor;
      if (idReal.isEmpty && fincas.isNotEmpty) {
         idReal = fincas.first.kagricultor;
      }
      
      final usuarioCorregido = Usuario(
        kagricultor: idReal,
        nombre: usuario.nombre,
        apellidos: usuario.apellidos,
        dni: usuario.dni,
        direccion: usuario.direccion,
        email: usuario.email,
        telefono: usuario.telefono,
        validado: usuario.validado,
        bloqueado: usuario.bloqueado,
        intentos: usuario.intentos,
        ultimoIntento: usuario.ultimoIntento,
        tipoUsuario: usuario.tipoUsuario,
        prefAgrupacion: usuario.prefAgrupacion,
        prefAgrupacionGastos: usuario.prefAgrupacionGastos,
      );
      
      final almacenes = (await _apiService.fetchList('tblalmacen', isMixto: true))
          .map((json) => Almacen.fromJson(json)).toList();
          
      final productos = (await _apiService.fetchList('tblproducto', isComun: true))
          .map((json) => Producto.fromJson(json)).toList();
          
      final tiposGasto = (await _apiService.fetchList('tbltipogasto', isComun: true))
          .map((json) => Tipogasto.fromJson(json)).toList();

      final tiposPrecio = (await _apiService.fetchList('tbltipodeprecio', isComun: true))
          .map((json) => Tipodeprecio.fromJson(json)).toList();

      final operaciones = (await _apiService.fetchList('tbltipooperacion', isComun: true))
          .map((json) => Tipooperacion.fromJson(json)).toList();

      final trabajadores = (await _apiService.fetchList('tbltrabajador'))
          .map((json) => Trabajador.fromJson(json)).toList();

      final albaranes = (await _apiService.fetchParticular('albaranesv2'))
          .map((json) => Albaran.fromJson(json)).toList();

      if (!mounted) return;

      TextInput.finishAutofillContext();
      
      // 6. Navegamos pasando los datos DIRECTAMENTE AL DASHBOARD
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardPage(
            usuario: usuarioCorregido, 
            fincas: fincas,
            tiposGasto: tiposGasto,
            almacen: almacenes,
            producto: productos,
            tipodeprecio: tiposPrecio,
            tipooperacion: operaciones,
            trabajador: trabajadores,
            albaranes: albaranes,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _error = 'Error al entrar: $e';
      });
    } finally {
      setState(() {
        _isLoading = false; 
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Spacer(flex: 2), 

            AppTheme.buildLogo(fontSize: 48),
            const SizedBox(height: 10),
            Text(
              "Gestión de Invernaderos",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            
            const SizedBox(height: 60),

            AutofillGroup(
              child: Column(
                children: [
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Correo electrónico'),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Contraseña'),
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
            
            _isLoading 
              ? const CircularProgressIndicator() 
              : ElevatedButton(
                  onPressed: _login, 
                  child: const Text("ENTRAR"),
                ),
                
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                _error, 
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error, 
                  fontWeight: FontWeight.bold,
                ), 
                textAlign: TextAlign.center,
              ),
            ],

            const Spacer(flex: 6), 
            
            // --- TEXTO DINÁMICO DEL SERVIDOR ---
            if (_mensajeInfo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  _mensajeInfo!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    height: 1.4, // Interlineado para facilitar lectura de varias líneas
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}