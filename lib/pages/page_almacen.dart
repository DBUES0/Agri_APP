import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/record_usuario.dart';
import '../models/record_almacen.dart';
import '../services/api_service.dart';
import '../utils/ui_utils.dart';
import '../utils/app_palette.dart';

class PageAlmacenesCRUD extends StatefulWidget {
  final Usuario usuario;
  final List<Almacen> almacenes;

  const PageAlmacenesCRUD({Key? key, required this.usuario, required this.almacenes}) : super(key: key);

  @override
  State<PageAlmacenesCRUD> createState() => _PageAlmacenesCRUDState();
}

class _PageAlmacenesCRUDState extends State<PageAlmacenesCRUD> {
  final ApiService _apiService = ApiService();
  late List<Almacen> _listaAlmacenes;
  bool _isLoading = false;

  // UUID del agricultor maestro (Catálogo General)
  static const String masterAgricultorId = '6223c8a4-0f95-11f0-ab54-e2b6c6b4d8df';

  @override
  void initState() {
    super.initState();
    _listaAlmacenes = List.from(widget.almacenes);
  }

  // Método para refrescar la lista desde la API y mantenerla sincronizada
  Future<void> _cargarAlmacenes() async {
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.fetchList('tblalmacen', isComun: true);
      setState(() {
        _listaAlmacenes = data.map((json) => Almacen.fromJson(json)).toList();
      });
    } catch (e) {
      mensajeEmergente(context, 'Error al actualizar lista: $e', tipo: 'error');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _eliminarAlmacen(String kalmacen) async {
    try {
      await _apiService.deleteGeneric('tblalmacen', kalmacen);
      await _cargarAlmacenes(); // Recargamos de la API
      if (!mounted) return;
      mensajeEmergente(context, 'Almacén/Proveedor marcado como eliminado');
    } catch (e) {
      mensajeEmergente(context, 'Error al eliminar: $e', tipo: 'error');
    }
  }

  // void _mostrarFormulario({Almacen? almacenItem}) {
  //   final formKey = GlobalKey<FormState>();
  //   final nombreController = TextEditingController(text: almacenItem?.nombreStr ?? '');
    
  //   // Por defecto asignamos el tipo de albarán de Ingresos si es nuevo
  //   String selectedTipoAlbaran = almacenItem?.ktipoalbaran ?? "b42f149b-6744-11f0-ac9b-e2b6c6b4d8df";

  //   showDialog(
  //     context: context,
  //     builder: (context) => StatefulBuilder(
  //       builder: (context, setDialogState) => AlertDialog(
  //         title: Text(almacenItem == null ? 'Nuevo Almacén / Proveedor' : 'Editar Entidad'),
  //         content: Form(
  //           key: formKey,
  //           child: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             children: [
  //               TextFormField(
  //                 controller: nombreController,
  //                 decoration: const InputDecoration(labelText: 'Nombre del almacén o proveedor'),
  //                 validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
  //               ),
  //               const SizedBox(height: 15),
  //               DropdownButtonFormField<String>(
  //                 value: selectedTipoAlbaran,
  //                 decoration: const InputDecoration(labelText: 'Tipo de Documento'),
  //                 items: const [
  //                   DropdownMenuItem(
  //                     value: "b42f149b-6744-11f0-ac9b-e2b6c6b4d8df", 
  //                     child: Text('Almacén de Destino (Ingresos)')
  //                   ),
  //                   DropdownMenuItem(
  //                     value: "c4755f6d-6744-11f0-ac9b-e2b6c6b4d8df", 
  //                     child: Text('Proveedor / Acreedor (Gastos)')
  //                   ),
  //                 ],
  //                 onChanged: (v) => setDialogState(() => selectedTipoAlbaran = v!),
  //               ),
  //             ],
  //           ),
  //         ),
  //         actions: [
  //           TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
  //           ElevatedButton(
  //             style: ElevatedButton.styleFrom(backgroundColor: AgriPalette.greenMain),
  //             onPressed: () async {
  //               if (!formKey.currentState!.validate()) return;

  //               try {
  //                 final datos = {
  //                   'nombre_str': nombreController.text,
  //                   'ktipoalbaran': selectedTipoAlbaran,
  //                 };

  //                 if (almacenItem == null) {
  //                   datos['kalmacen'] = const Uuid().v4();
  //                   await _apiService.postGeneric('tblalmacen', datos);
  //                 } else {
  //                   await _apiService.putGeneric('tblalmacen', almacenItem.kalmacen, datos);
  //                 }

  //                 if (!mounted) return;
  //                 Navigator.pop(context);
  //                 await _cargarAlmacenes(); // Refrescamos la lista automáticamente
  //                 mensajeEmergente(context, 'Guardado correctamente');
  //               } catch (e) {
  //                 mensajeEmergente(context, 'Error: $e', tipo: 'error');
  //               }
  //             },
  //             child: const Text('Guardar', style: TextStyle(color: Colors.white)),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

void _mostrarFormulario({Almacen? almacenItem}) {
    final formKey = GlobalKey<FormState>();
    final nombreController = TextEditingController(text: almacenItem?.nombreStr ?? '');
    String selectedTipoAlbaran = almacenItem?.ktipoalbaran ?? "b42f149b-6744-11f0-ac9b-e2b6c6b4d8df";

    // 1. Capturamos el context principal de la página de forma segura
    final currentContext = context;

    showDialog(
      context: currentContext,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(almacenItem == null ? 'Nuevo Almacén / Proveedor' : 'Editar Entidad'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nombreController,
                  decoration: const InputDecoration(labelText: 'Nombre del almacén o proveedor'),
                  validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: selectedTipoAlbaran,
                  decoration: const InputDecoration(labelText: 'Tipo de Documento'),
                  items: const [
                    DropdownMenuItem(
                      value: "b42f149b-6744-11f0-ac9b-e2b6c6b4d8df", 
                      child: Text('Almacén de Destino (Ingresos)')
                    ),
                    DropdownMenuItem(
                      value: "c4755f6d-6744-11f0-ac9b-e2b6c6b4d8df", 
                      child: Text('Proveedor / Acreedor (Gastos)')
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
                    'nombre_str': nombreController.text,
                    'ktipoalbaran': selectedTipoAlbaran,
                  };

                  if (almacenItem == null) {
                    datos['kalmacen'] = const Uuid().v4();
                    await _apiService.postGeneric('tblalmacen', datos);
                  } else {
                    await _apiService.putGeneric('tblalmacen', almacenItem.kalmacen, datos);
                  }

                  // 2. Cerramos el diálogo primero usando su propio context local
                  if (!mounted) return;
                  Navigator.pop(context);

                  // 3. Recargamos los datos
                  await _cargarAlmacenes(); 

                  // 4. Usamos el context principal (currentContext) que sigue activo
                  if (!mounted) return;
                  mensajeEmergente(currentContext, 'Guardado correctamente', tipo: 'success');
                } catch (e) {
                  if (!mounted) return;
                  mensajeEmergente(currentContext, 'Error: $e', tipo: 'error');
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
    // Filtro listo para mostrar tanto los del maestro como los propios del usuario actual
    final almacenesVisibles = _listaAlmacenes.where((a) => 
      a.kagricultor == masterAgricultorId || a.kagricultor == widget.usuario.kagricultor
    ).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Almacenes y Proveedores'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarAlmacenes,
            tooltip: 'Actualizar lista',
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: almacenesVisibles.length,
            itemBuilder: (context, index) {
              final a = almacenesVisibles[index];
              final bool esGlobal = a.kagricultor == masterAgricultorId;
              final bool esIngreso = a.ktipoalbaran == "b42f149b-6744-11f0-ac9b-e2b6c6b4d8df";

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(a.nombreStr, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${esIngreso ? "Ingreso" : "Gasto"} • ${esGlobal ? "Catálogo General / Maestro" : "Personalizado"}'
                  ),
                  trailing: esGlobal 
                    ? const Chip(label: Text('Global', style: TextStyle(fontSize: 10))) 
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: AgriPalette.greenMain),
                            onPressed: () => _mostrarFormulario(almacenItem: a),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: AgriPalette.error),
                            onPressed: () => _eliminarAlmacen(a.kalmacen),
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