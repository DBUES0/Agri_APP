import 'package:agriapp/services/sync_service.dart';
import 'package:flutter/material.dart'; // <--- ESTO ARREGLA CASI TODOS LOS ERRORES
import 'package:sqflite/sqflite.dart';   // Para Sqflite.firstIntValue
import '../services/db_service.dart';
import '../utils/ui_utils.dart';


class IconoSync extends StatelessWidget {
  const IconoSync({super.key});

  // Función para contar pendientes
  Future<int> _contarPendientes() async {
    final db = await DBService.instance.database;
    final res = await db.rawQuery('SELECT COUNT(*) as total FROM pendientes_sincro');
    return Sqflite.firstIntValue(res) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      // Polling: Esto se ejecutará cada vez que el widget se reconstruya
      future: _contarPendientes(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        
        if (count == 0) return const SizedBox.shrink(); // No mostrar nada si no hay pendientes

        return IconButton(
          icon: Stack(
            children: [
              const Icon(Icons.cloud_upload_outlined, color: Colors.orange),
              Positioned(
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                  child: Text('$count', style: const TextStyle(fontSize: 8, color: Colors.white)),
                ),
              ),
            ],
          ),
          onPressed: () async {
            mensajeEmergente(context, "Sincronizando $count registros...");
            await SyncService.sincronizarTodo();
            // Forzar refresco de la UI (depende de cómo gestiones el estado)
          },
        );
      },
    );
  }
}