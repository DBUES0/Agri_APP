import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../services/db_service.dart';
import '../services/sync_service.dart';
import '../utils/ui_utils.dart';

class IconoSync extends StatefulWidget {
  const IconoSync({super.key});

  @override
  State<IconoSync> createState() => _IconoSyncState();
}

class _IconoSyncState extends State<IconoSync> {
  // Creamos un "Stream" que consulta la base de datos cada 3 segundos
  Stream<int> _pendientesStream() async* {
    while (true) {
      await Future.delayed(const Duration(seconds: 3)); // Pausa de 3 segundos
      final db = await DBService.instance.database;
      final res = await db.rawQuery('SELECT COUNT(*) as total FROM pendientes_sincro');
      yield Sqflite.firstIntValue(res) ?? 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _pendientesStream(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        // Si el conteo llega a 0, el icono desaparece solo
        if (count == 0) return const SizedBox.shrink();

        return IconButton(
          icon: Stack(
            clipBehavior: Clip.none, // Permite que el círculo rojo sobresalga
            children: [
              const Icon(Icons.cloud_upload_outlined, color: Colors.orange, size: 28),
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Center(
                    child: Text(
                      '$count',
                      style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
          onPressed: () async {
            mensajeEmergente(context, "Sincronizando $count registros...");
            await SyncService.sincronizarTodo();
            // Al terminar la sincronización, el Stream detectará 
            // el cambio en la siguiente vuelta (máx 3 seg).
          },
        );
      },
    );
  }
}