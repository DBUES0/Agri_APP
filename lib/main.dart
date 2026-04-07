import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <--- FALTA ESTO
import '../pages/page_login.dart';
import '../pages/page_carga.dart';
import 'utils/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString('token');

  // Si aún no has creado DashboardCarga, pon Provisionalmente la página de Login
  // o el Dashboard si ya tienes los datos.
  Widget pantallaInicial = (token != null && token.isNotEmpty) 
      ? const DashboardCarga() // Cambiaremos esto a DashboardCarga cuando la crees
      : const LoginPage();

  runApp(MyApp(homePage: pantallaInicial));
}

class MyApp extends StatelessWidget {
  final Widget homePage; // <--- AÑADIR ESTO
  const MyApp({super.key, required this.homePage}); // <--- ACTUALIZAR CONSTRUCTOR

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agri APP',
      theme: AppTheme.lightTheme,
      home: homePage, // <--- USAR LA VARIABLE homePage
      debugShowCheckedModeBanner: false,
    );
  }
}