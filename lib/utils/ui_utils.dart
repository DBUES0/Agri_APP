import 'package:flutter/material.dart';

/// Función global para mostrar mensajes en toda la aplicación
void mensajeEmergente(BuildContext context, String mensaje, {
  Color? colorFondo, 
  Color? colorFuente, 
  int segundos = 3
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        mensaje,
        style: TextStyle(color: colorFuente ?? Colors.black),
      ),
      // Si no se provee color, usamos un gris oscuro por defecto
      backgroundColor: colorFondo ?? const Color.fromARGB(255, 226, 239, 214),
      duration: Duration(seconds: segundos),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).size.height * 0.05, // 5% desde abajo
        left: 20,
        right: 20,
      ),
    ),
  );
}