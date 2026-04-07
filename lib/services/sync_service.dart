import 'dart:convert';

import 'package:agriapp/services/db_service.dart';

import '../services/api_service.dart';
// Clase para evitar que haya dos sincronizaciones a la vez (que podría pasar si el usuario pulsa varias veces en "Guardar" sin red)
class SyncService {
  static bool _isSyncing = false;

  static Future<void> sincronizarTodo() async {
    // Si ya hay una sincronización en marcha, no hacemos nada
    if (_isSyncing) return;
    
    _isSyncing = true;
    final db = await DBService.instance.database;
    
    try {
      final List<Map<String, dynamic>> pendientes = await db.query(
        'pendientes_sincro', 
        orderBy: 'fecha_creacion ASC' // Importante: enviar en orden
      );

      for (var item in pendientes) {
        try {
          final String entidad = item['entidad'];
          final Map<String, dynamic> datos = jsonDecode(item['datos_json']);
          
          // --- LÓGICA GENÉRICA ---
          // Dependiendo de la 'entidad', decidimos a qué endpoint enviar
          String endpoint = '';
          if (entidad == 'albaran') endpoint = 'mergealbaran';
          if (entidad == 'gasto') endpoint = 'gastos/guardar'; // Ejemplo
          
          // Dentro del bucle for en SyncService
          final response = await ApiService().postParticular(endpoint, datos);

          // Si tu API devuelve un mapa con 'success' o similar:
          if (response.containsKey('error') == false) {
              await db.delete('pendientes_sincro', where: 'id = ?', whereArgs: [item['id']]);
          } else {
              break; // Algo salió mal en el servidor, paramos la cola
          }
        } catch (e) {
          // Si falla un registro (por red), hacemos BREAK. 
          // No intentamos el siguiente porque probablemente tampoco haya red.
          print("Error sincronizando ID ${item['id']}: $e");
          break; 
        }
      }
    } finally {
      _isSyncing = false; // Liberamos el "cerrojo" siempre, pase lo que pase
    }
  }
}
