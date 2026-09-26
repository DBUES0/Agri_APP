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
  final String ktipoalbaran;

  const PageAlbaran({
    Key? key,
    this.albaran,
    required this.almacenes,
    required this.tiposPrecio,
    required this.productos,
    required this.fincas,
    required this.albaranesTotales, 
    this.ktipoalbaran = "b42f149b-6744-11f0-ac9b-e2b6c6b4d8df", // Por defecto ALBARAN (Ingreso)
  }) : super(key: key);

  @override
  State<PageAlbaran> createState() => _PageAlbaranState();
}

class _PageAlbaranState extends State<PageAlbaran> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  static const String _uuidGasto = "c4755f6d-6744-11f0-ac9b-e2b6c6b4d8df";
  static const String _kProductoGenericoGasto = "f84a0c63-e757-49e6-87c5-3097cdfd813a";

  late DateTime _fecha;                
  String? _selectedAlmacen;            
  String? _selectedTipoPrecio;        
  String? _selectedProducto;
  
  late String _currentTipoAlbaran;

  final TextEditingController _idAlbaranAlmacenController = TextEditingController();
  final TextEditingController _comentarioCabeceraController = TextEditingController();
  final TextEditingController _totalCabeceraController = TextEditingController(); // CAMPO NUEVO

  List<AlbaranDetalle> _detalles = [];
  List<Archivo> _archivos = [];

  final TextEditingController _kgController              = TextEditingController();
  final TextEditingController _palletsController         = TextEditingController();
  final TextEditingController _cajasController           = TextEditingController();
  final TextEditingController _precioController          = TextEditingController();
  final TextEditingController _comentarioDetController   = TextEditingController();
  String? _selectedFinca;

  bool get _esGasto => _currentTipoAlbaran == _uuidGasto;

  @override
  void initState() {
    super.initState();
    
    _currentTipoAlbaran = widget.albaran?.ktipoalbaran ?? widget.ktipoalbaran;
    _fecha = widget.albaran?.fecha ?? DateTime.now();
    _selectedTipoPrecio = widget.albaran?.ktipodeprecio;
    _selectedAlmacen = widget.albaran?.kalmacen;

    if (widget.albaran != null) {
      _idAlbaranAlmacenController.text = widget.albaran?.idalbaranstr ?? "";
      _comentarioCabeceraController.text = widget.albaran?.comentarioStr ?? "";
      _detalles = List.from(widget.albaran!.detalles);
      _archivos = List.from(widget.albaran!.archivos);

      // Si es un gasto y tiene exactamente una línea genérica, precargamos el total rápido
      if (_esGasto && _detalles.length == 1 && _detalles.first.kproducto == _kProductoGenericoGasto) {
        final d = _detalles.first;
        if (d.precio != null && d.precio! > 0) {
          _totalCabeceraController.text = d.precio!.toStringAsFixed(2);
        }
      }
    } else {
      _selectedAlmacen = _obtenerUltimoAlmacenUsado();
      
      final productosFiltrados = widget.productos
        .where((p) => p.ktipoalbaran == _currentTipoAlbaran)
        .toList();
        
      if (productosFiltrados.isNotEmpty) {
        _selectedProducto = productosFiltrados[0].kproducto;
      }
    }
  }

  @override
  void dispose() {
    _idAlbaranAlmacenController.dispose();
    _comentarioCabeceraController.dispose();
    _totalCabeceraController.dispose();
    _kgController.dispose();
    _palletsController.dispose();
    _cajasController.dispose();
    _precioController.dispose();
    _comentarioDetController.dispose();
    super.dispose();
  }

  String? _obtenerUltimoAlmacenUsado() {
    if (widget.albaranesTotales.isEmpty) return null;
    List<Albaran> temporales = List.from(widget.albaranesTotales);
    temporales.sort((a, b) => b.fecha.compareTo(a.fecha));
    
    try {
      return temporales.firstWhere((element) => element.ktipoalbaran == _currentTipoAlbaran).kalmacen;
    } catch (_) {
      return null;
    }
  }

  Future<void> _guardarAlbaran() async {
    if (!_formKey.currentState!.validate()) return;

    List<AlbaranDetalle> detallesActivos = _detalles.where((d) => d.eliminado == 0).toList();
    final double? totalRapido = double.tryParse(_totalCabeceraController.text.replaceAll(',', '.'));

    // LÓGICA DE GUARDADO AUTOMÁTICO PARA GASTOS SIN LÍNEAS
    if (detallesActivos.isEmpty && _esGasto && totalRapido != null && totalRapido > 0) {
      if (widget.fincas.isEmpty) {
        mensajeEmergente(context, 'No se puede guardar el gasto porque no hay ninguna finca registrada.', tipo: 'error');
        return;
      }

      final fincaDefecto = widget.fincas.first;

      final lineaGenerica = AlbaranDetalle(
        kalbarandetalle: const Uuid().v4(),
        kalbaran: widget.albaran?.kalbaran ?? '',
        kfinca: fincaDefecto.kfinca,
        linea: 1,
        kg: 1.0, // 1 Unidad por defecto
        pallets: 0,
        cajas: 0,
        precio: totalRapido,
        kproducto: _kProductoGenericoGasto,
        comentario: _comentarioCabeceraController.text.trim(),
        eliminado: 0,
        kagricultor: fincaDefecto.kagricultor,
      );

      _detalles.add(lineaGenerica);
      detallesActivos = [lineaGenerica];
    }

    if (detallesActivos.isEmpty) {
      mensajeEmergente(context, _esGasto 
        ? 'Indique un importe total en cabecera o añada al menos una línea de gasto.'
        : 'Debe añadir al menos un producto.');
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
        'ktipoalbaran': _currentTipoAlbaran, 
        'eliminado_bit': 0,
        'fechaeliminacion_dtm': null, 
        'fechadesde_dtm': _fecha.toIso8601String(), 
        'fechahasta_dtm': _fecha.toIso8601String(), 
        'numcampanias_int': 1,
        'detalles': listaDetalles,
        'archivos': listaArchivos,
      };

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
          tipo: _esGasto ? 'GASTO' : 'ALBARAN',
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
          tipo: _esGasto ? 'GASTO' : 'ALBARAN',
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
            tipo: _esGasto ? 'GASTO' : 'ALBARAN',
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

  void _mostrarDialogoDetalle({AlbaranDetalle? detalle}) {
    final productosFiltrados = widget.productos
      .where((p) => p.ktipoalbaran == _currentTipoAlbaran)
      .toList();

    if (detalle != null) {
      _selectedFinca = detalle.kfinca;
      _selectedProducto = detalle.kproducto;
      _kgController.text = detalle.kg.toString();
      _palletsController.text = detalle.pallets.toString();
      _cajasController.text = detalle.cajas.toString();
      _precioController.text = detalle.precio?.toString() ?? '';
      _comentarioDetController.text = detalle.comentario ?? '';
    } else {
      // VALOR POR DEFECTO PARA GASTOS: Cantidad a 1
      _kgController.text = _esGasto ? '1' : ''; 
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

    if (_selectedFinca != null && !widget.fincas.any((f) => f.kfinca == _selectedFinca)) {
      _selectedFinca = null;
    }
    if (_selectedProducto != null && !productosFiltrados.any((p) => p.kproducto == _selectedProducto)) {
      _selectedProducto = null;
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

                      DropdownButtonFormField<String>(
                        value: _selectedProducto,
                        decoration: InputDecoration(
                          labelText: !_esGasto 
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
                        decoration: InputDecoration(labelText: _esGasto ? 'Cantidad / Unidades' : 'Kilos / Cantidad'), 
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      
                      if (!_esGasto) ...[
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
                      ],

                      const SizedBox(height: 10),
                      TextField(
                        controller: _precioController, 
                        decoration: InputDecoration(labelText: _esGasto ? 'Importe (€)' : 'Precio €/kg'), 
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                    
                    final nKg = double.tryParse(_kgController.text.replaceAll(',', '.')) ?? 0;
                    final nPal = int.tryParse(_palletsController.text) ?? 0;
                    final nCaj = int.tryParse(_cajasController.text) ?? 0;
                    final nPre = double.tryParse(_precioController.text.replaceAll(',', '.'));

                    setState(() {
                      // Vaciamos el total de cabecera si insertamos algo a mano
                      if (_esGasto) {
                        _totalCabeceraController.clear();
                      }

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
                    });

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
    final List<Almacen> almacenesFiltrados = widget.almacenes
        .where((a) => a.ktipoalbaran == _currentTipoAlbaran)
        .toList();

    if (_selectedAlmacen != null && !almacenesFiltrados.any((a) => a.kalmacen == _selectedAlmacen)) {
      _selectedAlmacen = null;
    }
    
    final visibleItems = _detalles.where((d) => d.eliminado == 0).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(!_esGasto 
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
                        labelText: !_esGasto 
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
                        labelText: !_esGasto 
                            ? 'Nº Albarán Almacén' 
                            : 'Nº Factura / Justificante'
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _comentarioCabeceraController,
                      decoration: const InputDecoration(labelText: 'Notas Generales'),
                    ),

                    // --- CAMPO NUEVO: TOTAL (€) SOLO PARA GASTOS ---
                    if (_esGasto) ...[
                      const SizedBox(height: 20),
                      TextField(
                        controller: _totalCabeceraController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Total Gasto (€) - Sin desglose de líneas',
                          hintText: 'Ej. 150.50',
                          prefixIcon: const Icon(Icons.euro, color: AgriPalette.greenMain),
                          helperText: visibleItems.isNotEmpty
                              ? 'Si escribe aquí, se descartarán las líneas manuales al guardar.'
                              : 'Si rellena este importe, se creará una línea genérica automáticamente.',
                        ),
                        onChanged: (valor) {
                          if (valor.trim().isNotEmpty && visibleItems.isNotEmpty) {
                            setState(() {
                              for (var d in _detalles) {
                                d.eliminado = 1;
                              }
                            });
                          }
                        },
                      ),
                    ],

                    const Divider(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          !_esGasto ? 'PRODUCTOS' : 'CONCEPTOS DE GASTO', 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle), 
                          color: AgriPalette.greenMain, 
                          iconSize: 32, 
                          onPressed: () => _mostrarDialogoDetalle()
                        ),
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
                          title: Text('${prod.productoStr} - ${d.kg} ${_esGasto ? 'ud' : 'kg'}'),
                          subtitle: Text(!_esGasto 
                              ? 'Pallets: ${d.pallets} | Cajas: ${d.cajas}'
                              : 'Importe: ${d.precio ?? 0.0} €'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit), 
                                color: AgriPalette.greenMain, 
                                onPressed: () => _mostrarDialogoDetalle(detalle: d)
                              ),
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