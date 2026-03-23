import 'package:flutter/material.dart';
import 'app_palette.dart';
import 'package:google_fonts/google_fonts.dart';
class AppTheme {

  // Definimos la fuente del logo usando Google Fonts (Lato es casi idéntica a Corbel)
  static TextStyle get logoTextStyle => GoogleFonts.lato(
        fontWeight: FontWeight.bold,
      );

  // WIDGET FUNCIONAL: Para pintar el logo AgriAPP mixto
  static Widget buildLogo({double fontSize = 30}) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Agri',
            style: logoTextStyle.copyWith(
              fontSize: fontSize,
              color: AgriPalette.greyMain, // Gris plomo
            ),
          ),
          TextSpan(
            text: 'APP',
            style: logoTextStyle.copyWith(
              fontSize: fontSize,
              color: AgriPalette.greenMain, // Verde lima
            ),
          ),
        ],
      ),
    );
  }
  
  // Nombre de la familia de fuente definida en pubspec.yaml para el logo
  static const String logoFont = 'AgriLogoFont'; 

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      
      // 1. FUENTE GLOBAL: Roboto (por defecto en Flutter)
      fontFamily: 'Roboto',

      // 2. ESQUEMA DE COLORES
      colorScheme: ColorScheme.fromSeed(
        seedColor: AgriPalette.greenMain,
        primary: AgriPalette.greenMain,
        secondary: AgriPalette.greyMain,
        surface: AgriPalette.white,
        background: AgriPalette.background,
        error: AgriPalette.error,
      ),

      // 3. COMPONENTES ARMONIZADOS
      scaffoldBackgroundColor: AgriPalette.background,
      
      appBarTheme: const AppBarTheme(
        backgroundColor: AgriPalette.greenMain,
        foregroundColor: AgriPalette.white,
        centerTitle: true,
        elevation: 0,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AgriPalette.greenMain,
          foregroundColor: AgriPalette.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AgriPalette.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AgriPalette.greyMain),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AgriPalette.greenMain, width: 2),
        ),
      ),
    );
  }

  // 4. ESTILO ESPECÍFICO PARA EL LOGO
  // Úsalo solo donde quieras que aparezca la fuente del logo
  static TextStyle getLogoStyle({
    double size = 24, 
    Color color = AgriPalette.greyMain, 
    bool isBold = false
  }) {
    return TextStyle(
      fontFamily: logoFont,
      fontSize: size,
      color: color,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
    );
  }
}