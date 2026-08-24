import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/record_usuario.dart';
import '../models/record_producto.dart';
import '../services/api_service.dart';
import '../utils/ui_utils.dart';
import '../utils/app_palette.dart';

class PageProductosCRUD extends StatefulWidget {
  final Usuario usuario;
  final List<Producto> productos;

  const PageProductosCRUD({Key? key, required this.usuario, required this.productos}) : super(key: key);

  @override
  State<PageProductosCRUD> createState() => _PageProductosCRUDState();
}

class _PageProductosCRUDState extends State<PageProductosCRUD> {
  final ApiService _apiService = ApiService();
  late List<Producto> _listaProductos;

  @override
  void initState() {
    super.initState();
    _listaProductos = List.from(widget.productos);
  }

  Future<void> _eliminarProducto(String kproducto) async {
    try {
      await _apiService.deleteGeneric('tblproducto', kproducto);
      setState(() {
        _listaProductos.removeWhere((p) => p.kproducto == kproducto);
      });
      if (!mounted) return;
      mensajeEmergente(context, 'Producto eliminado correctamente');
    } catch (e) {
      mensajeEmergente(context, 'Error al eliminar: $e', tipo: 'error');
    }
  }

  void _mostrarFormulario({Producto? productoItem}) {
    final formKey = GlobalKey<FormState>();
    final nombreController = TextEditingController(text: productoItem?.productoStr ?? '');
    
    // Si editamos o creamos, definimos el tipo de albarán por defecto (Ingreso o Gasto)
    String selectedTipoAlbaran = productoItem?.ktipoalbaran ?? "b42f149b-6744-11f0-ac9b-e2b6c6b4d8df";

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(productoItem == null ? 'Nuevo Producto / Concepto' : 'Editar Producto'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nombreController,
                  decoration: const InputDecoration(labelText: 'Nombre del producto o concepto'),
                  validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: selectedTipoAlbaran,
                  decoration: const InputDecoration(labelText: 'Tipo (Ingreso / Gasto)'),
                  items: const [
                    DropdownMenuItem(
                      value: "b42f149b-6744-11f0-ac9b-e2b6c6b4d8df", 
                      child: Text('Ingreso / Producto Cosecha')
                    ),
                    DropdownMenuItem(
                      value: "c4755f6d-6744-11f0-ac9b-e2b6c6b4d8df", 
                      child: Text('Gasto / Concepto Finca')
                    ),
                  ],
                  onChanged: (v) => setDialogState(() => selectedTipoAlbaran = v!),
                ),
              ],
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
                    'producto_str': nombreController.text,
                    'ktipoalbaran': selectedTipoAlbaran,
                  };

                  if (productoItem == null) {
                    datos['kproducto'] = const Uuid().v4();
                    await _apiService.postGeneric('tblproducto', datos);
                  } else {
                    await _apiService.putGeneric('tblproducto', productoItem.kproducto, datos);
                  }

                  if (!mounted) return;
                  Navigator.pop(context);
                  mensajeEmergente(context, 'Guardado con éxito');
                } catch (e) {
                  mensajeEmergente(context, 'Error: $e', tipo: 'error');
                }
              },
              child: const Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de Productos y Conceptos')),
      body: ListView.builder(
        itemCount: _listaProductos.length,
        itemBuilder: (context, index) {
          final p = _listaProductos[index];
          final bool esIngreso = p.ktipoalbaran == "b42f149b-6744-11f0-ac9b-e2b6c6b4d8df";

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text(p.productoStr, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(esIngreso ? 'Tipo: Producto (Ingreso)' : 'Tipo: Concepto (Gasto)'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: AgriPalette.greenMain),
                    onPressed: () => _mostrarFormulario(productoItem: p),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: AgriPalette.error),
                    onPressed: () => _eliminarProducto(p.kproducto),
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