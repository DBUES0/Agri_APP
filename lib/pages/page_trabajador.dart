import 'package:flutter/material.dart';
import '../models/record_trabajador.dart';
import '../services/api_service.dart';
import '../utils/app_palette.dart';
import '../pages/page_trabajador_add.dart';

class PageTrabajadores extends StatefulWidget {
  const PageTrabajadores({Key? key}) : super(key: key);

  @override
  State<PageTrabajadores> createState() => _PageTrabajadoresState();
}

class _PageTrabajadoresState extends State<PageTrabajadores> {
  final ApiService _apiService = ApiService();
  List<Trabajador> _trabajadores = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarTrabajadores();
  }

  Future<void> _cargarTrabajadores() async {
    setState(() => _cargando = true);
    _trabajadores = await _apiService.fetchTrabajadoresActivos();
    setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gestión de personal")),
      body: _cargando 
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _trabajadores.length,
              itemBuilder: (context, index) {
                final t = _trabajadores[index];
                return ListTile(
                  leading: CircleAvatar(child: Icon(Icons.person)),
                  title: Text(t.nombreStr),
                  subtitle: Text(t.dniStr ?? "Sin DNI"),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: AgriPalette.greenMain),
                    onPressed: () { /* Navegar a editar */ },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PageTrabajadorForm()),
          );
          if (result == true) {
            _cargarTrabajadores(); // Refrescamos la lista si se creó uno nuevo
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}