import 'package:flutter/material.dart';

class AppColors {
  // Colores principales (basados en tu estilo agrícola)
  static const Color primario = Color(0xFF2E7D32); // Un verde bosque robusto
  static const Color secundario = Color(0xFFFFA000); // Un naranja ámbar para avisos/detalles
  static const Color fondo = Color(0xFFF5F5F5); // Gris muy claro para el fondo
  static const Color error = Color(0xFFD32F2F);
  static const Color tarjetas = Colors.white;
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true, // Habilita el diseño moderno de Google
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primario,
        primary: AppColors.primario,
        secondary: AppColors.secundario,
        surface: AppColors.tarjetas,
        background: AppColors.fondo,
        error: AppColors.error,
      ),
      
      // Armonización de Fuentes
      fontFamily: 'Roboto', // O la que prefieras (asegúrate de incluirla en pubspec.yaml)
      
      // Estilo global de las AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primario,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),

      // Estilo global de los Botones
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primario,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      // Estilo de los campos de texto (Input)
    // inputDecorationTheme: InputDecorationTheme(
    //   filled: true,             // Añade un ligero fondo
    //   fillColor: Colors.white,   // Fondo blanco para que no se vea transparente
    //   contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), // Espacio interno
    //   border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
    //     focusedBorder: OutlineInputBorder(
    //       borderRadius: BorderRadius.circular(12),
    //       borderSide: const BorderSide(color: AppColors.primario, width: 20),
    //     ),
    //   ),
inputDecorationTheme: InputDecorationTheme(
  filled: true,
  fillColor: Colors.white,
  isDense: false, // Permite que el campo use su altura natural
  contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11), // Más altura interna
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.grey.shade400),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.grey.shade300),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.primario, width: 2),
  ),
  // Esto ayuda a que el label (Almacén de Destino) no se monte con el borde superior
  floatingLabelBehavior: FloatingLabelBehavior.always, 
),

    );
  }
}