//page_note.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../models/record_usuario.dart';
import '../services/api_service.dart';
import '../utils/app_palette.dart';
import '../utils/ui_utils.dart';

class PageNota extends StatefulWidget {
  final Usuario usuario;
  final Map<String, dynamic>? nota; // Si es null, es una nota nueva

  const PageNota({Key? key, required this.usuario, this.nota}) : super(key: key);

  @override
  State<PageNota> createState() => _PageNotaState();
}

class _PageNotaState extends State<PageNota> {
  final ApiService _apiService = ApiService();
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _contenidoController = TextEditingController();
  
  List<Map<String, dynamic>> _archivos = [];
  bool _guardando = false;
  late String _knota;

  @override
  void initState() {
    super.initState();
    if (widget.nota != null) {
      _knota = widget.nota!['knota'];
      _tituloController.text = widget.nota!['titulo_str'] ?? '';
      _contenidoController.text = widget.nota!['contenido_str'] ?? '';
      _cargarArchivosAdjuntos();
    } else {
      _knota = const Uuid().v4();
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _contenidoController.dispose();
    super.dispose();
  }

  Future<void> _cargarArchivosAdjuntos() async {
    // Si tu API permite filtrar archivos por kuuid, aquí los recuperaríamos
    // Ejemplo: final rawArchivos = await _apiService.fetchList('tblarchivos?kuuid=$_knota');
  }

  Future<void> _guardarNota() async {
    setState(() => _guardando = true);
    
    try {
      String tituloFinal = _tituloController.text.trim();
      if (tituloFinal.isEmpty) {
        // Título genérico si está vacío
        tituloFinal = "Nota ${DateFormat("yyyy/MM/dd 'a las' HH:mm:ss").format(DateTime.now())}";
      }

      final Map<String, dynamic> datosNota = {
        'knota': _knota,
        'kagricultor': widget.usuario.kagricultor,
        'titulo_str': tituloFinal,
        'contenido_str': _contenidoController.text.trim(),
        'fecha_dtm': widget.nota != null 
            ? widget.nota!['fecha_dtm'] 
            : DateTime.now().toIso8601String(),
        'eliminado_bit': 0,
      };

      if (widget.nota == null) {
        await _apiService.postGeneric('tblnota', datosNota);
      } else {
        await _apiService.putGeneric('tblnota', _knota, datosNota);
      }

      if (!mounted) return;
      Navigator.pop(context, true); // Retorna true para refrescar el Dashboard
      mensajeEmergente(context, 'Nota guardada con éxito', tipo: 'success');
      
    } catch (e) {
      mensajeEmergente(context, 'Error al guardar la nota: $e', tipo: 'error');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // --- LÓGICA DE ARCHIVOS MULTIMEDIA ---
  void _mostrarOpcionesMultimedia() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AgriPalette.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AgriPalette.greenMain),
              title: const Text('Hacer Foto / Grabar Vídeo'),
              onTap: () {
                Navigator.pop(context);
                _obtenerMultimedia(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AgriPalette.greenMain),
              title: const Text('Galería'),
              onTap: () {
                Navigator.pop(context);
                _obtenerMultimedia(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file, color: AgriPalette.greenMain),
              title: const Text('Adjuntar Documento / Audio'),
              onTap: () {
                Navigator.pop(context);
                _seleccionarArchivoCualquiera();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _obtenerMultimedia(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    // Permitir fotos o videos
    final XFile? media = await picker.pickMedia(); 
    if (media != null) {
      await _subirArchivoAlServidor(media.path, media.name);
    }
  }

  Future<void> _seleccionarArchivoCualquiera() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      await _subirArchivoAlServidor(result.files.single.path!, result.files.single.name);
    }
  }

  Future<void> _subirArchivoAlServidor(String filePath, String fileName) async {
    try {
      mensajeEmergente(context, 'Subiendo archivo...', tipo: 'info');
      // Subimos usando el UUID de la nota para vincularlos
      final response = await _apiService.uploadFile(
        filePath: filePath,
        kuuid: _knota,
        tipo: 'NOTA',
      );
      
      setState(() {
        _archivos.add({
          'karchivos': response['uuid'] ?? const Uuid().v4(),
          'nombrearchivo': fileName,
        });
      });
      mensajeEmergente(context, 'Archivo subido correctamente', tipo: 'success');
    } catch (e) {
      mensajeEmergente(context, 'Error al subir archivo: $e', tipo: 'error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nota == null ? 'Nueva Nota' : 'Editar Nota'),
        actions: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            color: AgriPalette.greenMain,
            onPressed: _mostrarOpcionesMultimedia,
          ),
          IconButton(
            icon: _guardando 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AgriPalette.greenMain, strokeWidth: 2))
                : const Icon(Icons.save),
            color: AgriPalette.greenMain,
            onPressed: _guardando ? null : _guardarNota,
          ),
        ],
      ),
      body: Column(
        children: [
          // CABECERA: Título
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _tituloController,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'Título (Opcional)',
                border: InputBorder.none,
              ),
            ),
          ),
          const Divider(height: 1),
          
          // CUERPO: Contenido
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _contenidoController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Empieza a escribir aquí...',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          
          // ZONA INFERIOR: Archivos adjuntos
          if (_archivos.isNotEmpty) ...[
            const Divider(height: 1),
            Container(
              color: AgriPalette.background,
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Archivos adjuntos:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _archivos.length,
                      itemBuilder: (context, index) {
                        final archivo = _archivos[index];
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AgriPalette.greenMain.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.insert_drive_file, size: 16, color: AgriPalette.greenMain),
                              const SizedBox(width: 6),
                              Text(archivo['nombrearchivo'] ?? 'Archivo', style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }
}