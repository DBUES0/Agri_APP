import 'dart:async';
import 'dart:convert';
import 'db_service.dart';
import 'api_service.dart';

class SyncService {
  // Flag para evitar que se ejecuten dos sincronizaciones al mismo tiempo
  static bool _isSyncing = false;
  
  // El temporizador que buscará datos pendientes periódicamente
  static Timer? _syncTimer;

  /// Inicia el trabajador en segundo plano. 
  /// Se recomienda llamarlo una sola vez al arrancar la app (en main.dart o page_carga.dart).
  static void startAutoSync() {
    if (_syncTimer != null) return; // Si ya está corriendo, no hacemos nada

    print("--- TRABAJADOR DE SINCRONIZACIÓN INICIADO ---");
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      // Cada 30 segundos intentamos sincronizar
      await sincronizarTodo();
    });
  }

  /// Detiene el trabajador (útil si el usuario cierra sesión)
  static void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// El método principal que recorre la cola de pendientes y los envía a la API
  static Future<void> sincronizarTodo() async {
    if (_isSyncing) return;
    
    _isSyncing = true;
    final db = await DBService.instance.database;

    try {
      // 1. Obtenemos los pendientes por orden de creación
      final List<Map<String, dynamic>> pendientes = await db.query(
        'pendientes_sincro',
        orderBy: 'fecha_creacion ASC',
      );

      if (pendientes.isEmpty) {
        _isSyncing = false;
        return;
      }

      print("Intentando sincronizar ${pendientes.length} registros...");

      for (var item in pendientes) {
        try {
          final String entidad = item['entidad'];
          final Map<String, dynamic> datos = jsonDecode(item['datos_json']);
          final List<dynamic> archivos = datos['archivos'] ?? [];

          for (var archivo in archivos) {
            // Si la ruta no empieza por "http", es que es un archivo local pendiente de subir
            if (archivo['rutacompleta_str'] != null && !archivo['rutacompleta_str'].startsWith('http')) {
              
              String? nuevoUuidServidor = await ApiService().subirArchivoMultipart(
                archivo['rutacompleta_str'], 
                datos['kalbaran'], // El kuuid que espera tu PHP
                'ALBARAN'          // El tipo que espera tu PHP
              );

              if (nuevoUuidServidor != null) {
                // Actualizamos el objeto local con el ID real del servidor
                archivo['karchivos'] = nuevoUuidServidor;
                // Opcional: podrías marcarlo como 'ya subido'
              }
            }
          }
          
          // Una vez procesados los archivos, enviamos el Albarán completo
          await ApiService().postParticular('mergealbaran', datos);
          
          // Definimos el endpoint según el tipo de dato
          String endpoint = (entidad == 'albaran') ? 'mergealbaran' : 'gastos/guardar';

          // 2. Enviamos a la API
          // Nota: postParticular ya debería manejar la lógica de errores 401
          final response = await ApiService().postParticular(endpoint, datos);

          // 3. Si no hay error en la respuesta, borramos de la base de datos local
          if (response.containsKey('error') == false) {
            await db.delete('pendientes_sincro', where: 'id = ?', whereArgs: [item['id']]);
            print("ID ${item['id']} ($entidad) sincronizado y borrado de la cola.");
          } else {
            print("Error del servidor para ID ${item['id']}: ${response['error']}");
            break; // Paramos el bucle si el servidor rechaza el dato
          }
        } catch (e) {
          // Manejo de Token expirado o errores de red
          if (e.toString().contains("Expired token") || e.toString().contains("401")) {
             print("Sincronización abortada: Sesión caducada.");
             // Aquí no podemos usar 'context' porque no es un widget. 
             // Pero el error se propagará y la UI lo manejará.
          }
          print("Error de red o conexión: $e");
          break; // Si falla la red, dejamos de intentar con el resto por ahora
        }
      }
    } finally {
      _isSyncing = false;
    }
  }
}