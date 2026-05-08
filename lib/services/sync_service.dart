import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'db_service.dart';
import 'api_service.dart';

class SyncService {
  static bool _isSyncing = false;
  static Timer? _syncTimer;

  // El StreamController que avisa a la UI (Dashboard) para refrescar listas.
  static final _syncController = StreamController<bool>.broadcast();
  static Stream<bool> get syncStream => _syncController.stream;

  /// Enciende el motor de sincronización automática cada 30 segundos
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
    bool huboCambiosEnEstaSesion = false; 

    try {
      // 1. Buscamos registros pendientes de enviar al servidor
      final List<Map<String, dynamic>> pendientes = await db.query(
        'pendientes_sincro',
        orderBy: 'fecha_creacion ASC',
      );

      if (pendientes.isEmpty) {
        _isSyncing = false;
        return;
      }

      print("Sincronización: Procesando ${pendientes.length} registros pendientes.");

      // 2. BUCLE DE PROCESAMIENTO
      for (var item in pendientes) {
        try {
          final String entidad = item['entidad'];
          final Map<String, dynamic> datos = jsonDecode(item['datos_json'] as String);
          
          // --- A. SUBIDA DE ARCHIVOS BINARIOS (Punto 2 modificado) ---
          if (entidad == 'albaran' && datos['archivos'] != null) {
            final List<dynamic> archivos = datos['archivos'];
            
            for (var archivo in archivos) {
              final String rutaLocal = archivo['rutacompleta_str'] ?? "";

              // FILTRO CRÍTICO: Solo subimos si es una ruta local del móvil.
              // Evitamos rutas que empiecen por http o por /root/nas/ (rutas del servidor).
              bool esRutaLocal = rutaLocal.contains('app_flutter') || 
                                 rutaLocal.startsWith('/data/') || 
                                 rutaLocal.startsWith('/var/');

              if (esRutaLocal && !rutaLocal.startsWith('http')) {
                print("Detectado archivo local para subir: ${archivo['nombrearchivo_str']}");
                
                // Subimos el binario usando el UUID generado en el móvil
                String? uuidConfirmado = await ApiService().subirArchivoMultipart(
                  rutaLocal, 
                  datos['kalbaran'], 
                  'ALBARAN',
                  karchivoLocal: archivo['karchivos'], 
                );

                if (uuidConfirmado != null) {
                  // VITAL: Cambiamos la ruta a una marca especial.
                  // Esto evita que 'mergealbaran.php' sobreescriba la ruta del NAS 
                  // en la base de datos con la ruta del móvil.
                  archivo['rutacompleta_str'] = "ALREADY_UPLOADED"; 
                  print("Binario subido con éxito: $uuidConfirmado");
                }
              }
            }
            // Actualizamos los datos con las rutas modificadas a "ALREADY_UPLOADED"
            datos['archivos'] = archivos;
          }
          
          // --- B. ENVIAR DATOS (JSON) A LA API ---
          // Ahora enviamos el albarán completo. Si los archivos se subieron arriba,
          // el servidor solo vinculará los registros.
          String endpoint = (entidad == 'albaran') ? 'mergealbaran' : 'gastos/guardar';
          final response = await ApiService().postParticular(endpoint, datos);

          // --- C. GESTIÓN DE RESPUESTA ---
          if (response.containsKey('error') == false) {
            // Éxito: Eliminamos de la cola local
            await db.delete('pendientes_sincro', where: 'id = ?', whereArgs: [item['id']]);
            huboCambiosEnEstaSesion = true;
            print("Registro ${item['id']} ($entidad) sincronizado correctamente.");
          } else {
            print("Error del servidor en registro ${item['id']}: ${response['error']}");
            // Si el error es de base de datos (como el Column Count), paramos el bucle
            // para que no siga fallando en bucle infinito y revise el código.
            break; 
          }

        } catch (e) {
          // Si el token ha expirado, relanzamos para que la App desloguee
          if (e.toString().contains("401") || e.toString().contains("Expired token")) {
             print("Sesión expirada en segundo plano.");
             rethrow; 
          }
          print("Fallo de conexión o red para el registro ${item['id']}: $e");
          break; // Salimos y reintentamos en 30 segundos
        }
      }

      // --- 3. NOTIFICACIÓN A LA UI ---
      if (huboCambiosEnEstaSesion) {
        print("Sincronización terminada. Refrescando Dashboard...");
        _syncController.add(true); 
      }

    } finally {
      _isSyncing = false;
    }
  }
}