//page_nota.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../models/record_usuario.dart';
import '../services/api_service.dart';
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
  bool _editando = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();

    if (widget.nota != null) {
      _esNueva = false;
      _editando = false;
      final n = widget.nota!;

      _knota = n['knota'] ?? const Uuid().v4();
      _tituloController.text = n['titulo_str'] ?? '';
      _contenidoController.text = n['nota_str'] ?? '';

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
      _editando = true;
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
    setState(() => _guardando = true);
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
        'nota_str': _contenidoController.text.trim(),
        'fecha_dtm': _fecha.toIso8601String(),
        'eliminado_bit': 0,
      };

      if (_esNueva) {
        await _apiService.postGeneric('tblnota', notaCompleta);
      } else {
        await _apiService.putGeneric('tblnota', _knota, notaCompleta);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      mensajeEmergente(context, 'Nota guardada', tipo: 'success');
    } catch (e) {
      mensajeEmergente(context, 'Error al guardar: $e', tipo: 'error');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _abrirArchivo(dynamic karchivo) async {
    if (karchivo != null) {
      try {
        await _apiService.descargarYVerArchivo(karchivo);
      } catch (e) {
        mensajeEmergente(context, 'Error al abrir el archivo: $e', tipo: 'error');
      }
    } else {
      mensajeEmergente(context, 'Archivo no sincronizado aún');
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
                    'Archivos Adjuntos (${archivosVisibles.length})',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AgriPalette.greyMain),
                  ),
                  const SizedBox(height: 8),
                  Divider(color: AgriPalette.greyMain.withValues(alpha: 0.2)),
                  if (archivosVisibles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(30),
                      child: Text('No hay archivos adjuntos',
                          style: TextStyle(fontStyle: FontStyle.italic, color: AgriPalette.greyMain)),
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
                            onTap: () => _abrirArchivo(archivo['karchivos']),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: AgriPalette.error),
                              onPressed: () async {
                                try {
                                  await _apiService.deleteGeneric('tblArchivos', archivo['karchivos']);
                                  setState(() {
                                    archivo['eliminado_bit'] = 1;
                                  });
                                  setModalState(() {});
                                  mensajeEmergente(context, 'Archivo eliminado', tipo: 'warning');
                                } catch (e) {
                                  mensajeEmergente(context, 'Error al borrar archivo', tipo: 'error');
                                }
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

  Widget _buildActionTile(
      {required BuildContext context,
      required IconData icon,
      required String label,
      required VoidCallback onTap}) {
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
      mensajeEmergente(context, 'Subiendo archivo...', tipo: 'info');
      final response = await _apiService.uploadFile(
        filePath: pathOriginal,
        kuuid: _knota,
        tipo: 'NOTA',
      );

      if (!mounted) return;

      setState(() {
        _archivos.add({
          'karchivos': response['uuid'] ?? const Uuid().v4(),
          'kuuid': _knota,
          'nombrearchivo_str': name,
          'localPath': pathOriginal,
          'fecha_dtm': DateTime.now().toIso8601String(),
          'formato_str': name.split('.').last.toUpperCase(),
          'tipo_str': 'NOTA',
          'eliminado_bit': 0,
        });
      });

      mensajeEmergente(context, 'Archivo guardado correctamente', tipo: 'success');
    } catch (e) {
      mensajeEmergente(context, 'Error al procesar archivo: $e', tipo: 'error');
    }
  }

  Widget _buildInlineArchivos(List<Map<String, dynamic>> archivos) {
    if (archivos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Divider(color: AgriPalette.greyMain.withValues(alpha: 0.2)),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.attach_file, size: 20, color: AgriPalette.greenMain),
            const SizedBox(width: 8),
            Text(
              'Archivos Adjuntos (${archivos.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AgriPalette.greyMain,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: archivos.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _buildArchivoInlineItem(archivos[index]);
          },
        ),
      ],
    );
  }

  Widget _buildArchivoInlineItem(Map<String, dynamic> archivo) {
    final String nombre = archivo['nombrearchivo_str'] ?? archivo['nombrearchivo'] ?? 'Archivo';
    final String formato = (archivo['formato_str'] ?? nombre.split('.').last ?? '').toString().toUpperCase();
    final String? localPath = archivo['localPath'];
    final dynamic karchivo = archivo['karchivos'];

    final bool esImagen = ['JPG', 'JPEG', 'PNG', 'GIF', 'WEBP'].contains(formato);
    final bool esPdf = formato == 'PDF';

    if (esImagen) {
      return _ImagenAdjuntaInlineWidget(
        nombre: nombre,
        localPath: localPath,
        karchivo: karchivo,
        onTapAbrir: () => _abrirArchivo(karchivo),
      );
    } else if (esPdf) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
          color: Colors.red.shade50.withValues(alpha: 0.4),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  const Text('Documento PDF', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: AgriPalette.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text('Ver PDF', style: TextStyle(fontSize: 12)),
              onPressed: () => _abrirArchivo(karchivo),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AgriPalette.greyMain.withValues(alpha: 0.2)),
          color: AgriPalette.white,
        ),
        child: Row(
          children: [
            const Icon(Icons.insert_drive_file, color: AgriPalette.greenMain, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                nombre,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.download, color: AgriPalette.greenMain),
              onPressed: () => _abrirArchivo(karchivo),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final archivosVisibles = _archivos.where((a) => a['eliminado_bit'] != 1).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_esNueva ? 'Nueva Nota' : (_editando ? 'Editar Nota' : 'Nota')),
        actions: [
          Badge(
            isLabelVisible: archivosVisibles.isNotEmpty,
            label: Text('${archivosVisibles.length}'),
            backgroundColor: AgriPalette.greenMain,
            child: IconButton(
              icon: const Icon(Icons.attach_file),
              color: AgriPalette.greenMain,
              tooltip: 'Archivos adjuntos',
              onPressed: _mostrarOAnadirArchivos,
            ),
          ),
          const SizedBox(width: 8),
          if (!_editando)
            IconButton(
              icon: const Icon(Icons.edit),
              color: AgriPalette.greenMain,
              tooltip: 'Editar nota',
              onPressed: () {
                setState(() {
                  _editando = true;
                });
              },
            )
          else
            IconButton(
              icon: _guardando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: AgriPalette.greenMain, strokeWidth: 2))
                  : const Icon(Icons.save),
              color: AgriPalette.greenMain,
              tooltip: 'Guardar nota',
              onPressed: _guardando ? null : _guardarNota,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_editando) ...[
                Text(
                  _tituloController.text.trim().isEmpty
                      ? 'Sin título'
                      : _tituloController.text.trim(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AgriPalette.greyMain,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_fecha.day.toString().padLeft(2, '0')}/${_fecha.month.toString().padLeft(2, '0')}/${_fecha.year} ${_fecha.hour.toString().padLeft(2, '0')}:${_fecha.minute.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AgriPalette.greyMain.withValues(alpha: 0.6),
                      ),
                ),
                const SizedBox(height: 16),
                SelectableText(
                  _contenidoController.text.trim().isEmpty
                      ? 'Nota sin contenido.'
                      : _contenidoController.text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 16,
                        height: 1.5,
                        color: AgriPalette.greyMain,
                      ),
                ),
              ] else ...[
                TextFormField(
                  controller: _tituloController,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: 'Título (Opcional)',
                    filled: true,
                    fillColor: AgriPalette.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AgriPalette.greyMain.withValues(alpha: 0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AgriPalette.greyMain.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AgriPalette.greenMain, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  maxLines: 1,
                ),
                const SizedBox(height: 10),
                Text(
                  '${_fecha.day.toString().padLeft(2, '0')}/${_fecha.month.toString().padLeft(2, '0')}/${_fecha.year} ${_fecha.hour.toString().padLeft(2, '0')}:${_fecha.minute.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AgriPalette.greyMain),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _contenidoController,
                  minLines: 8,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    hintText: 'Empieza a escribir aquí...',
                    filled: true,
                    fillColor: AgriPalette.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AgriPalette.greyMain.withValues(alpha: 0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AgriPalette.greyMain.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AgriPalette.greenMain, width: 2),
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
              ],

              _buildInlineArchivos(archivosVisibles),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagenAdjuntaInlineWidget extends StatefulWidget {
  final String nombre;
  final String? localPath;
  final dynamic karchivo;
  final VoidCallback onTapAbrir;

  const _ImagenAdjuntaInlineWidget({
    Key? key,
    required this.nombre,
    this.localPath,
    required this.karchivo,
    required this.onTapAbrir,
  }) : super(key: key);

  @override
  State<_ImagenAdjuntaInlineWidget> createState() => _ImagenAdjuntaInlineWidgetState();
}

class _ImagenAdjuntaInlineWidgetState extends State<_ImagenAdjuntaInlineWidget> {
  Uint8List? _bytes;
  bool _cargando = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    if ((widget.localPath == null || !File(widget.localPath!).existsSync()) && widget.karchivo != null) {
      _cargarImagenServidor();
    }
  }

  Future<void> _cargarImagenServidor() async {
    setState(() {
      _cargando = true;
      _error = false;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token != null) {
        final headers = {'Authorization': 'Bearer $token'};
        final urls = [
          'https://api.bueso.duckdns.org/api/gastos/descargararchivonas/${widget.karchivo}',
          'https://api.bueso.duckdns.org/api/descargararchivonas/${widget.karchivo}',
          'https://api.bueso.duckdns.org/api/archivos/${widget.karchivo}',
        ];

        for (final urlStr in urls) {
          final response = await http.get(Uri.parse(urlStr), headers: headers);
          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            if (mounted) {
              setState(() {
                _bytes = response.bodyBytes;
                _cargando = false;
              });
            }
            return;
          }
        }
      }
    } catch (e) {
      print("Error descargando imagen adjunta: $e");
    }

    if (mounted) {
      setState(() {
        _cargando = false;
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool tieneArchivoLocal = widget.localPath != null && File(widget.localPath!).existsSync();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AgriPalette.greyMain.withValues(alpha: 0.2)),
        color: AgriPalette.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tieneArchivoLocal)
            GestureDetector(
              onTap: widget.onTapAbrir,
              child: Image.file(
                File(widget.localPath!),
                width: double.infinity,
                //maxHeight: 280,
                fit: BoxFit.cover,
              ),
            )
          else if (_bytes != null)
            GestureDetector(
              onTap: widget.onTapAbrir,
              child: Image.memory(
                _bytes!,
                width: double.infinity,
                //maxHeight: 280,
                fit: BoxFit.cover,
              ),
            )
          else if (_cargando)
            Container(
              height: 180,
              width: double.infinity,
              color: AgriPalette.greenMain.withValues(alpha: 0.05),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AgriPalette.greenMain),
                ),
              ),
            )
          else
            InkWell(
              onTap: widget.onTapAbrir,
              child: Container(
                height: 160,
                width: double.infinity,
                color: AgriPalette.greenMain.withValues(alpha: 0.05),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.image_not_supported, size: 44, color: AgriPalette.greyMain),
                    const SizedBox(height: 8),
                    Text(
                      _error ? 'Toca para intentar abrir imagen' : 'Toca para abrir imagen',
                      style: const TextStyle(
                        color: AgriPalette.greenMain,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.nombre,
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new, size: 20, color: AgriPalette.greenMain),
                  onPressed: widget.onTapAbrir,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}