import 'package:agriapp/services/db_service.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/record_albaran.dart';
import '../models/record_almacen.dart';
import '../models/record_producto.dart';
import '../models/record_tipodeprecio.dart';
import '../models/record_finca.dart';
import 'package:file_picker/file_picker.dart'; 
import 'package:uuid/uuid.dart'; 
import 'package:image_picker/image_picker.dart'; 
import '../utils/ui_utils.dart';
import '../utils/app_palette.dart';
import 'dart:io'; 
import 'package:path_provider/path_provider.dart'; 

class PageAlbaran extends StatefulWidget {
  final Albaran? albaran;            
  final List<Almacen> almacenes;     
  final List<Tipodeprecio> tiposPrecio; 
  final List<Producto> productos;    
  final List<finca> fincas;          
  final List<Albaran> albaranesTotales;
  
  // --- PUNTO 1: CONFIGURACIÓN DEL DISCRIMINADOR ---
  // Añadimos este parámetro opcional. Por defecto es el UUID de ALBARÁN,
  // así cuando lo llames desde Gastos solo tendrás que pasarle el UUID de GASTO.
  final String ktipoalbaran;

  const PageAlbaran({
    Key? key,
    this.albaran,
    required this.almacenes,
    required this.tiposPrecio,
    required this.productos,
    required this.fincas,
    required this.albaranesTotales, 
    this.ktipoalbaran = "b42f149b-6744-11f0-ac9b-e2b6c6b4d8df", // Por defecto ALBARAN
  }) : super(key: key);

  @override
  State<PageAlbaran> createState() => _PageAlbaranState();
}

class _PageAlbaranState extends State<PageAlbaran> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  late DateTime _fecha;               
  String? _selectedAlmacen;           
  String? _selectedTipoPrecio;        
  String? _selectedProducto;
  
  // Variable interna que recordará el tipo de documento durante la sesión
  late String _currentTipoAlbaran;

  final TextEditingController _idAlbaranAlmacenController = TextEditingController();
  final TextEditingController _comentarioCabeceraController = TextEditingController();

  List<AlbaranDetalle> _detalles = [];
  List<Archivo> _archivos = [];

  final TextEditingController _kgController               = TextEditingController();
  final TextEditingController _palletsController        = TextEditingController();
  final TextEditingController _cajasController          = TextEditingController();
  final TextEditingController _precioController          = TextEditingController();
  final TextEditingController _comentarioDetController  = TextEditingController();
  String? _selectedFinca;

  @override
  void initState() {
    super.initState();
    
    // Asignamos el tipo de documento: Prioriza el del albarán existente (si editamos) 
    // o el que viene por el constructor (si creamos nuevo).
    _currentTipoAlbaran = widget.albaran?.ktipoalbaran ?? widget.ktipoalbaran;

    _fecha = widget.albaran?.fecha ?? DateTime.now();
    _selectedTipoPrecio = widget.albaran?.ktipodeprecio;
    _selectedAlmacen = widget.albaran?.kalmacen;

    if (widget.albaran != null) {
      _idAlbaranAlmacenController.text = widget.albaran?.idalbaranstr ?? "";
      _comentarioCabeceraController.text = widget.albaran?.comentarioStr ?? "";
      _detalles = List.from(widget.albaran!.detalles);
      _archivos = List.from(widget.albaran!.archivos); 
    } else {
      _selectedAlmacen = _obtenerUltimoAlmacenUsado();
      
      // Filtramos en caliente los productos del tipo actual para preseleccionar el primero
     // AÑADE ESTO PARA DEPURAR
    print("Tipo de Albarán Actual: $_currentTipoAlbaran");
    print("Total de productos en memoria: ${widget.productos.length}");
    for(var p in widget.productos) {
      print("- ${p.productoStr}: ${p.ktipoalbaran}");
    }

    final productosFiltrados = widget.productos
      .where((p) => p.ktipoalbaran == _currentTipoAlbaran)
      .toList();
      
    print("Productos Filtrados: ${productosFiltrados.length}");
      if (productosFiltrados.isNotEmpty) {
        _selectedProducto = productosFiltrados[0].kproducto;
      }
    }
  }

  String? _obtenerUltimoAlmacenUsado() {
    if (widget.albaranesTotales.isEmpty) return null;
    List<Albaran> temporales = List.from(widget.albaranesTotales);
    temporales.sort((a, b) => b.fecha.compareTo(a.fecha));
    
    // Buscamos el último almacén usado que coincida con el tipo de documento actual
    try {
      return temporales.firstWhere((element) => element.ktipoalbaran == _currentTipoAlbaran).kalmacen;
    } catch (_) {
      return null;
    }
  }

  Future<void> _guardarAlbaran() async {
    if (!_formKey.currentState!.validate()) return;

    final detallesActivos = _detalles.where((d) => d.eliminado == 0).toList();
    if (detallesActivos.isEmpty) {
      mensajeEmergente(context, 'Debe añadir al menos un producto.');
      return;
    }

    try {
      String kalbaranId = widget.albaran?.kalbaran ?? const Uuid().v4();

      final listaDetalles = _detalles.map((d) {
        return {
          'kalbarandetalle': d.kalbarandetalle.isEmpty ? const Uuid().v4() : d.kalbarandetalle,
          'kfinca': d.kfinca,
          'linea_int': d.linea,
          'kg_float': d.kg,
          'numeropallets_int': d.pallets,
          'numerocajas_int': d.cajas,
          'precio_flt': d.precio ?? 0.0,
          'kproducto': d.kproducto,
          'comentario_str': d.comentario ?? "",
          'eliminado_bit': d.eliminado,
          'fechaeliminacion_dtm': d.eliminado == 1 ? DateTime.now().toIso8601String() : null,
          'fecha_dtm': _fecha.toIso8601String(),
          'total_flt': (d.kg * (d.precio ?? 0.0)),
        };
      }).toList();

      final listaArchivos = _archivos.map((a) {
        return {
          'karchivos': a.karchivos,
          'kuuid': a.kuuid,
          'orden_int': a.orden,
          'fecha_dtm': a.fecha.toIso8601String(),
          'formato_str': a.formato,
          'nombrearchivo_str': a.nombrearchivo,
          'tipo_str': a.tipo,
          'eliminado_bit': a.eliminado,
          'comentario_str': a.comentario ?? "",
          'rutacompleta_str': a.rutacompleta, 
        };
      }).toList();

      final Map<String, dynamic> albaranCompleto = {
        'kalbaran': kalbaranId,
        'fecha_dtm': _fecha.toIso8601String(),
        'kalmacen': _selectedAlmacen,
        'ktipodeprecio': _selectedTipoPrecio,
        'comentario_str': _comentarioCabeceraController.text,
        'idalbaran_str': _idAlbaranAlmacenController.text, 
        
        // --- PUNTO 2: DINÁMICO AL GUARDAR ---
        'ktipoalbaran': _currentTipoAlbaran, 
        
        'eliminado_bit': 0,
        'fechaeliminacion_dtm': null, 
        'fechadesde_dtm': _fecha.toIso8601String(), 
        'fechahasta_dtm': _fecha.toIso8601String(), 
        'numcampanias_int': 1,
        'detalles': listaDetalles,
        'archivos': listaArchivos,
      };
      
      print("DOCUMENTO ENVIADO A LA COLA LOCAL: $albaranCompleto");

      DBService.instance.registrarPendiente(entidad: 'albaran', datos: albaranCompleto);

      if (detallesActivos.isNotEmpty) {
        final ultimo = detallesActivos.last;
        int iFinca = widget.fincas.indexWhere((f) => f.kfinca == ultimo.kfinca);
        if (iFinca != -1) widget.fincas.insert(0, widget.fincas.removeAt(iFinca));

        int iProd = widget.productos.indexWhere((p) => p.kproducto == ultimo.kproducto);
        if (iProd != -1) widget.productos.insert(0, widget.productos.removeAt(iProd));
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      mensajeEmergente(context, 'Guardado con éxito');

    } catch (e) {
        print("ERROR AL GUARDAR: ${e.toString()}");
        mensajeEmergente(context, 'Error al guardar: $e');
    }
  }

  void _mostrarConfirmacionGuardar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Desea guardar los cambios?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Guardar', style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
    if (confirm == true) await _guardarAlbaran();
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
            final archivosVisibles = _archivos.where((a) => a.eliminado == 0).toList();

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
                    Padding(
                      padding: const EdgeInsets.all(30),
                      child: Text(
                        'No hay archivos adjuntos',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: AgriPalette.greyMain,
                        ),
                      ),
                    ),

                  ...archivosVisibles.map((archivo) => ListTile(
                    leading: const Icon(Icons.insert_drive_file, color: AgriPalette.greenMain),
                    title: Text(
                      archivo.nombrearchivo,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    onTap: () async {
                      try {
                        await _apiService.descargarYVerArchivo(archivo.karchivos);
                      } catch (e) {
                        mensajeEmergente(context, e.toString(), tipo: 'error');
                      }
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: AgriPalette.error),
                      onPressed: () {
                        setState(() => archivo.eliminado = 1);
                        setModalState(() {});
                        mensajeEmergente(context, 'Archivo marcado para eliminar', tipo: 'warning');
                      },
                    ),
                  )),

                  if (archivosVisibles.isNotEmpty) const Divider(),
                  
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

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AgriPalette.greenMain), 
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: AgriPalette.greyMain,
        ),
      ),
      onTap: onTap,
    );
  }

  Future<void> _obtenerImagen(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 70);

    if (image != null) {
      await _procesarYSubirArchivo(image.path, image.name);
    }
  }

  Future<void> _procesarYSubirArchivo(String pathOriginal, String name) async {
    try {
      String newUuid = const Uuid().v4();
      final directory = await getApplicationDocumentsDirectory();
      final String extension = name.split('.').last;
      final String nuevoPath = '${directory.path}/$newUuid.$extension';
      
      await File(pathOriginal).copy(nuevoPath);

      if (!mounted) return;

      setState(() {
        _archivos.add(Archivo(
          karchivos: newUuid,
          kuuid: widget.albaran?.kalbaran ?? '', 
          kagricultor: widget.fincas.isNotEmpty ? widget.fincas.first.kagricultor : '',
          nombrearchivo: name,
          fecha: DateTime.now(),
          formato: extension.toUpperCase(),
          tipo: _currentTipoAlbaran == "b42f149b-6744-11f0-ac9b-e2b6c6b4d8df" ? 'ALBARAN' : 'GASTO',
          rutacompleta: nuevoPath, 
          orden: _archivos.length + 1, 
        ));
      });

      mensajeEmergente(context, 'Imagen adjuntada localmente');
    } catch (e) {
      mensajeEmergente(context, 'Error al procesar imagen: $e', tipo: 'error');
    }
  }

  Future<void> _seleccionarYSubirArchivo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.single.path != null) {
      String filePath = result.files.single.path!;
      String fileName = result.files.single.name;
      String newUuid = const Uuid().v4(); 

      try {
        final response = await _apiService.uploadFile(
          filePath: filePath,
          kuuid: newUuid,
          tipo: _currentTipoAlbaran == "b42f149b-6744-11f0-ac9b-e2b6c6b4d8df" ? 'ALBARAN' : 'GASTO',
        );

        setState(() {
          _archivos.add(Archivo(
            karchivos: response['uuid'], 
            kagricultor: '', 
            kuuid: newUuid,
            orden: _archivos.length + 1,
            fecha: DateTime.now(),
            formato: fileName.split('.').last, 
            nombrearchivo: fileName,
            tipo: _currentTipoAlbaran == "b42f149b-6744-11f0-ac9b-e2b6c6b4d8df" ? 'ALBARAN' : 'GASTO',
            rutacompleta: null,
            campo1: null,
            sizemb: null,
            comentario: null,
          ));
        });
        
        mensajeEmergente(context, 'Archivo subido con éxito');
      } catch (e) {
        mensajeEmergente(context, "Error: $e");
      }
    }
  }

  // --- PUNTO 3: FILTRADO INTELIGENTE DE PRODUCTOS EN EL DIÁLOGO ---
  void _mostrarDialogoDetalle({AlbaranDetalle? detalle}) {
    
    // Filtramos la lista de productos en caliente basándonos en el tipo de documento activo
// AÑADE ESTO PARA DEPURAR
    print("Tipo de Albarán Actual: $_currentTipoAlbaran");
    print("Total de productos en memoria: ${widget.productos.length}");
    for(var p in widget.productos) {
      print("- ${p.productoStr}: ${p.ktipoalbaran}");
    }

    final productosFiltrados = widget.productos
      .where((p) => p.ktipoalbaran == _currentTipoAlbaran)
      .toList();
      
    print("Productos Filtrados: ${productosFiltrados.length}");

    if (detalle != null) {
      _selectedFinca = detalle.kfinca;
      _selectedProducto = detalle.kproducto;
      _kgController.text = detalle.kg.toString();
      _palletsController.text = detalle.pallets.toString();
      _cajasController.text = detalle.cajas.toString();
      _precioController.text = detalle.precio?.toString() ?? '';
      _comentarioDetController.text = detalle.comentario ?? '';
    } else {
      _kgController.clear(); 
      _palletsController.clear();
      _cajasController.clear(); 
      _precioController.clear();
      _comentarioDetController.clear();

      if (widget.fincas.isNotEmpty) {
        _selectedFinca = widget.fincas[0].kfinca;
      }
      
      if (productosFiltrados.isNotEmpty) {
        _selectedProducto = productosFiltrados[0].kproducto; 
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            double ancho80 = MediaQuery.of(context).size.width * 0.9;
            return AlertDialog(
              title: Text(detalle == null ? 'Nuevo Detalle' : 'Editar Detalle'),
              content: SizedBox(
                width: ancho80, 
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedFinca,
                        decoration: const InputDecoration(labelText: 'Finca'),
                        items: widget.fincas.map((f) => DropdownMenuItem(
                          value: f.kfinca, 
                          child: Text(f.nombreStr)
                        )).toList(),
                        onChanged: (v) => setDialogState(() => _selectedFinca = v),
                      ),
                      const SizedBox(height: 10),

                      // El Dropdown consume la lista limpia según el documento
                      DropdownButtonFormField<String>(
                        value: _selectedProducto,
                        decoration: InputDecoration(
                          labelText: _currentTipoAlbaran == "b42f149b-6744-11f0-ac9b-e2b6c6b4d8df" 
                              ? 'Producto (Ingreso)' 
                              : 'Concepto (Gasto)'
                        ),
                        items: productosFiltrados.map((p) => DropdownMenuItem(
                          value: p.kproducto, 
                          child: Text(p.productoStr)
                        )).toList(),
                        onChanged: (v) => setDialogState(() => _selectedProducto = v),
                      ),

                      const SizedBox(height: 10),
                      TextField(
                        controller: _kgController, 
                        decoration: const InputDecoration(labelText: 'Kilos / Cantidad'), 
                        keyboardType: TextInputType.number
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _palletsController, 
                        decoration: const InputDecoration(labelText: 'Pallets'), 
                        keyboardType: TextInputType.number
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _cajasController, 
                        decoration: const InputDecoration(labelText: 'Cajas'), 
                        keyboardType: TextInputType.number
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _precioController, 
                        decoration: const InputDecoration(labelText: 'Precio €'), 
                        keyboardType: TextInputType.number
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _comentarioDetController, 
                        decoration: const InputDecoration(labelText: 'Comentario línea')
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: const Text('Cerrar')
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_selectedFinca == null || _selectedProducto == null) return;
                    
                    final nKg = double.tryParse(_kgController.text) ?? 0;
                    final nPal = int.tryParse(_palletsController.text) ?? 0;
                    final nCaj = int.tryParse(_cajasController.text) ?? 0;
                    final nPre = double.tryParse(_precioController.text);

                    if (detalle == null) {
                      _detalles.add(AlbaranDetalle(
                        kalbarandetalle: '',
                        kalbaran: widget.albaran?.kalbaran ?? '',
                        kfinca: _selectedFinca!,
                        linea: _detalles.length + 1,
                        kg: nKg, 
                        pallets: nPal, 
                        cajas: nCaj, 
                        precio: nPre,
                        kproducto: _selectedProducto!,
                        comentario: _comentarioDetController.text,
                        eliminado: 0,
                        kagricultor: widget.fincas.firstWhere((f) => f.kfinca == _selectedFinca).kagricultor,
                      ));
                    } else {
                      detalle.kfinca = _selectedFinca!;
                      detalle.kproducto = _selectedProducto!;
                      detalle.kg = nKg; 
                      detalle.pallets = nPal;
                      detalle.cajas = nCaj; 
                      detalle.precio = nPre;
                      detalle.comentario = _comentarioDetController.text;
                    }
                    
                    setState(() {});
                    Navigator.pop(context);
                  },
                  child: Text(
                    detalle == null ? 'Añadir' : 'Actualizar', 
                    style: const TextStyle(color: Colors.white)
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- PUNTO 4: FILTRADO INTELIGENTE DE ALMACENES EN EL BUILD ---
    final List<Almacen> almacenesFiltrados = widget.almacenes
        .where((a) => a.ktipoalbaran == _currentTipoAlbaran)
        .toList();

    if (_selectedAlmacen != null && !almacenesFiltrados.any((a) => a.kalmacen == _selectedAlmacen)) {
      _selectedAlmacen = null;
    }
    
    final visibleItems = _detalles.where((d) => d.eliminado == 0).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTipoAlbaran == "b42f149b-6744-11f0-ac9b-e2b6c6b4d8df" 
            ? (widget.albaran == null ? 'Nuevo Albarán' : 'Editar Albarán')
            : (widget.albaran == null ? 'Nuevo Gasto' : 'Editar Gasto')),
        actions: [
          IconButton(icon: const Icon(Icons.attach_file), color: AgriPalette.greenMain, onPressed: _mostrarOAnadirArchivos),
          IconButton(icon: const Icon(Icons.save), color: AgriPalette.greenMain, onPressed: _mostrarConfirmacionGuardar)
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    ListTile(
                        title: Text(
                          'Fecha: ${_fecha.day.toString().padLeft(2, '0')}/${_fecha.month.toString().padLeft(2, '0')}/${_fecha.year}'
                        ),
                      trailing: const Icon(Icons.calendar_today, color: AgriPalette.greenMain),
                      onTap: () async {
                        final p = await showDatePicker(context: context, initialDate: _fecha, firstDate: DateTime(2020), lastDate: DateTime(2100));
                        if (p != null) setState(() => _fecha = p);
                      },
                    ),
                    DropdownButtonFormField<String>(
                      value: _selectedAlmacen,
                      decoration: InputDecoration(
                        labelText: _currentTipoAlbaran == "b42f149b-6744-11f0-ac9b-e2b6c6b4d8df" 
                            ? 'Almacén de Destino' 
                            : 'Proveedor / Acreedor'
                      ),
                      items: almacenesFiltrados.map((a) => DropdownMenuItem(
                        value: a.kalmacen, 
                        child: Text(a.nombreStr)
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedAlmacen = v),
                      validator: (v) => v == null ? 'Seleccione entidad' : null,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _idAlbaranAlmacenController,
                      decoration: InputDecoration(
                        labelText: _currentTipoAlbaran == "b42f149b-6744-11f0-ac9b-e2b6c6b4d8df" 
                            ? 'Nº Albarán Almacén' 
                            : 'Nº Factura / Justificante'
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _comentarioCabeceraController,
                      decoration: const InputDecoration(labelText: 'Notas Generales'),
                    ),
                    const Divider(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _currentTipoAlbaran == "b42f149b-6744-11f0-ac9b-e2b6c6b4d8df" ? 'PRODUCTOS' : 'CONCEPTOS DE GASTO', 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                        ),
                        IconButton(icon: const Icon(Icons.add_circle), color: AgriPalette.greenMain, iconSize: 32, onPressed: () => _mostrarDialogoDetalle()),
                      ],
                    ),
                    ...visibleItems.map((d) {
                      final prod = widget.productos.firstWhere(
                          (p) => p.kproducto == d.kproducto, 
                          orElse: () => Producto(
                            kproducto: '', 
                            productoStr: '?', 
                            fecha: DateTime.now(),
                            ktipoalbaran: _currentTipoAlbaran,
                          ),
                        );
                      return Card(
                        child: ListTile(
                          title: Text('${prod.productoStr} - ${d.kg} unidades'),
                          subtitle: Text('Pallets: ${d.pallets} | Cajas: ${d.cajas}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit), color: AgriPalette.greenMain, onPressed: () => _mostrarDialogoDetalle(detalle: d)),
                              IconButton(
                                icon: const Icon(Icons.delete), 
                                color: AgriPalette.greenMain, 
                                onPressed: () => setState(() {
                                  if (d.kalbarandetalle.isEmpty) {
                                    _detalles.remove(d);
                                  } else {
                                    d.eliminado = 1;
                                  }
                                }),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}