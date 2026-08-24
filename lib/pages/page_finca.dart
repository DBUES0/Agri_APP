import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/record_usuario.dart';
import '../models/record_finca.dart';
import '../services/api_service.dart';
import '../utils/ui_utils.dart';
import '../utils/app_palette.dart';

class PageFincasCRUD extends StatefulWidget {
  final Usuario usuario;
  final List<finca> fincas;

  const PageFincasCRUD({Key? key, required this.usuario, required this.fincas}) : super(key: key);

  @override
  State<PageFincasCRUD> createState() => _PageFincasCRUDState();
}

class _PageFincasCRUDState extends State<PageFincasCRUD> {
  final ApiService _apiService = ApiService();
  late List<finca> _listaFincas;

  @override
  void initState() {
    super.initState();
    _listaFincas = List.from(widget.fincas);
  }

  Future<void> _eliminarFinca(String kfinca) async {
    try {
      await _apiService.deleteGeneric('finca', kfinca);
      setState(() {
        _listaFincas.removeWhere((f) => f.kfinca == kfinca);
      });
      if (!mounted) return;
      mensajeEmergente(context, 'Finca eliminada correctamente');
    } catch (e) {
      mensajeEmergente(context, 'Error al eliminar: $e', tipo: 'error');
    }
  }

  void _mostrarFormulario({finca? fincaItem}) {
    final formKey = GlobalKey<FormState>();
    final nombreController = TextEditingController(text: fincaItem?.nombreStr ?? '');
    final descController = TextEditingController(text: fincaItem?.descripcionStr ?? '');
    final ubiController = TextEditingController(text: fincaItem?.ubicacionStr ?? '');
    final areaController = TextEditingController(text: fincaItem?.aream2Flt.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(fincaItem == null ? 'Nueva Finca' : 'Editar Finca'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nombreController,
                  decoration: const InputDecoration(labelText: 'Nombre de la finca'),
                  validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
                ),
                TextFormField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
                TextFormField(
                  controller: ubiController,
                  decoration: const InputDecoration(labelText: 'Ubicación'),
                ),
                TextFormField(
                  controller: areaController,
                  decoration: const InputDecoration(labelText: 'Área en m²'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AgriPalette.greenMain),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              try {
                final datos = {
                  'nombre_str': nombreController.text,
                  'descripcion_str': descController.text,
                  'Ubicacion_str': ubiController.text,
                  'aream2_float': double.tryParse(areaController.text) ?? 0.0,
                };

                if (fincaItem == null) {
                  // Crear
                  datos['kfinca'] = const Uuid().v4();
                  await _apiService.postGeneric('crearfinca', datos);
                  // Recargar lista local o añadir simulación
                } else {
                  // Editar
                  datos['kfinca'] = fincaItem.kfinca;
                  await _apiService.putGeneric('finca', fincaItem.kfinca, datos);
                }

                if (!mounted) return;
                Navigator.pop(context);
                mensajeEmergente(context, 'Guardado con éxito');
                // Opcional: Refrescar la lista pidiéndola de nuevo a la API
              } catch (e) {
                mensajeEmergente(context, 'Error: $e', tipo: 'error');
              }
            },
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de Fincas')),
      body: ListView.builder(
        itemCount: _listaFincas.length,
        itemBuilder: (context, index) {
          final f = _listaFincas[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text(f.nombreStr, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Ubicación: ${f.ubicacionStr} | Área: ${f.aream2Flt} m²'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: AgriPalette.greenMain),
                    onPressed: () => _mostrarFormulario(fincaItem: f),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: AgriPalette.error),
                    onPressed: () => _eliminarFinca(f.kfinca),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AgriPalette.greenMain,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _mostrarFormulario(),
      ),
    );
  }
}