import 'package:flutter/material.dart';

/// Función global para mostrar mensajes en toda la aplicación
void mensajeEmergente(BuildContext context, String mensaje, {
  Color? colorFondo, 
  Color? colorFuente, 
  int segundos = 3,
  String tipo = 'info',
  int altura = 0 //en %, para ajustar la altura del mensaje desde abajo
}) {
  switch (tipo) {
    case 'info':
      colorFondo ??= Colors.green[300];
      colorFuente ??= Colors.white;
      break;
    case 'error':
      colorFondo ??= Colors.red[300];
      colorFuente ??= Colors.white;
      break;
    case 'success':
      colorFondo ??= Colors.green[300];
      colorFuente ??= Colors.white;
      break;
    case 'warning':
      colorFondo ??= Colors.orange[300];
      colorFuente ??= Colors.white;
      break;
    default:
      colorFondo ??= const Color.fromARGB(255, 226, 239, 214);
      colorFuente ??= Colors.black;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        mensaje,
        style: TextStyle(color: colorFuente),
      ),
      // Si no se provee color, usamos un gris oscuro por defecto
      backgroundColor: colorFondo,
      duration: Duration(seconds: segundos),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).size.height * (0.05 + altura / 100), // 5% desde abajo
        left: 20,
        right: 20,
      ),
    ),
  );
}