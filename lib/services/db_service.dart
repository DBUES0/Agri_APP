import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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
          'json_data': item.toString(), // O jsonEncode(item)
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}