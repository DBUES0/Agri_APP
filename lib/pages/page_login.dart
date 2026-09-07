// lib/pages/page_login.dart
import 'package:flutter/gestures.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart'; // <-- Soluciona Error 3
import 'package:http/http.dart' as http; // <-- Para llamar a la API directamente

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
Future<void> _abrirUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // Convierte el formato [Texto](url) en un hipervínculo clickeable ocultando la URL
  Widget _buildTextoConEnlace(String texto) {
    final RegExp exp = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');
    final Iterable<RegExpMatch> matches = exp.allMatches(texto);

    if (matches.isEmpty) {
      return Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13));
    }

    List<TextSpan> spans = [];
    int lastMatchEnd = 0;

    for (var match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: texto.substring(lastMatchEnd, match.start)));
      }
      
      String linkText = match.group(1)!;
      String linkUrl = match.group(2)!;

      spans.add(TextSpan(
        text: linkText,
        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
        recognizer: TapGestureRecognizer()..onTap = () => _abrirUrl(linkUrl),
      ));

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < texto.length) {
      spans.add(TextSpan(text: texto.substring(lastMatchEnd)));
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(style: const TextStyle(color: Colors.grey, fontSize: 13), children: spans),
    );
  }

  // --- NUEVA FUNCIÓN CORREGIDA ---
  Future<void> _cargarInfoApp() async {
    try {
      // Usamos http directamente para recibir el JSON completo y no pelear con getAppInfo()
      final response = await http.get(Uri.parse('https://api.bueso.duckdns.org/api/info'));
      
      if (response.statusCode == 200) {
        // Transformamos la respuesta en un diccionario
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (mounted) {
          setState(() {
            _mensajeInfo = data['mensaje']?.toString();
          });
        }

        // Comprobar la versión
        final packageInfo = await PackageInfo.fromPlatform();
        final versionInstalada = packageInfo.version; 
        final versionServidor = data['version_ultima']?.toString();
        final urlApk = data['url_apk']?.toString();

        if (versionServidor != null && versionInstalada != versionServidor && urlApk != null) {
          if (mounted) {
            _mostrarAlertaActualizacion(versionInstalada, versionServidor, urlApk);
          }
        }
      }
    } catch (e) {
      print("Error cargando info de la app: $e");
    }
  }

  // --- CUADRO DE DIÁLOGO ---
  void _mostrarAlertaActualizacion(String versionInstalada, String versionServidor, String urlApk) {
    showDialog(
      context: context,
      barrierDismissible: false, // Obliga al usuario a elegir
      builder: (context) => AlertDialog(
        title: const Text('Actualización disponible'),
        content: Text('Tienes la versión $versionInstalada y la nueva versión $versionServidor está lista para descargar.\n\n¿Deseas actualizar ahora?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Más tarde', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              final Uri url = Uri.parse(urlApk);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication); 
              }
            },
            child: const Text('Actualizar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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

            const Spacer(flex: 2), 
            
            // --- TEXTO DINÁMICO DEL SERVIDOR ---
// --- TEXTO DINÁMICO DEL SERVIDOR ---
            if (_mensajeInfo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0), // Separación con el borde inferior
                child: _buildTextoConEnlace(_mensajeInfo!),
              ),
              // Padding(
              //   padding: const EdgeInsets.only(bottom: 2.0),
              //   child: Linkify(
              //     onOpen: (link) async {
              //       final Uri url = Uri.parse(link.url);
              //       if (await canLaunchUrl(url)) {
              //         await launchUrl(url, mode: LaunchMode.externalApplication);
              //       }
              //     },
              //     // AÑADE ?? '' AQUÍ:
              //     text: _mensajeInfo ?? '', 
              //     textAlign: TextAlign.center,
              //     style: const TextStyle(color: Colors.grey, fontSize: 12),
              //     linkStyle: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              //   )
              // ),
          ],
        ),
      ),
    );
  }
}