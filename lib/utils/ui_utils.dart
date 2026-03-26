import 'package:flutter/material.dart';
import 'app_palette.dart'; // Importante para acceder a tus colores

/// Función global para mostrar mensajes armonizados con AgriAPP
void mensajeEmergente(
  BuildContext context, 
  String mensaje, {
  Color? colorFondo, 
  Color? colorFuente, 
  int segundos = 3,
  String tipo = 'info', // 'info', 'error', 'success', 'warning'
  double altura = 0,    // % adicional de altura desde el fondo
}) {
  // Definimos los colores basados en la paleta de la App
  switch (tipo) {
    case 'success':
      colorFondo ??= AgriPalette.greenMain; // Tu verde del logo
      colorFuente ??= Colors.white;
      break;
    case 'error':
      colorFondo ??= const Color(0xFFE57373); // Un rojo suave armonizado
      colorFuente ??= Colors.white;
      break;
    case 'warning':
      colorFondo ??= const Color(0xFFFFB74D); // Naranja suave
      colorFuente ??= Colors.black87;
      break;
    case 'info':
    default:
      colorFondo ??= AgriPalette.textoVerdeOscuro; // El gris plomo de tu logo
      colorFuente ??= AgriPalette.backgroundLogo; // Un verde oscuro para buen contraste
      break;
  }

  // Limpiamos snacks anteriores para evitar colas largas
  ScaffoldMessenger.of(context).removeCurrentSnackBar();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        mensaje,
        textAlign: TextAlign.center, // Centramos el texto para mejor estética
        style: TextStyle(
          color: colorFuente,
          fontWeight: FontWeight.w500, // Un poco más de peso para legibilidad
        ),
      ),
      backgroundColor: colorFondo,
      duration: Duration(seconds: segundos),
      behavior: SnackBarBehavior.floating,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), // Bordes más redondeados
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).size.height * (0.05 + altura / 100),
        left: 20, // Más margen lateral para que se vea más como una "píldora"
        right: 20,
      ),
    ),
  );
}