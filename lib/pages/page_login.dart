import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Necesario para TextInput.finishAutofillContext()
import 'package:shared_preferences/shared_preferences.dart';

// Importamos el servicio que creamos antes
import '../services/api_service.dart';

// Importamos todos los modelos (records)
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

// Importamos la página de destino
import 'page_usuario.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Los controladores capturan lo que escribes en los cuadros de texto
  final TextEditingController _emailController = TextEditingController(text: 'davidbueso@gmail.com');
  final TextEditingController _passwordController = TextEditingController(text: '1234a*');
  
  // Instanciamos nuestro servicio para usarlo luego
  final ApiService _apiService = ApiService();

  String _error = '';
  bool _isLoading = false; // Para mostrar un circulito de carga

  // Función principal de Login
  Future<void> _login() async {
    setState(() {
      _error = '';
      _isLoading = true; 
    });

    try {
      // Llamamos al servicio
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

      final usuario = Usuario.fromJson(userData);
      
      // Iniciamos la carga masiva de datos
      final fincas = (await _apiService.fetchListV('vfincas'))
          .map((json) => finca.fromJson(json)).toList();
      final almacenes = (await _apiService.fetchList('tblalmacen'))
          .map((json) => Almacen.fromJson(json)).toList();
      final productos = (await _apiService.fetchParticular('productos'))
          .map((json) => Producto.fromJson(json)).toList();
      
      final tiposGasto = (await _apiService.fetchList('tbltipogasto', isComun: true))
          .map((json) => Tipogasto.fromJson(json)).toList();

      final tiposPrecio = (await _apiService.fetchList('tbltipodeprecio', isComun: true))
          .map((json) => Tipodeprecio.fromJson(json)).toList();

      final operaciones = (await _apiService.fetchList('tbltipooperacion', isComun: true))
          .map((json) => Tipooperacion.fromJson(json)).toList();

      final trabajadores = (await _apiService.fetchList('tbltrabajador'))
          .map((json) => Trabajador.fromJson(json)).toList();

      final albaranes = (await _apiService.fetchParticular('albaranes'))
          .map((json) => Albaran.fromJson(json)).toList();

      if (!mounted) return;

      // 1. Cerramos el contexto de autocompletado para que el navegador/sistema 
      // ofrezca guardar la contraseña si el usuario lo desea.
      TextInput.finishAutofillContext();
      
      // 2. Navegamos a la siguiente pantalla pasando todos los datos cargados
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => UsuarioPage(
            usuario: usuario,
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

            // --- BLOQUE DE LOGO ---
            AppTheme.buildLogo(fontSize: 48),
            const SizedBox(height: 10),
            Text(
              "Gestión de Invernaderos",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            
            const SizedBox(height: 60),

            // --- BLOQUE DE FORMULARIO CON AUTOCOMPLETADO ---
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
          ],
        ),
      ),
    );
  }
}