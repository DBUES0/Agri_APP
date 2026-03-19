import 'package:flutter/material.dart';
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
// Función principal de Login en page_login.dart
  Future<void> _login() async {
    setState(() {
      _error = '';
      _isLoading = true; 
    });

    try {
      // Llamamos al servicio (esto está bien)
      final response = await _apiService.postLogin(
        _emailController.text.trim(),
        _passwordController.text,
      );

      // --- AQUÍ ESTABA EL ERROR ---
      // Cambiamos 'user' por 'usuario' para que coincida con tu index.php
      final String token = response['token'];
      final Map<String, dynamic>? userData = response['usuario'];

      if (userData == null) {
        throw 'El servidor no devolvió los datos del usuario (clave "usuario" no encontrada).';
      }
      // ----------------------------

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);

      final usuario = Usuario.fromJson(userData);
      
      // Iniciamos la carga masiva de datos
      print('hola Antes');
      final fincas = (await _apiService.fetchListV('vfincas'))
          .map((json) => finca.fromJson(json)).toList();
      print('hola');    
      final almacenes = (await _apiService.fetchList('tblalmacen'))
          .map((json) => Almacen.fromJson(json)).toList();
      
      final productos = (await _apiService.fetchParticular('productos'))
          .map((json) => Producto.fromJson(json)).toList();
      
      // CAMBIO: Añadimos isComun: true porque tbltipogasto es una tabla compartida
      final tiposGasto = (await _apiService.fetchList('tbltipogasto', isComun: true))
          .map((json) => Tipogasto.fromJson(json)).toList();

      // CAMBIO: Añadimos isComun: true porque tbltipogasto es una tabla compartida
      final tiposPrecio = (await _apiService.fetchList('tbltipodeprecio', isComun: true))
          .map((json) => Tipodeprecio.fromJson(json)).toList();

       // CAMBIO: Añadimos isComun: true porque tbltipogasto es una tabla compartida
      final operaciones = (await _apiService.fetchList('tbltipooperacion', isComun: true))
          .map((json) => Tipooperacion.fromJson(json)).toList();
          
    //  final operaciones = (await _apiService.fetchList('tbltipooperacion'))
    //       .map((json) => Tipooperacion.fromJson(json)).toList();

      final trabajadores = (await _apiService.fetchList('tbltrabajador'))
          .map((json) => Trabajador.fromJson(json)).toList();
// print('hola Antes Albaranes');   
      final albaranes = (await _apiService.fetchParticular('albaranes'))
          .map((json) => Albaran.fromJson(json)).toList();
// print('holaDespues Albaranes');   
      if (!mounted) return;
      
      // Navegamos a la siguiente pantalla pasando todos los datos cargados
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
    // La UI ahora está mucho más limpia
    return Scaffold(
      appBar: AppBar(title: const Text("Gestión Agrícola - Login")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController, 
              decoration: const InputDecoration(labelText: 'Correo electrónico', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController, 
              decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
              obscureText: true,
            ),
            const SizedBox(height: 25),
            
            // Si está cargando, mostramos un círculo. Si no, el botón.
            _isLoading 
              ? const CircularProgressIndicator() 
              : ElevatedButton(
                  onPressed: _login, 
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  child: const Text("ENTRAR"),
                ),
                
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(_error, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

