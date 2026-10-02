//page_nota.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart'; // <--- OBLIGATORIO PARA getApplicationDocumentsDirectory
import 'dart:io';

import '../models/record_usuario.dart';
import '../services/api_service.dart';
import '../services/db_service.dart'; 
import '../utils/app_palette.dart';
import '../utils/ui_utils.dart';

class PageNota extends StatefulWidget {
  final Usuario usuario;
  final Map<String, dynamic>? nota; 

  const PageNota({Key? key, required this.usuario, this.nota}) : super(key: key);

  @override
  State<PageNota> createState() => _PageNotaState();
}

class _PageNotaState extends State<PageNota> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _contenidoController = TextEditingController();
  
  late String _knota;
  late DateTime _fecha;
  List<Map<String, dynamic>> _archivos = []; 
  bool _esNueva = true;

  @override
  void initState() {
    super.initState();
    
    if (widget.nota != null) {
      _esNueva = false;
      final n = widget.nota!;
      
      _knota = n['knota'] ?? const Uuid().v4();
      _tituloController.text = n['titulo_str'] ?? '';
      _contenidoController.text = n['contenido_str'] ?? '';
      
      if (n['fecha_dtm'] != null) {
        try {
          _fecha = DateTime.parse(n['fecha_dtm']);
        } catch (_) {
          _fecha = DateTime.now();
        }
      } else {
        _fecha = DateTime.now();
      }

      if (n['archivos'] != null && n['archivos'] is List) {
        _archivos = List<Map<String, dynamic>>.from(n['archivos']);
      }
    } else {
      _esNueva = true;
      _knota = const Uuid().v4();
      _fecha = DateTime.now();
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _contenidoController.dispose();
    super.dispose();
  }

  Future<void> _guardarNota() async {
    try {
      String tituloFinal = _tituloController.text.trim();
      if (tituloFinal.isEmpty) {
        final f = DateFormat("yyyy/MM/dd 'a las' HH:mm:ss");
        tituloFinal = "Nota ${f.format(DateTime.now())}";
      }

      final Map<String, dynamic> notaCompleta = {
        'knota': _knota,
        'kagricultor': widget.usuario.kagricultor,
        'titulo_str': tituloFinal,
        'contenido_str': _contenidoController.text.trim(),
        'fecha_dtm': _fecha.toIso8601String(),
        'eliminado_bit': 0,
        'archivos': _archivos, 
      };

      await DBService.instance.registrarPendiente(
        entidad: 'nota', 
        datos: notaCompleta
      );

      if (!mounted) return;
      
      Navigator.pop(context, true); 
      mensajeEmergente(context, 'Nota guardada localmente', tipo: 'success');
      
    } catch (e) {
      mensajeEmergente(context, 'Error al guardar: $e', tipo: 'error');
    }
  }

  Future<void> _mostrarOAnadirArchivos() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: AgriPalette.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: StatefulBuilder( 
          builder: (context, setModalState) {
            final archivosVisibles = _archivos.where((a) => a['eliminado_bit'] != 1).toList();

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Archivos Adjuntos',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AgriPalette.greyMain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Divider(color: AgriPalette.greyMain.withValues(alpha: 0.2)),
                  
                  if (archivosVisibles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(30),
                      child: Text('No hay archivos adjuntos', style: TextStyle(fontStyle: FontStyle.italic, color: AgriPalette.greyMain)),
                    )
                  else
                    ConstrainedBox( 
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: archivosVisibles.length,
                        itemBuilder: (context, index) {
                          final archivo = archivosVisibles[index];
                          final String nombre = archivo['nombrearchivo_str'] ?? archivo['nombrearchivo'] ?? 'Archivo';
                          
                          return ListTile(
                            leading: const Icon(Icons.insert_drive_file, color: AgriPalette.greenMain),
                            title: Text(nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () async {
                              final karchivo = archivo['karchivos'];
                              if (karchivo != null) {
                                try {
                                  await _apiService.descargarYVerArchivo(karchivo);
                                } catch (e) {
                                  mensajeEmergente(context, 'No se puede abrir el archivo: $e', tipo: 'error');
                                }
                              } else {
                                mensajeEmergente(context, 'Archivo no subido aún (pendiente sincro)');
                              }
                            },
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: AgriPalette.error),
                              onPressed: () {
                                setState(() {
                                  archivo['eliminado_bit'] = 1;
                                  archivo['fechaeliminacion_dtm'] = DateTime.now().toIso8601String();
                                });
                                setModalState(() {}); 
                                mensajeEmergente(context, 'Archivo marcado para eliminar', tipo: 'warning');
                              },
                            ),
                          );
                        },
                      ),
                    ),

                  const Divider(),
                  
                  _buildActionTile(
                    context: context,
                    icon: Icons.camera_alt,
                    label: 'Hacer Foto',
                    onTap: () => _handleFileAction(() => _obtenerImagen(ImageSource.camera)),
                  ),
                  _buildActionTile(
                    context: context,
                    icon: Icons.photo_library,
                    label: 'Elegir de Galería',
                    onTap: () => _handleFileAction(() => _obtenerImagen(ImageSource.gallery)),
                  ),
                  _buildActionTile(
                    context: context,
                    icon: Icons.attach_file,
                    label: 'Adjuntar Archivo/PDF',
                    onTap: () => _handleFileAction(_seleccionarYSubirArchivo),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleFileAction(Function action) {
    Navigator.pop(context); 
    action(); 
  }

  Widget _buildActionTile({required BuildContext context, required IconData icon, required String label, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: AgriPalette.greenMain),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: AgriPalette.greyMain)),
      onTap: onTap,
    );
  }

  Future<void> _obtenerImagen(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 70);

    if (image != null) {
      await _procesarArchivoLocal(image.path, image.name);
    }
  }

  Future<void> _seleccionarYSubirArchivo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.single.path != null) {
      await _procesarArchivoLocal(result.files.single.path!, result.files.single.name);
    }
  }

  Future<void> _procesarArchivoLocal(String pathOriginal, String name) async {
    try {
      String newFileUuid = const Uuid().v4();
      final String extension = name.split('.').last;
      
      // ERROR 1 SOLUCIONADO: Usamos getApplicationDocumentsDirectory
      final directory = await getApplicationDocumentsDirectory();
      final String nuevoPath = '${directory.path}/$newFileUuid.$extension';
      await File(pathOriginal).copy(nuevoPath);

      if (!mounted) return;

      setState(() {
        _archivos.add({
          'karchivos': newFileUuid, 
          'kuuid': _knota,        
          'nombrearchivo_str': name,
          'fecha_dtm': DateTime.now().toIso8601String(),
          'formato_str': extension.toUpperCase(),
          'tipo_str': 'NOTA',     
          'eliminado_bit': 0,
          'orden_int': _archivos.length + 1,
          'rutacompleta_str': nuevoPath, 
        });
      });

      mensajeEmergente(context, 'Archivo adjuntado localmente');
    } catch (e) {
      mensajeEmergente(context, 'Error al procesar archivo: $e', tipo: 'error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_esNueva ? 'Nueva Nota' : 'Editar Nota'),
        actions: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            color: AgriPalette.greenMain,
            onPressed: _mostrarOAnadirArchivos,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            color: AgriPalette.greenMain,
            onPressed: _guardarNota,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextFormField(
                controller: _tituloController,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: 'Título (Opcional)',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 5),
              // ERROR 2 SOLUCIONADO: Envuelto en Align en vez de usar parámetro
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_fecha.day.toString().padLeft(2, '0')}/${_fecha.month.toString().padLeft(2, '0')}/${_fecha.year} ${_fecha.hour.toString().padLeft(2, '0')}:${_fecha.minute.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AgriPalette.greyMain),
                ),
              ),
              const Divider(),
              const SizedBox(height: 10),
              TextFormField(
                controller: _contenidoController,
                maxLines: null, 
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: 'Empieza a escribir aquí...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}