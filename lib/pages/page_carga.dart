import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_palette.dart';

// Modelos
import '../models/record_usuario.dart';
import '../models/record_finca.dart';
import '../models/record_almacen.dart';
import '../models/record_producto.dart';
import '../models/record_tipodeprecio.dart';
import '../models/record_tipogasto.dart';
import '../models/record_tipooperacion.dart';
import '../models/record_trabajador.dart';
import '../models/record_albaran.dart';
import '../utils/ui_utils.dart';
import '../services/db_service.dart'; // <--- ASEGÚRATE DE QUE ESTÉ ESTE

// Destino
import 'page_usuario.dart'; // Tu DashboardPage (UsuarioPage)
import 'page_login.dart';

class DashboardCarga extends StatefulWidget {
  const DashboardCarga({super.key});

  @override
  State<DashboardCarga> createState() => _DashboardCargaState();
}

class _DashboardCargaState extends State<DashboardCarga> {
  final ApiService _apiService = ApiService();
  String _mensajeStatus = "Iniciando sesión...";

  @override
  void initState() {
    super.initState();
    _iniciarApp();
  }

  // Future<void> _iniciarApp() async {
  //   try {
  //     // 1. Verificar si tenemos token (doble comprobación)
  //     final prefs = await SharedPreferences.getInstance();
  //     final String? token = prefs.getString('token');

  //     // En page_carga.dart:
  //     final String? userJson = prefs.getString('usuario_json');
  //     if (userJson != null) {
  //       final usuario = Usuario.fromJson(jsonDecode(userJson));
  //       // ¡Ya tienes al usuario sin llamar a la API!
  //     }

  //     //borrar
  //     mensajeEmergente(context, 'Token encontrado: $token', segundos: 5);
  //     print('Token encontrado: $token');
  //     if (token == null || token.isEmpty) {
  //       _irAlLogin();
  //       return;
  //     }

  //     // 2. Cargar Perfil de Usuario 
  //     // (Asumiendo que tienes un endpoint 'perfil' o similar que use el Bearer token)
  //     setState(() => _mensajeStatus = "Cargando perfil...");

  //     // La respuesta suele venir como una lista de un solo elemento [ {datos...} ]
  //     final response = await _apiService.fetchParticular('perfil');

  //     // CAMBIO AQUÍ: Si es una lista, tomamos el primero. Si es un mapa, lo usamos directo.
  //     final Map<String, dynamic> userData = (response is List) ? response.first : response;

  //     //Comentamos esto porque usuario viene cargado de arriba 
  //     final usuario = Usuario.fromJson(userData);
  //     // 3. CARGA MASIVA (Copiada de tu lógica de login)
  //     setState(() => _mensajeStatus = "Sincronizando fincas...");
  //     final fincas = (await _apiService.fetchListV('vfincas'))
  //         .map((json) => finca.fromJson(json)).toList();

  //     setState(() => _mensajeStatus = "Cargando almacenes...");
  //     final almacenes = (await _apiService.fetchList('tblalmacen'))
  //         .map((json) => Almacen.fromJson(json)).toList();

  //     setState(() => _mensajeStatus = "Cargando productos...");
  //     final productos = (await _apiService.fetchParticular('productos'))
  //         .map((json) => Producto.fromJson(json)).toList();

  //     setState(() => _mensajeStatus = "Configurando maestros...");
  //     final tiposGasto = (await _apiService.fetchList('tbltipogasto', isComun: true))
  //         .map((json) => Tipogasto.fromJson(json)).toList();

  //     final tiposPrecio = (await _apiService.fetchList('tbltipodeprecio', isComun: true))
  //         .map((json) => Tipodeprecio.fromJson(json)).toList();

  //     final operaciones = (await _apiService.fetchList('tbltipooperacion', isComun: true))
  //         .map((json) => Tipooperacion.fromJson(json)).toList();

  //     setState(() => _mensajeStatus = "Cargando personal...");
  //     final trabajadores = (await _apiService.fetchList('tbltrabajador'))
  //         .map((json) => Trabajador.fromJson(json)).toList();

  //     setState(() => _mensajeStatus = "Recuperando albaranes...");
  //     final albaranes = (await _apiService.fetchParticular('albaranes'))
  //         .map((json) => Albaran.fromJson(json)).toList();

  //     if (!mounted) return;

  //     // 4. Salto al Dashboard con todos los datos
  //     Navigator.pushReplacement(
  //       context,
  //       MaterialPageRoute(
  //         builder: (context) => UsuarioPage(
  //           usuario: usuario,
  //           fincas: fincas,
  //           tiposGasto: tiposGasto,
  //           almacen: almacenes,
  //           producto: productos,
  //           tipodeprecio: tiposPrecio,
  //           tipooperacion: operaciones,
  //           trabajador: trabajadores,
  //           albaranes: albaranes,
  //         ),
  //       ),
  //     );

  //   } catch (e) {
  //     print("Error en carga automática: $e");
  //     // Si el token falló o expiró, borramos y al login
  //     final prefs = await SharedPreferences.getInstance();
  //     await prefs.remove('token');
  //     _irAlLogin();
  //   }
  // }
/*
Future<void> _iniciarApp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');

      mensajeEmergente(context, 'token: $token', segundos: 2);

      if (token == null || token.isEmpty) {
        _irAlLogin();
        return;
      }

      // 1. DEFINIMOS LA VARIABLE FUERA PARA QUE SEA ACCESIBLE DESPUÉS
      Usuario? usuario;

      // Intentamos cargar desde el "disco" (Opción A)
      final String? userJson = prefs.getString('usuario_json');
      
      mensajeEmergente(context, 'Usuario: $userJson', segundos: 2);

      if (userJson != null) {
        setState(() => _mensajeStatus = "Recuperando sesión local...");
        usuario = Usuario.fromJson(jsonDecode(userJson));
      } else {
        // Si por alguna razón no hay JSON local, lo pedimos a la API
        setState(() => _mensajeStatus = "Cargando perfil desde servidor...");
        final response = await _apiService.fetchParticular('perfil');
        final Map<String, dynamic> userData = (response is List) ? response.first : response;
        usuario = Usuario.fromJson(userData);
        
        // Lo guardamos para la próxima vez
        await prefs.setString('usuario_json', jsonEncode(userData));
      }

      // 2. CARGA MASIVA DE DATOS
      // Aquí seguimos igual, descargando lo necesario para el Dashboard
      setState(() => _mensajeStatus = "Sincronizando fincas...");
      // final fincas = (await _apiService.fetchListV('vfincas'))
      //     .map((json) => finca.fromJson(json)).toList();

      try {
        final fincas = (await _apiService.fetchListV('vfincas'))
            .map((json) => finca.fromJson(json)).toList();
        // Guardamos en caché para la próxima vez que estemos offline
        await DBService.instance.saveToCache('vfincas', fincas.map((e) => e.toJson()).toList());
      } catch (e) {
        // Si falla la red, leemos de SQL
        final localData = await DBService.instance.getAllFromLocal('vfincas');
        fincas = localData.map((json) => finca.fromJson(json)).toList();
      }
      setState(() => _mensajeStatus = "Cargando almacenes...");
      final almacenes = (await _apiService.fetchList('tblalmacen'))
          .map((json) => Almacen.fromJson(json)).toList();

      setState(() => _mensajeStatus = "Cargando productos...");
      final productos = (await _apiService.fetchParticular('productos'))
          .map((json) => Producto.fromJson(json)).toList();

      setState(() => _mensajeStatus = "Configurando maestros...");
      final tiposGasto = (await _apiService.fetchList('tbltipogasto', isComun: true))
          .map((json) => Tipogasto.fromJson(json)).toList();

      final tiposPrecio = (await _apiService.fetchList('tbltipodeprecio', isComun: true))
          .map((json) => Tipodeprecio.fromJson(json)).toList();

      final operaciones = (await _apiService.fetchList('tbltipooperacion', isComun: true))
          .map((json) => Tipooperacion.fromJson(json)).toList();

      setState(() => _mensajeStatus = "Cargando personal...");
      final trabajadores = (await _apiService.fetchList('tbltrabajador'))
          .map((json) => Trabajador.fromJson(json)).toList();

      setState(() => _mensajeStatus = "Recuperando albaranes...");
      final albaranes = (await _apiService.fetchParticular('albaranes'))
          .map((json) => Albaran.fromJson(json)).toList();

      if (!mounted) return;

      // 3. SALTO AL DASHBOARD
      // Usamos 'usuario!' porque estamos seguros de que no es nulo a estas alturas
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => UsuarioPage(
            usuario: usuario!, 
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
      print("Error en carga automática: $e");
      _irAlLogin();
    }
  }
*/

Future<void> _iniciarApp() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      _irAlLogin();
      return;
    }

    // --- 1. DECLARAMOS LAS VARIABLES AL PRINCIPIO ---
    Usuario? usuario;
    List<finca> fincas = [];
    List<Almacen> almacenes = [];
    List<Producto> productos = [];
    List<Tipogasto> tiposGasto = [];
    List<Tipodeprecio> tiposPrecio = [];
    List<Tipooperacion> operaciones = [];
    List<Trabajador> trabajadores = [];
    List<Albaran> albaranes = [];

    // --- 2. CARGAR PERFIL ---
    final String? userJson = prefs.getString('usuario_json');
    if (userJson != null) {
      setState(() => _mensajeStatus = "Recuperando sesión local...");
      usuario = Usuario.fromJson(jsonDecode(userJson));
    } else {
      setState(() => _mensajeStatus = "Cargando perfil desde servidor...");
      final response = await _apiService.fetchParticular('perfil');
      final Map<String, dynamic> userData = (response is List) ? response.first : response;
      usuario = Usuario.fromJson(userData);
      await prefs.setString('usuario_json', jsonEncode(userData));
    }

    // --- 3. CARGA MASIVA CON FALLBACK OFFLINE ---
    
    // FINCAS
    setState(() => _mensajeStatus = "Sincronizando fincas...");
    try {
      fincas = (await _apiService.fetchListV('vfincas'))
          .map((json) => finca.fromJson(json)).toList();
      await DBService.instance.saveToCache('vfincas', fincas.map((e) => e.toJson()).toList());
    } catch (e) {
      final local = await DBService.instance.getAllFromLocal('vfincas');
      fincas = local.map((json) => finca.fromJson(json)).toList();
    }

    // ALMACENES
    setState(() => _mensajeStatus = "Cargando almacenes...");
    try {
      almacenes = (await _apiService.fetchList('tblalmacen'))
          .map((json) => Almacen.fromJson(json)).toList();
      await DBService.instance.saveToCache('tblalmacen', almacenes.map((e) => e.toJson()).toList());
    } catch (e) {
      final local = await DBService.instance.getAllFromLocal('tblalmacen');
      almacenes = local.map((json) => Almacen.fromJson(json)).toList();
    }

    // PRODUCTOS
    setState(() => _mensajeStatus = "Cargando productos...");
    try {
      productos = (await _apiService.fetchParticular('productos'))
          .map((json) => Producto.fromJson(json)).toList();
      await DBService.instance.saveToCache('productos', productos.map((e) => e.toJson()).toList());
    } catch (e) {
      final local = await DBService.instance.getAllFromLocal('productos');
      productos = local.map((json) => Producto.fromJson(json)).toList();
    }

    // MAESTROS (TIPOS GASTO, PRECIO, OPERACION)
    // Nota: Para ahorrar código, puedes hacerlos individuales o en bloque
    setState(() => _mensajeStatus = "Configurando maestros...");
    try {
      tiposGasto = (await _apiService.fetchList('tbltipogasto', isComun: true))
          .map((json) => Tipogasto.fromJson(json)).toList();
      tiposPrecio = (await _apiService.fetchList('tbltipodeprecio', isComun: true))
          .map((json) => Tipodeprecio.fromJson(json)).toList();
      operaciones = (await _apiService.fetchList('tbltipooperacion', isComun: true))
          .map((json) => Tipooperacion.fromJson(json)).toList();
      
      // Guardar en caché
      await DBService.instance.saveToCache('tbltipogasto', tiposGasto.map((e) => e.toJson()).toList());
      await DBService.instance.saveToCache('tbltipodeprecio', tiposPrecio.map((e) => e.toJson()).toList());
      await DBService.instance.saveToCache('tbltipooperacion', operaciones.map((e) => e.toJson()).toList());
    } catch (e) {
      final lGasto = await DBService.instance.getAllFromLocal('tbltipogasto');
      tiposGasto = lGasto.map((json) => Tipogasto.fromJson(json)).toList();
      final lPrecio = await DBService.instance.getAllFromLocal('tbltipodeprecio');
      tiposPrecio = lPrecio.map((json) => Tipodeprecio.fromJson(json)).toList();
      final lOperacion = await DBService.instance.getAllFromLocal('tbltipooperacion');
      operaciones = lOperacion.map((json) => Tipooperacion.fromJson(json)).toList();
    }

    // TRABAJADORES
    setState(() => _mensajeStatus = "Cargando personal...");
    try {
      trabajadores = (await _apiService.fetchList('tbltrabajador'))
          .map((json) => Trabajador.fromJson(json)).toList();
      await DBService.instance.saveToCache('tbltrabajador', trabajadores.map((e) => e.toJson()).toList());
    } catch (e) {
      final local = await DBService.instance.getAllFromLocal('tbltrabajador');
      trabajadores = local.map((json) => Trabajador.fromJson(json)).toList();
    }

    // ALBARANES
    setState(() => _mensajeStatus = "Recuperando albaranes...");
    try {
      albaranes = (await _apiService.fetchParticular('albaranes'))
          .map((json) => Albaran.fromJson(json)).toList();
      await DBService.instance.saveToCache('albaranes', albaranes.map((e) => e.toJson()).toList());
    } catch (e) {
      final local = await DBService.instance.getAllFromLocal('albaranes');
      albaranes = local.map((json) => Albaran.fromJson(json)).toList();
    }

    if (!mounted) return;

    // --- 4. SALTO AL DASHBOARD ---
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => UsuarioPage(
          usuario: usuario!, 
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
    print("Error crítico en carga: $e");
    // Solo si el usuario es null (primera vez total) vamos al login
    _irAlLogin();
  }
}

  void _irAlLogin() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AgriPalette.background,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Spacer(flex: 2),
            
            // Logo y Estilo idéntico a tu Login
            AppTheme.buildLogo(fontSize: 48),
            const SizedBox(height: 10),
            Text(
              "AgriAPP",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
            
            const SizedBox(height: 60),
            
            // Indicador de carga armonizado
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AgriPalette.greenMain),
              strokeWidth: 3,
            ),
            
            const SizedBox(height: 20),
            
            Text(
              _mensajeStatus,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AgriPalette.greyMain.withValues(alpha: 0.7),
              ),
            ),

            const Spacer(flex: 6),
          ],
        ),
      ),
    );
  }
}