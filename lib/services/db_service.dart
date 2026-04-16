import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'sync_service.dart';

class DBService {
  static final DBService instance = DBService._init();
  static Database? _database;

  DBService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('agri_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Tabla para guardar el último timestamp de sincronización por entidad
    await db.execute('''
      CREATE TABLE sync_metadata (
        entidad TEXT PRIMARY KEY,
        ultima_sincro TEXT
      )
    ''');

    // Tabla genérica para caché (puedes crear una por cada Record si prefieres)
    // Pero para empezar, usaremos una tabla de "Cache Global"
    await db.execute('''
      CREATE TABLE local_cache (
        tabla TEXT,
        id TEXT,
        json_data TEXT,
        PRIMARY KEY (tabla, id)
      )
    ''');

  // Tabla para registros creados/editados en el móvil que aún no están en el servidor
  await db.execute('''
    CREATE TABLE pendientes_sincro (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      entidad TEXT,      -- 'albaran', 'gasto', etc.
      operacion TEXT,    -- 'INSERT', 'UPDATE', 'DELETE'
      datos_json TEXT,   -- El objeto completo en JSON
      fecha_creacion TEXT
    )
  ''');

  }

  // Método para guardar una lista de objetos en la caché
  Future<void> saveToCache(String tabla, List<Map<String, dynamic>> datos) async {
    final db = await instance.database;
    Batch batch = db.batch();
    
    for (var item in datos) {
      // Asumimos que todos tus registros tienen una clave primaria (ej: kalbaran, kfinca)
      // La detectamos dinámicamente (suele empezar por 'k')
      String idKey = item.keys.firstWhere((k) => k.startsWith('k'), orElse: () => 'id');
      
      batch.insert(
        'local_cache',
        {
          'tabla': tabla,
          'id': item[idKey].toString(),
          // 'json_data': item.toString(), 
          'json_data': jsonEncode(item),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

// Metodo para guardar en la base de datos del movil los registros que se han creado o editado y que aún no se han sincronizado con el servidor, intentando sincronizar automáticamente después de guardar

Future<void> registrarPendiente({
  required String entidad, 
  required Map<String, dynamic> datos
}) async {
  final db = await database;
  await db.insert('pendientes_sincro', {
    'entidad': entidad,
    'operacion': 'MERGE',
    'datos_json': jsonEncode(datos),
    'fecha_creacion': DateTime.now().toIso8601String(),
  });
  
  // Intentar sincronizar automáticamente al guardar
  SyncService.sincronizarTodo();
}

Future<List<Map<String, dynamic>>> getAllFromLocal(String tabla) async {
  final db = await database;
  // Consultamos la tabla de caché filtrando por el nombre de la entidad
  final res = await db.query('local_cache', where: 'tabla = ?', whereArgs: [tabla]);
  
  // Convertimos el String JSON que guardamos en la DB de vuelta a un Mapa de Dart
  return res.map((item) => jsonDecode(item['json_data'] as String) as Map<String, dynamic>).toList();
}


}