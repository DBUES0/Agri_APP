import 'package:flutter/material.dart';

// Paleta de colores oficial extraída exactamente del logotipo.
class AgriPalette {
  // El verde lima vibrante de la hoja y los campos. Ideal para acciones principales y acentos.
  static const Color greenMain = Color(0xFFA4C639);
  
  // El gris plomo sobrio del pin de localización. Perfecto para texto secundario y bordes.
  static const Color greyMain = Color(0xFF9E9E9E);

  // El color de fondo blanquecino texturizado. Úsalo para el fondo de las pantallas (scaffoldBackgroundColor).
  static const Color background = Color(0xFFF5F5F5);

  // Colores funcionales derivados
  static const Color textPrimary = greyMain; // Usamos el gris plomo como texto principal
  static const Color textOnPrimary = Colors.white; // Para texto sobre botones verdes
  static const Color border = Color(0xFFE0E0E0); // Gris más claro para bordes de inputs
  static const Color white = Colors.white;
  static const Color error = Color(0xFFD32F2F);
}