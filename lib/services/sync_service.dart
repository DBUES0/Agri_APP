import 'dart:async';
import 'dart:convert';
import 'db_service.dart';
import 'api_service.dart';

class SyncService {
  static bool _isSyncing = false;
  static Timer? _syncTimer;

  // El StreamController que avisa a la UI. 
  // .broadcast() permite que varios widgets escuchen a la vez.
  static final _syncController = StreamController<bool>.broadcast();
  static Stream<bool> get syncStream => _syncController.stream;

  /// Enciende el motor de sincronización automática
  static void startAutoSync() {
    if (_syncTimer != null) return;
    print("--- TRABAJADOR DE SINCRONIZACIÓN INICIADO ---");
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await sincronizarTodo();
    });
  }

  /// Apaga el motor
  static void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    print("--- TRABAJADOR DE SINCRONIZACIÓN DETENIDO ---");
  }

  /// MÉTODO MAESTRO DE SINCRONIZACIÓN
  static Future<void> sincronizarTodo() async {
    if (_isSyncing) return;
    _isSyncing = true;
    
    final db = await DBService.instance.database;
    bool huboCambiosEnEstaSesion = false; // <--- NUESTRO SEMÁFORO

    try {
      // 1. Buscamos todos los pendientes
      final List<Map<String, dynamic>> pendientes = await db.query(
        'pendientes_sincro',
        orderBy: 'fecha_creacion ASC',
      );

      if (pendientes.isEmpty) {
        _isSyncing = false;
        return;
      }

      print("Iniciando subida de bloque: ${pendientes.length} registros.");

      // 2. EMPEZAMOS EL BUCLE DE SUBIDA
      for (var item in pendientes) {
        try {
          final String entidad = item['entidad'];
          final Map<String, dynamic> datos = jsonDecode(item['datos_json'] as String);
          
          // A. SUBIDA DE ARCHIVOS (Si es albarán)
          if (entidad == 'albaran' && datos['archivos'] != null) {
            final List<dynamic> archivos = datos['archivos'];
            for (var archivo in archivos) {
              // Si es ruta local, lo subimos
              if (archivo['rutacompleta_str'] != null && !archivo['rutacompleta_str'].startsWith('http')) {
                String? nuevoUuid = await ApiService().subirArchivoMultipart(
                  archivo['rutacompleta_str'], 
                  datos['kalbaran'], 
                  'ALBARAN'
                );
                if (nuevoUuid != null) archivo['karchivos'] = nuevoUuid;
              }
            }
          }
          
          // B. ENVIAR DATOS A LA API
          String endpoint = (entidad == 'albaran') ? 'mergealbaran' : 'gastos/guardar';
          final response = await ApiService().postParticular(endpoint, datos);

          // C. SI EL SERVIDOR RESPONDE OK
          if (response.containsKey('error') == false) {
            await db.delete('pendientes_sincro', where: 'id = ?', whereArgs: [item['id']]);
            huboCambiosEnEstaSesion = true; // <--- Marcamos que algo se ha movido
            print("Registro ${item['id']} sincronizado con éxito.");
          } else {
            print("El servidor rechazó el registro ${item['id']}: ${response['error']}");
            // Si hay un error de validación, paramos para no bloquear el bucle con errores
            break; 
          }
        } catch (e) {
          // GESTIÓN DE SEGURIDAD (TOKEN)
          if (e.toString().contains("Expired token") || e.toString().contains("401")) {
             print("ERROR CRÍTICO: Token caducado en SyncService.");
             rethrow; // Lanzamos el error para que la UI cierre la sesión
          }
          print("Fallo de red para el registro ${item['id']}: $e");
          break; // Si falla la red, salimos del bucle y esperamos a los próximos 30s
        }
      }

      // --- 3. FINAL DEL PROCESO ---
      // Solo si el semáforo está en true (hubo cambios), avisamos a la UI.
      // Esto ocurre una sola vez, después de procesar toda la lista.
      if (huboCambiosEnEstaSesion) {
        print("Sincronización de bloque terminada. Avisando al Dashboard...");
        _syncController.add(true); 
      }

    } finally {
      _isSyncing = false;
    }
  }
}