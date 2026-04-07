import 'package:agriapp/services/db_service.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/record_albaran.dart';
import '../models/record_almacen.dart';
import '../models/record_producto.dart';
import '../models/record_tipodeprecio.dart';
import '../models/record_finca.dart';
import 'package:file_picker/file_picker.dart'; // Necesitas añadir esto al pubspec.yaml
import 'package:uuid/uuid.dart'; // Importa la librería
import 'package:image_picker/image_picker.dart'; // Para tomar fotos con la cámara o elegir de la galería
import '../utils/ui_utils.dart';
import '../utils/app_palette.dart';



/// [PageAlbaran] es una pantalla de tipo 'StatefulWidget'. 
/// Esto significa que es una página que puede cambiar lo que muestra (dinámica),
/// por ejemplo, al añadir una línea a la lista de productos.
class PageAlbaran extends StatefulWidget {
  // Estos son los datos que la página RECIBE de la pantalla anterior.
  final Albaran? albaran;            // Si viene un albarán, estamos EDITANDO. Si es null, estamos CREANDO uno nuevo.
  final List<Almacen> almacenes;     // Lista para llenar el desplegable de almacenes.
  final List<Tipodeprecio> tiposPrecio; // Lista para el desplegable de tipos de precio.
  final List<Producto> productos;    // Lista de productos disponibles.
  final List<finca> fincas;          // Lista de fincas del agricultor.
  // Añadimos la lista de albaranes totales para poder buscar el último usado
  final List<Albaran> albaranesTotales;

const PageAlbaran({
    Key? key,
    this.albaran,
    required this.almacenes,
    required this.tiposPrecio,
    required this.productos,
    required this.fincas,
    required this.albaranesTotales, // Lo requerimos desde el Dashboard
  }) : super(key: key);

  @override
  State<PageAlbaran> createState() => _PageAlbaranState();
}

/// Esta clase [_PageAlbaranState] es donde reside toda la lógica y los datos temporales de la página.
class _PageAlbaranState extends State<PageAlbaran> {
  // El '_formKey' es como un "carnet de identidad" para el formulario. 
  // Nos permite preguntar: "¿Están todos los campos obligatorios rellenos?"
  final _formKey = GlobalKey<FormState>();
  
  // Instancia de nuestro motor de conexión con el servidor PHP.
  final ApiService _apiService = ApiService();

  // Color principal que elegiste para que los botones de 'Añadir' y 'Borrar' sean iguales.
  static const Color colorAccion = Colors.green; 

  // Variables que guardan lo que el usuario va eligiendo en la pantalla.
  late DateTime _fecha;               // Fecha seleccionada.
  String? _selectedAlmacen;           // ID del almacén elegido.
  String? _selectedTipoPrecio;        // ID del tipo de precio elegido.
  String? _selectedProducto;
  

  // Los 'TextEditingController' son "mandos a distancia" para los cuadros de texto.
  // Nos permiten leer lo que el usuario escribió o borrar el contenido desde el código.
  final TextEditingController _idAlbaranAlmacenController = TextEditingController();
  final TextEditingController _comentarioCabeceraController = TextEditingController();

  // Esta es la lista "en memoria" de los renglones (detalles) del albarán.
  List<AlbaranDetalle> _detalles = [];

  List<Archivo> _archivos = [];
  
  // UUID que identifica a los almacenes de tipo "ALBARÁN"
  static const String uuidTipoAlbaran = "b42f149b-6744-11f0-ac9b-e2b6c6b4d8df";

  // Controladores específicos para los textos que aparecen dentro del cuadro de diálogo (Pop-up) de añadir producto.
  final TextEditingController _kgController             = TextEditingController();
  final TextEditingController _palletsController        = TextEditingController();
  final TextEditingController _cajasController          = TextEditingController();
  final TextEditingController _precioController         = TextEditingController();
  final TextEditingController _comentarioDetController  = TextEditingController();
  //String? _selectedProducto;
  String? _selectedFinca;

  /// [initState] es lo primero que se ejecuta al abrir la página. 
  /// Sirve para preparar los datos iniciales.
  @override
  void initState() {
    super.initState();
    // Si 'widget.albaran' tiene datos, significa que venimos a EDITAR. 
    // Por tanto, rellenamos las variables con la información que ya existe en la base de datos.
    // La interrogación simple (?) se usa para decirle a Flutter: "Si este objeto es nulo, no intentes leer lo que hay dentro, simplemente detente y devuelve nulo".
    _fecha = widget.albaran?.fecha ?? DateTime.now();
    _selectedTipoPrecio = widget.albaran?.ktipodeprecio;
    _selectedAlmacen = widget.albaran?.kalmacen;

    if (widget.albaran != null) {
      _idAlbaranAlmacenController.text = widget.albaran?.idalbaranstr ?? "";
      _comentarioCabeceraController.text = widget.albaran?.comentarioStr ?? "";
      // Copiamos los detalles existentes a nuestra lista local.
      //Cuando pones una exclamación después de una variable, le estás diciendo a Flutter:
      //"Sé que esta variable parece que podría estar vacía, pero te garantizo que en este momento tiene datos. No te preocupes, ignora las advertencias de seguridad y sigue adelante".
      _detalles = List.from(widget.albaran!.detalles);
      // --- MOVIDO AQUÍ PARA EVITAR ERRORES ---
      _archivos = List.from(widget.albaran!.archivos); 
      // ---------------------------------------
    } else {
      // 2. LÓGICA DE ALMACÉN POR DEFECTO (El último usado)
      _selectedAlmacen = _obtenerUltimoAlmacenUsado();
      
      // 3. SELECCIONAR EL PRIMER PRODUCTO POR DEFECTO
      // Comprobamos que la lista no esté vacía para evitar errores
      if (widget.productos.isNotEmpty) {
        // Asignamos el ID (String) del primer producto de la lista
        _selectedProducto = widget.productos[0].kproducto;
      }
    }
  }

String? _obtenerUltimoAlmacenUsado() {
    if (widget.albaranesTotales.isEmpty) return null;

    // Ordenamos por fecha para asegurar que el primero es el más reciente
    List<Albaran> temporales = List.from(widget.albaranesTotales);
    temporales.sort((a, b) => b.fecha.compareTo(a.fecha));

    // El ID del almacén de tipo ALBARÁN del último registro
    return temporales.first.kalmacen;
  }


Future<void> _guardarAlbaran() async {
    if (!_formKey.currentState!.validate()) return;

    // Validación: No permitir albaranes sin productos visibles
    final detallesActivos = _detalles.where((d) => d.eliminado == 0).toList();
    if (detallesActivos.isEmpty) {
      mensajeEmergente(context, 'Debe añadir al menos un producto.');
      return;
    }

    try {
      // 1. Generar un UUID para el albarán si es nuevo
      String kalbaranId = widget.albaran?.kalbaran ?? const Uuid().v4();

      // 2. Mapear los DETALLES al formato que espera el PHP
      // Incluimos tanto los nuevos como los marcados para eliminar
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

      // 3. Mapear los ARCHIVOS al formato del PHP
      final listaArchivos = _archivos.map((a) {
        return {
          'karchivos': a.karchivos,
          'kuuid': a.kuuid,
          'orden_int': a.orden,
          'fecha_dtm': a.fecha.toIso8601String(),
          'formato_str': a.formato,
          'nombrearchivo_str': a.nombrearchivo,
          'tipo_str': a.tipo,
          'eliminado_bit': a.eliminado,           // Enviamos la fecha de eliminación si el bit es 1
          'comentario_str': a.comentario ?? "",
        };
      }).toList();

      // 4. Crear el objeto ALBARÁN completo (Cabecera + Hijos)
      // En page_albaran.dart, dentro de _guardarAlbaran()
      final Map<String, dynamic> albaranCompleto = {
        'kalbaran': kalbaranId,
        'fecha_dtm': _fecha.toIso8601String(),
        'kalmacen': _selectedAlmacen,
        'ktipodeprecio': _selectedTipoPrecio,
        'comentario_str': _comentarioCabeceraController.text,
        'idalbaran_str': _idAlbaranAlmacenController.text, // Asegúrate de incluirlo
        'ktipoalbaran': "b42f149b-6744-11f0-ac9b-e2b6c6b4d8df",
        'eliminado_bit': 0,
        'fechaeliminacion_dtm': null, // Este sí puede ser null si eliminado_bit es 0
        'fechadesde_dtm': _fecha.toIso8601String(), // Asegúrate de no enviar null
        'fechahasta_dtm': _fecha.toIso8601String(), // Asegúrate de no enviar null
        'numcampanias_int': 1,
        'detalles': listaDetalles,
        'archivos': listaArchivos,
      };
      
      print("ALBARÁN COMPLETO ENVIADO AL SERVIDOR: ${albaranCompleto.toString()}");

      // 5. Llamada única al servidor
      //await _apiService.mergeAlbaran(albaranCompleto);
      DBService.instance.registrarPendiente(entidad: 'albaran', datos: albaranCompleto);

      // --- LÓGICA DE REORDENACIÓN EN MEMORIA ---
      if (detallesActivos.isNotEmpty) {
        final ultimo = detallesActivos.last;
        
        int iFinca = widget.fincas.indexWhere((f) => f.kfinca == ultimo.kfinca);
        if (iFinca != -1) widget.fincas.insert(0, widget.fincas.removeAt(iFinca));

        int iProd = widget.productos.indexWhere((p) => p.kproducto == ultimo.kproducto);
        if (iProd != -1) widget.productos.insert(0, widget.productos.removeAt(iProd));
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      mensajeEmergente(context, 'Albarán guardado con éxito');

    } catch (e) {
        print("ERROR CRUDO DEL SERVIDOR desde page_albaran.dart: ${e.toString()}");
        mensajeEmergente(context, 'Error al guardar: $e');
    }
  }



  /// Función de apoyo para modificar un renglón que ya existía.
  // Future<void> _editarDetalleEnServidor(AlbaranDetalle d) async {
  //   final body = {
  //     'kfinca': d.kfinca,
  //     'kg_float': d.kg,
  //     'numeropallets_int': d.pallets,
  //     'numerocajas_int': d.cajas,
  //     'precio_flt': d.precio,
  //     'kproducto': d.kproducto,
  //     'comentario_str': d.comentario,
  //   };
  //   await _apiService.putGeneric('tblalbarandetalle', d.kalbarandetalle, body);
  // }

  /// Muestra una ventana de confirmación antes de guardar.
  void _mostrarConfirmacionGuardar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Desea guardar el albarán?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
           // style: ElevatedButton.styleFrom(backgroundColor: colorAccion),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Guardar', style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
    // Si el usuario pulsó 'Sí', llamamos a la función de guardado real.
    if (confirm == true) await _guardarAlbaran();
  }

Future<void> _mostrarOAnadirArchivos() async {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AgriPalette.background, // Usamos el fondo de la app
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
                // TÍTULO ARMONIZADO
                Text(
                  'Archivos Adjuntos',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AgriPalette.greyMain, // Gris plomo del logo
                  ),
                ),
                const SizedBox(height: 8),
                Divider(color: AgriPalette.greyMain.withOpacity(0.2)),
                
                // LISTADO DE ARCHIVOS
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

                // Map de archivos con estilos del tema
                ...archivosVisibles.map((archivo) => ListTile(
                  leading: Icon(Icons.insert_drive_file, color: AgriPalette.greenMain),
                  title: Text(
                    archivo.nombrearchivo,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  onTap: () async {
                    try {
                      await _apiService.descargarYVerArchivo(archivo.karchivos);
                    } catch (e) {
                      // Usamos tu nueva función armonizada
                      mensajeEmergente(context, e.toString(), tipo: 'error');
                    }
                  },
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline, color: AgriPalette.error),
                    onPressed: () {
                      setState(() => archivo.eliminado = 1);
                      setModalState(() {});
                      mensajeEmergente(context, 'Archivo marcado para eliminar', tipo: 'warning');
                    },
                  ),
                )),

                if (archivosVisibles.isNotEmpty) const Divider(),
                
                // OPCIONES DE AÑADIR (Colores coherentes)
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

// Función auxiliar para no repetir código de cerrar modal
void _handleFileAction(Function action) {
  Navigator.pop(context);
  action();
}

// Widget auxiliar para mantener los botones de acción limpios
Widget _buildActionTile({
  required BuildContext context,
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return ListTile(
    leading: Icon(icon, color: AgriPalette.greenMain), // Todos en el verde de la app
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

// Future<void> _mostrarOAnadirArchivos() async {
//   showModalBottomSheet(
//     context: context,
//     isScrollControlled: true,
//     shape: const RoundedRectangleBorder(
//       borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//     ),
//     builder: (context) => SafeArea(
//       child: StatefulBuilder(
//         builder: (context, setModalState) {
//           // Filtramos los archivos que NO están marcados como eliminados
//           final archivosVisibles = _archivos.where((a) => a.eliminado == 0).toList();

//           return Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 const Text(
//                   'Archivos Adjuntos',
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                 ),
//                 const Divider(),
                
//                 // Si no hay archivos visibles, mostramos un mensaje
//                 if (archivosVisibles.isEmpty)
//                   const Padding(
//                     padding: EdgeInsets.all(20),
//                     child: Text('No hay archivos adjuntos'),
//                   ),

//                 // Lista de archivos con borrado lógico
//                 ...archivosVisibles.map((archivo) => ListTile(
//                   leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
//                   title: Text(archivo.nombrearchivo),
//                   onTap: () async {
//                     try {
//                       await _apiService.descargarYVerArchivo(archivo.karchivos);
//                     } catch (e) {
//                       mensajeEmergente(context, e.toString(), colorFondo: Colors.red);
//                     }
//                   },
//                   trailing: IconButton(
//                     icon: const Icon(Icons.delete, color: Colors.red),
//                     onPressed: () {
//                       // Cambiamos el estado a 1 (borrado lógico)
//                       // No hacemos .remove() para que el objeto siga en la lista y se envíe al PHP
//                       setState(() {
//                         archivo.eliminado = 1;
//                       });
//                       // Refrescamos el modal para que desaparezca de la vista actual
//                       setModalState(() {});
//                       mensajeEmergente(context, 'Archivo marcado para eliminar');
//                     },
//                   ),
//                 )),

//                 const Divider(),
                
//                 // Opciones para añadir nuevos archivos
//                 ListTile(
//                   leading: const Icon(Icons.camera_alt, color: Colors.green),
//                   title: const Text('Hacer Foto'),
//                   onTap: () async {
//                     Navigator.pop(context);
//                     await _obtenerImagen(ImageSource.camera);
//                   },
//                 ),
//                 ListTile(
//                   leading: const Icon(Icons.photo_library, color: Colors.purple),
//                   title: const Text('Elegir de Galería'),
//                   onTap: () async {
//                     Navigator.pop(context);
//                     await _obtenerImagen(ImageSource.gallery);
//                   },
//                 ),
//                 ListTile(
//                   leading: const Icon(Icons.attach_file, color: Colors.orange),
//                   title: const Text('Adjuntar Archivo/PDF'),
//                   onTap: () async {
//                     Navigator.pop(context);
//                     await _seleccionarYSubirArchivo();
//                   },
//                 ),
//               ],
//             ),
//           );
//         },
//       ),
//     ),
//   );
// }
// Función para manejar Cámara y Galería
Future<void> _obtenerImagen(ImageSource source) async {
  final ImagePicker picker = ImagePicker();
  final XFile? image = await picker.pickImage(source: source, imageQuality: 70);

  if (image != null) {
    await _procesarYSubirArchivo(image.path, image.name);
  }
}

// Función interna para centralizar la subida (usando la librería uuid)
Future<void> _procesarYSubirArchivo(String path, String name) async {
  String newUuid = const Uuid().v4(); // Genera UUID real
  try {
    final response = await _apiService.uploadFile(
      filePath: path,
      kuuid: newUuid,
      tipo: 'albaran_foto',
    );

    setState(() {
      _archivos.add(Archivo(
        karchivos: response['uuid'], 
        nombrearchivo: name,
        kagricultor: '', kuuid: newUuid, orden: _archivos.length + 1,
        fecha: DateTime.now(), formato: name.split('.').last,
        tipo: 'albaran_foto',
      ));
    });
    mensajeEmergente(context, 'Archivo subido correctamente');
  } catch (e) {
    mensajeEmergente(context, 'Error al subir: $e');
  }
}

//COSA1 FIN

Future<void> _seleccionarYSubirArchivo() async {
  // 1. El usuario elige el archivo
  FilePickerResult? result = await FilePicker.platform.pickFiles();

  if (result != null && result.files.single.path != null) {
    String filePath = result.files.single.path!;
    String fileName = result.files.single.name;
    // String newUuid = UniqueKey().toString(); // Generamos un UUID temporal o real
    String newUuid = const Uuid().v4(); // Esto genera un UUID válido como 'f47ac10b-58cc-4372-a567-0e02b2c3d479'

    try {
      // 2. Usamos el endpoint /api/archivo de tu API
      // Nota: Tu ApiService debe tener un método para enviar multipart/form-data
      final response = await _apiService.uploadFile(
        filePath: filePath,
        kuuid: newUuid,
        tipo: 'albaran_foto',
      );

      setState(() {
        _archivos.add(Archivo(
          karchivos: response['uuid'], // El ID que nos devuelve la API
          kagricultor: '', // Lo rellenará el servidor, pero el modelo lo pide
          kuuid: newUuid,
          orden: _archivos.length + 1,
          fecha: DateTime.now(),
          formato: fileName.split('.').last, // Extraemos la extensión (pdf, jpg...)
          nombrearchivo: fileName,
          tipo: 'albaran_foto',
          rutacompleta: null,
          campo1: null,
          sizemb: null,
          comentario: null,
        ));
      });
      
     
     
      // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Archivo subido con éxito')));
      mensajeEmergente(context, 'Archivo subido con éxito');
    } catch (e) {
      mensajeEmergente(context, "Error: $e");
      // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al subir: $e'), backgroundColor: Colors.red));
    }
  }
}

// }
  /// Abre un cuadro de diálogo (Pop-up) para rellenar los datos de un producto (Kilos, cajas...).
 /// ESTA ES LA FUNCIÓN CLAVE: Abre el diálogo con valores preseleccionados
  void _mostrarDialogoDetalle({AlbaranDetalle? detalle}) {
    
    // --- AÑADIR ESTE FILTRO ---
    final productosHortalizas = widget.productos
      .where((p) => p.tipoproductoStr.toUpperCase() == "HORTALIZAS")
      .toList();

    if (detalle != null) {
      // Si editamos, cargamos los datos del detalle existente
      _selectedFinca = detalle.kfinca;
      _selectedProducto = detalle.kproducto;
      _kgController.text = detalle.kg.toString();
      _palletsController.text = detalle.pallets.toString();
      _cajasController.text = detalle.cajas.toString();
      _precioController.text = detalle.precio?.toString() ?? '';
      _comentarioDetController.text = detalle.comentario ?? '';
    } else {
      // SI ES NUEVO: Aquí aplicamos la preselección que pedías
      _kgController.clear(); 
      _palletsController.clear();
      _cajasController.clear(); 
      _precioController.clear();
      _comentarioDetController.clear();

      // 1. Preseleccionar primera finca si existe
      if (widget.fincas.isNotEmpty) {
        _selectedFinca = widget.fincas[0].kfinca;
      }
      
      // 2. Preseleccionar primer producto si existe
      if (productosHortalizas.isNotEmpty) {
            _selectedProducto = productosHortalizas[0].kproducto; // Primera hortaliza
          }
    }

showDialog(
      context: context,
      builder: (context) {
        // Redefinimos el filtro dentro del builder para asegurar que el diálogo lo use correctamente
        final productosHortalizas = widget.productos
            .where((p) => p.tipoproductoStr.toUpperCase() == "HORTALIZAS")
            .toList();

        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Obtenemos el 80% del ancho de la pantalla actual
            double ancho80 = MediaQuery.of(context).size.width * 0.9;
            return AlertDialog(
             title: Text(detalle == null ? 'Nuevo Detalle' : 'Editar Detalle'),
             content: SizedBox(
              width: ancho80, // <--- Aquí aplicamos el 80%
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Desplegable de Fincas (Preseleccionado)
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

                    // Desplegable de Productos (Filtrado por Hortalizas y Preseleccionado)
                    DropdownButtonFormField<String>(
                      value: _selectedProducto,
                      decoration: const InputDecoration(labelText: 'Producto (Hortalizas)'),
                      items: productosHortalizas.map((p) => DropdownMenuItem(
                        value: p.kproducto, 
                        child: Text(p.productoStr)
                      )).toList(),
                      onChanged: (v) => setDialogState(() => _selectedProducto = v),
                    ),

                     const SizedBox(height: 10),
                    TextField(
                      controller: _kgController, 
                      decoration: const InputDecoration(labelText: 'Kilos'), 
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
                  //style: ElevatedButton.styleFrom(backgroundColor: colorAccion),
                  onPressed: () {
                    if (_selectedFinca == null || _selectedProducto == null) return;
                    
                    final nKg = double.tryParse(_kgController.text) ?? 0;
                    final nPal = int.tryParse(_palletsController.text) ?? 0;
                    final nCaj = int.tryParse(_cajasController.text) ?? 0;
                    final nPre = double.tryParse(_precioController.text);

                    if (detalle == null) {
                      // Crear nuevo objeto en la lista local
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
                      // Actualizar objeto existente
                      detalle.kfinca = _selectedFinca!;
                      detalle.kproducto = _selectedProducto!;
                      detalle.kg = nKg; 
                      detalle.pallets = nPal;
                      detalle.cajas = nCaj; 
                      detalle.precio = nPre;
                      detalle.comentario = _comentarioDetController.text;
                    }
                    
                    // Notificamos a la página principal que debe redibujar la lista de tarjetas
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

  /// Aquí se dibuja lo que el usuario ve (la interfaz).
  @override
  Widget build(BuildContext context) {

    // FILTRADO DE ALMACENES: Solo los que coinciden con el tipo de la tabla
    final List<Almacen> almacenesFiltrados = widget.almacenes
        .where((a) => a.ktipoalbaran == uuidTipoAlbaran)
        .toList();

    // Si por algún motivo el último almacén usado no es de este tipo, 
    // evitamos un error visual poniendo el valor a nulo si no está en la lista filtrada.
    if (_selectedAlmacen != null && !almacenesFiltrados.any((a) => a.kalmacen == _selectedAlmacen)) {
      _selectedAlmacen = null;
    }
    
    // Filtramos la lista para NO mostrar los detalles que el usuario ha marcado para eliminar (borrado lógico).
    final visibleItems = _detalles.where((d) => d.eliminado == 0).toList();


    return Scaffold(
      appBar: AppBar(
        title: Text(widget.albaran == null ? 'Nuevo Albarán' : 'Editar Albarán'),
        actions: [
          // Botón de guardar arriba a la derecha.
          
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
                    // Fila para elegir la fecha.
                    ListTile(
                      title: Text('Fecha: ${_fecha.day}/${_fecha.month}/${_fecha.year}'),
                      trailing: const Icon(Icons.calendar_today, color: AgriPalette.greenMain),
                      onTap: () async {
                        // Abre el calendario del sistema Android.
                        final p = await showDatePicker(context: context, initialDate: _fecha, firstDate: DateTime(2020), lastDate: DateTime(2100));
                        if (p != null) setState(() => _fecha = p);
                      },
                    ),
                    // Desplegable de almacenes de destino.
                    DropdownButtonFormField<String>(
                      value: _selectedAlmacen,
                      decoration: const InputDecoration(labelText: 'Almacén de Destino'),
                      items: almacenesFiltrados.map((a) => DropdownMenuItem(
                        value: a.kalmacen, 
                        child: Text(a.nombreStr)
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedAlmacen = v),
                      validator: (v) => v == null ? 'Seleccione almacén' : null,
                    ),
                    const SizedBox(height: 20),
                    // Cuadro para poner el número de albarán que nos dan en el almacén.
                    TextField(
                      controller: _idAlbaranAlmacenController,
                      decoration: const InputDecoration(labelText: 'Nº Albarán Almacén'),
                    ),
                    const SizedBox(height: 20),
                    // Cuadro para notas de voz o escritas generales.
                    TextField(
                      controller: _comentarioCabeceraController,
                      decoration: const InputDecoration(labelText: 'Notas Generales'),
                    ),
                    const Divider(height: 40),
                    // Cabecera de la sección de productos.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('PRODUCTOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        IconButton(icon: const Icon(Icons.add_circle), color:  AgriPalette.greenMain, iconSize: 32, onPressed: () => _mostrarDialogoDetalle()),
                      ],
                    ),
                    // Generamos la lista de "Tarjetas" (Cards) con cada producto añadido.
                    ...visibleItems.map((d) {
                      // Buscamos el nombre del producto para mostrarlo (ya que en 'd' solo tenemos el ID).
                      final prod = widget.productos.firstWhere(
                          (p) => p.kproducto == d.kproducto, 
                          orElse: () => Producto(
                            kproducto: '', 
                            productoStr: '?', 
                            fecha: DateTime.now(),
                            ktipoproducto: '',    // <--- Nuevo campo obligatorio
                            tipoproductoStr: '',  // <--- Nuevo campo obligatorio
                          ),
                        );                      return Card(
                        child: ListTile(
                          title: Text('${prod.productoStr} - ${d.kg} kg'),
                          subtitle: Text('Pallets: ${d.pallets} | Cajas: ${d.cajas}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Botón editar línea.
                              IconButton(icon: const Icon(Icons.edit), color:  AgriPalette.greenMain, onPressed: () => _mostrarDialogoDetalle(detalle: d)),
                              // Botón borrar línea.
                              IconButton(
                                icon: const Icon(Icons.delete), 
                                color:  AgriPalette.greenMain, 
                                onPressed: () => setState(() {
                                  if (d.kalbarandetalle.isEmpty) {
                                    // Si no estaba en la base de datos, lo quitamos de la lista y ya está.
                                    _detalles.remove(d);
                                  } else {
                                    // Si estaba en la base de datos, lo marcamos como 'eliminado = 1'. 
                                    // Así, al darle a GUARDAR, el código sabrá que tiene que borrarlo de la nube.
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



