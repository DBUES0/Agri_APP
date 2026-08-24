// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:sqflite/sqflite.dart';                        // Para ConflictAlgorithm
import 'db_service.dart';                                     // Para que reconozca DBService
import 'package:flutter/material.dart'; // <--- ARREGLA CONTEXT, NAVIGATOR Y MATERIALPAGEROUTE
import '../pages/page_login.dart';    // <--- ARREGLA EL ERROR DE LOGINPAGE
import 'dart:async';
import '../models/record_trabajador.dart';


class ApiService {
  // Esta es la dirección de tu servidor. 
  // Al tenerla aquí, si un día cambia, solo la editas en un sitio.
//  static const String baseUrl = 'https://api.bueso.duckdns.org/api';
static const String baseUrl = 'https://api.bueso.online/api';
  // --- MÉTODOS DE APOYO (HELPERS) ---

  // Obtiene el token que guardamos en el móvil al hacer login
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Crea las "cabeceras" de la petición (idioma, tipo de datos y seguridad)
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      // Si tenemos el token, se lo enviamos al servidor para que nos deje entrar
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // --- MÉTODOS PRINCIPALES ---

  // 1. Método de Login: Envía correo y pass al servidor
  Future<Map<String, dynamic>> postLogin(String email, String password) async {
    final url = Uri.parse('$baseUrl/login');
    
    // Enviamos los datos en formato JSON
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else if (response.statusCode >= 500) {
      // Si es 502, 503, etc., devolvemos un error controlado sin intentar decodificar HTML
      print("SERVIDOR NO DISPONIBLE (${response.statusCode})");
      return {"error": "Servidor temporalmente fuera de servicio"};
    } else {
      // Para errores 400 (Bad Request), intentamos leer el JSON de error si existe
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return {"error": "Error desconocido: ${response.statusCode}"};
      }
    }
  }

  // 2. Listar tablas genéricas (fincas, almacenes...)
    // Future<List<dynamic>> fetchList(String endpoint, {bool isComun = false}) async {
     Future<List<dynamic>> fetchList(String endpoint, {bool isComun = false, bool isMixto = false}) async {
      String tipoRuta = 'listar';
      if (isComun) tipoRuta = 'listarcomun';
      if (isMixto) tipoRuta = 'listarmixto';
      // final url = Uri.parse('$baseUrl${isComun ? '/listarcomun/' : '/listar/'}$endpoint');
      final url = Uri.parse('$baseUrl/$tipoRuta/$endpoint');

      try {
        // Añadimos un timeout para que la App no se quede "colgada" si el proxy no responde
        final response = await http.get(url, headers: await _getHeaders()).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          // CASO ÉXITO: El servidor responde con JSON válido
          print("DEBUG: Datos recibidos en $endpoint: ${response.body.length} registros."); // <-- MIRA ESTO
          return jsonDecode(response.body);
        } 
        else if (response.statusCode >= 500) {
          // CASO SERVIDOR CAÍDO (502 Bad Gateway, 503...): 
          // La respuesta suele ser HTML, así que NO hacemos jsonDecode.
          print("SERVIDOR NO DISPONIBLE (${response.statusCode}) al cargar $endpoint");
          // Devolvemos una lista vacía para que la UI no rompa y cargue lo que tenga en local
          return []; 
        } 
        else {
          // Otros errores (401, 403, 404...)
          print("Error de API (${response.statusCode}): ${response.body}");
          throw 'Error ${response.statusCode} al cargar $endpoint';
        }
      } catch (e) {
        // Capturamos errores de red o FormatException (cuando llega HTML en lugar de JSON)
        if (e is FormatException) {
          print("ERROR DE FORMATO en $endpoint: El servidor devolvió HTML (posible 502).");
        } else {
          print("EXCEPCIÓN DE CONEXIÓN al cargar $endpoint: $e");
        }
        
        // Si falla la red o el formato, devolvemos lista vacía 
        // Esto permite que el flujo offline continúe sin lanzar errores rojos a la pantalla
        return [];
      }
    }

  // 2.1 Listar vistas (vfincas, almacenes...)
  Future<List<dynamic>> fetchListV(String endpoint, {bool isComun = false}) async {
    // Si es común usa /listarcomun/, si no /listar/
    final url = Uri.parse('$baseUrl/vista/$endpoint');
      try {
        // Añadimos un timeout para que la App no se quede "colgada" si el proxy no responde
        final response = await http.get(url, headers: await _getHeaders()).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          // CASO ÉXITO: El servidor responde con JSON válido
          return jsonDecode(response.body);
        } 
        else if (response.statusCode >= 500) {
          // CASO SERVIDOR CAÍDO (502 Bad Gateway, 503...): 
          // La respuesta suele ser HTML, así que NO hacemos jsonDecode.
          print("SERVIDOR NO DISPONIBLE (${response.statusCode}) al cargar $endpoint");
          // Devolvemos una lista vacía para que la UI no rompa y cargue lo que tenga en local
          return []; 
        } 
        else {
          // Otros errores (401, 403, 404...)
          print("Error de API (${response.statusCode}): ${response.body}");
          throw 'Error ${response.statusCode} al cargar $endpoint';
        }
      } catch (e) {
        // Capturamos errores de red o FormatException (cuando llega HTML en lugar de JSON)
        if (e is FormatException) {
          print("ERROR DE FORMATO en $endpoint: El servidor devolvió HTML (posible 502).");
        } else {
          print("EXCEPCIÓN DE CONEXIÓN al cargar $endpoint: $e");
        }
        
        // Si falla la red o el formato, devolvemos lista vacía 
        // Esto permite que el flujo offline continúe sin lanzar errores rojos a la pantalla
        return [];
      }
    }

// 3. Listar tablas particulares (productos, albaranes...)
Future<List<dynamic>> fetchParticular(String endpoint) async {
  final url = Uri.parse('$baseUrl/$endpoint');
  
  try {
    final response = await http.get(url, headers: await _getHeaders());
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Aprovechamos para guardar en caché siempre que haya internet
      await DBService.instance.saveToCache(endpoint, data is List ? data.cast<Map<String, dynamic>>() : [data]);
      return data;
    } else {
      throw 'Error del servidor';
    }
  } catch (e) {
    // ¡AQUÍ ESTÁ EL TRUCO! 
    // Si hay SocketException (offline), cargamos de la DB local automáticamente
    print("Modo Offline detectado para $endpoint. Cargando de SQLite...");
    return await DBService.instance.getAllFromLocal(endpoint);
  }
}

// En ApiService.dart añade:

Future<Map<String, dynamic>> postParticular(String endpoint, Map<String, dynamic> data) async {
  final url = Uri.parse('$baseUrl/$endpoint');        
  
  try {
    // CAMBIO VITAL: Usar http.post y enviar el body
    final response = await http.post(
      url, 
      headers: await _getHeaders(),
      body: jsonEncode(data), // Enviamos los datos del albarán/gasto
    ).timeout(const Duration(seconds: 30)); // 30s es más seguro para albaranes grandes

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } 
    else if (response.statusCode >= 500) {
      print("SERVIDOR NO DISPONIBLE (${response.statusCode}) en $endpoint");
      return {"error": "Servidor temporalmente fuera de servicio"};
    } 
    else {
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return {"error": "Error del servidor (${response.statusCode})"};
      }
    }
  } catch (e) {
    if (e is FormatException) {
      print("ERROR DE FORMATO en $endpoint: Respuesta no válida (HTML).");
      return {"error": "El servidor no respondió con un formato correcto."};
    } else if (e is TimeoutException) {
      print("TIEMPO AGOTADO en la conexión con $endpoint.");
      return {"error": "Tiempo de espera agotado"};
    }
    print("EXCEPCIÓN en $endpoint: $e");
    return {"error": "Error de conexión: $e"};
  }
}

Future<void> putGeneric(String tabla, String id, Map<String, dynamic> data) async {
  final url = Uri.parse('$baseUrl/editar/$tabla/$id');
  final response = await http.put(url, headers: await _getHeaders(), body: jsonEncode(data));
  if (response.statusCode != 200) throw 'Error al editar $tabla: ${response.body}';
}

Future<void> deleteGeneric(String tabla, String id) async {
  final url = Uri.parse('$baseUrl/eliminar/$tabla/$id');
  final response = await http.delete(url, headers: await _getHeaders());
  if (response.statusCode != 200) throw 'Error al eliminar de $tabla';
}


Future<Map<String, dynamic>> uploadFile({
  required String filePath,
  required String kuuid,
  required String tipo,
  String? karchivos, // <--- AÑADE ESTO
}) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');

  // Creamos la petición multipart (para enviar binarios)
  var request = http.MultipartRequest(
    'POST',
    Uri.parse('$baseUrl/archivo'),
  );
  
  if (karchivos != null) request.fields['karchivos'] = karchivos;

  // Añadimos las cabeceras de seguridad
  request.headers['Authorization'] = 'Bearer $token';

  // Añadimos los campos de texto
  request.fields['kuuid'] = kuuid;
  request.fields['tipo'] = tipo;

  // Añadimos el archivo binario
  request.files.add(await http.MultipartFile.fromPath('archivo', filePath));

  // Enviamos y esperamos respuesta
  var streamedResponse = await request.send();
  var response = await http.Response.fromStream(streamedResponse);

  if (response.statusCode == 200) {
    return json.decode(response.body);
  } else {
    throw Exception('Error al subir archivo: ${response.body}');
  }
}

Future<void> descargarYVerArchivo(String karchivo) async {
  try {
    // 1. Definir la URL según tu definición de cURL
    final url = Uri.parse('$baseUrl/gastos/descargararchivo/$karchivo');

    // 2. Realizar la petición GET con tus cabeceras de seguridad
    // Usamos _getHeaders() que ya incluye el Bearer Token y el Accept: application/json
    // pero sobreescribimos el Accept para que coincida con tu API
    final headers = await _getHeaders();
    headers['Accept'] = 'application/octet-stream';

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      // 3. Obtener el directorio temporal del móvil
      final directory = await getTemporaryDirectory();
      String contentStart = String.fromCharCodes(response.bodyBytes.take(10));
      if (contentStart.contains("<br") || contentStart.contains("<html")) {
        throw 'El servidor devolvió un error interno en lugar del archivo.';
      }
      
      // Intentamos extraer el nombre del archivo de la cabecera o usamos el ID
      String fileName = "archivo_$karchivo";
      if (response.headers.containsKey('content-disposition')) {
        // Lógica básica para extraer nombre si el servidor lo envía
        fileName = response.headers['content-disposition']!.split('filename=').last.replaceAll('"', '');
      }

      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      // 4. Escribir los bytes recibidos en el archivo local
      await file.writeAsBytes(response.bodyBytes);

      // 5. Abrir el archivo con la aplicación correspondiente del sistema
      final result = await OpenFilex.open(filePath);
      
      if (result.type != ResultType.done) {
        throw 'No hay una aplicación instalada para abrir este archivo (${result.message})';
      }
    } else {
      throw 'Error del servidor (${response.statusCode}): ${response.body}';
    }
  } catch (e) {
    debugPrint("Error en la descarga/visualización: $e");
    rethrow; // Lanzamos para que la UI use mensajeEmergente
  }
}

Future<Map<String, dynamic>> mergeAlbaran(Map<String, dynamic> albaranData) async {
  // El endpoint espera un array de objetos según tu PHP
  final body = [albaranData]; 
  final url = Uri.parse('$baseUrl/mergealbaran');

  try {
    final response = await http.post(
      url, 
      headers: await _getHeaders(), 
      body: jsonEncode(body)
    ).timeout(const Duration(seconds: 30)); // Timeout más largo para el merge

    if (response.statusCode == 200 || response.statusCode == 201) {
      // CASO ÉXITO
      return jsonDecode(response.body);
    } 
    else if (response.statusCode >= 500) {
      // CASO SERVIDOR CAÍDO (502 Bad Gateway detectado en logs)
      print("SERVIDOR NO DISPONIBLE (${response.statusCode}) en mergeAlbaran");
      return {'error': 'Servidor fuera de servicio temporalmente (Error ${response.statusCode})'};
    } 
    else {
      // CASO ERROR CONTROLADO (400, 401, 403...)
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return {'error': 'Error en el servidor (${response.statusCode})'};
      }
    }
  } catch (e) {
    // GESTIÓN DE EXCEPCIONES (Red o Formato HTML)
    if (e is FormatException) {
      print("ERROR DE FORMATO en mergeAlbaran: El servidor devolvió HTML (posible 502).");
      return {'error': 'La respuesta del servidor no es un JSON válido'};
    }
    
    print("EXCEPCIÓN en mergeAlbaran: $e");
    return {'error': 'No se pudo conectar con el servidor: $e'};
  }
}
Future<List<Map<String, dynamic>>> fetchIncremental(String endpoint) async {
  // 1. CAMBIO: Usar DBService en lugar de AI
  final db = await DBService.instance.database;
  final res = await db.query('sync_metadata', where: 'entidad = ?', whereArgs: [endpoint]);
  
  String desde = res.isNotEmpty ? res.first['ultima_sincro'] as String : '2000-01-01 00:00:00';

  // 2. CAMBIO: url no existía, usamos baseUrl
  final response = await http.get(
    Uri.parse('$baseUrl/$endpoint?desde=$desde'), // Convertir a Uri
    headers: await _getHeaders()
  );

  // 3. CAMBIO: response.body no tiene .isNotEmpty, se comprueba el status o el contenido
  if (response.statusCode == 200) {
    final List<dynamic> nuevosDatos = jsonDecode(response.body);
    
    if (nuevosDatos.isNotEmpty) {
      // Guardamos en SQL (Asegúrate de tener este método en db_service.dart)
      await DBService.instance.saveToCache(endpoint, nuevosDatos.cast<Map<String, dynamic>>());
      
      await db.insert('sync_metadata', 
        {'entidad': endpoint, 'ultima_sincro': DateTime.now().toString()},
        conflictAlgorithm: ConflictAlgorithm.replace
      );
    }
  }
    if (response.statusCode == 401) {
      // El servidor dice que el token no vale. 
      // 1. Borrar datos locales
      // 2. Redirigir al Login
      throw 'Expired token'; // Lanzamos este texto exacto para que SyncService lo cace
      // throw "Sesión caducada"; 
    }
  
  if (response.statusCode == 200 || response.statusCode == 201) {
    //return jsonDecode(response.body);
    return await _getAllFromLocal(endpoint);
  }
  
  throw 'Error en $endpoint: ${response.body}';

  // 4. Debes definir este método en ApiService o llamar a la DB directamente
  
}

// AÑADE ESTE MÉTODO al final de la clase ApiService para que no dé error
Future<List<Map<String, dynamic>>> _getAllFromLocal(String tabla) async {
  final db = await DBService.instance.database;
  final res = await db.query('local_cache', where: 'tabla = ?', whereArgs: [tabla]);
  return res.map((item) => jsonDecode(item['json_data'] as String) as Map<String, dynamic>).toList();
}

Future<void> guardarAlbaranOffline(Map<String, dynamic> albaranData) async {
  final db = await DBService.instance.database;

  // 1. Lo guardamos en la caché local para que el usuario lo vea YA
  await DBService.instance.saveToCache('albaranes', [albaranData]);

  // 2. Lo anotamos en la lista de pendientes
  await db.insert('pendientes_sincro', {
    'entidad': 'albaran',
    'operacion': 'INSERT',
    'datos_json': jsonEncode(albaranData),
    'fecha_creacion': DateTime.now().toIso8601String(),
  });

  // 3. Intentamos sincronizar en segundo plano (sin bloquear al usuario)
  sincronizarPendientes(); 
}

Future<void> sincronizarPendientes() async {
  final db = await DBService.instance.database;
  
  // Obtenemos todo lo que falta por subir
  final List<Map<String, dynamic>> pendientes = await db.query('pendientes_sincro');

  for (var item in pendientes) {
    try {
      final Map<String, dynamic> datos = jsonDecode(item['datos_json']);
      
      // Intentamos enviar a la API
      await postParticular('mergealbaran', datos);

      // Si la API responde OK, borramos de pendientes
      await db.delete('pendientes_sincro', where: 'id = ?', whereArgs: [item['id']]);
      
      print("Sincronizado con éxito: ${item['id']}");
    } catch (e) {
      // Si falla (por falta de red), no hacemos nada. 
      // Se queda en la tabla para el próximo intento.
      print("Fallo de red, se reintentará luego: $e");
      break; // Dejamos de intentar para no saturar si no hay red
    }
  }
}



Future<void> cerrarSesion(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  
  // 1. Limpiamos TODA la persistencia local relacionada con la sesión
  await prefs.remove('token');
  await prefs.remove('usuario_json');
  
  // Opcional: Detener el motor de autosync si lo tienes activo
  // SyncService.stopAutoSync(); 

  if (!context.mounted) return;

  // 2. Navegación "limpia": Borra todo el historial de pantallas y va al Login
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (context) => const LoginPage()),
    (route) => false, // Esto hace que no se pueda volver al Dashboard con el botón atrás
  );
}


Future<String?> subirArchivoMultipart(
  String pathLocal, 
  String kuuidPadre, 
  String tipo, 
  {String? karchivoLocal}
) async {
  try {
    final String cleanUrl = baseUrl.endsWith('/api') ? '$baseUrl/archivo' : '$baseUrl/api/archivo';
    var request = http.MultipartRequest('POST', Uri.parse(cleanUrl));
    
    final String? token = await _getToken();
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    request.fields['kuuid'] = kuuidPadre;
    request.fields['tipo'] = tipo;
    if (karchivoLocal != null) {
      request.fields['karchivos'] = karchivoLocal;
    }

    final file = File(pathLocal);
    if (!await file.exists()) {
      print("INFO: Saltando archivo no local o inexistente: $pathLocal");
      return null;
    }

    request.files.add(await http.MultipartFile.fromPath('archivo', pathLocal));

    print("Subiendo binario a: $cleanUrl");
    
    // Ejecutamos el envío con un timeout de seguridad
    var streamedResponse = await request.send().timeout(const Duration(seconds: 60));
    var response = await http.Response.fromStream(streamedResponse);

    // --- BLOQUE DE CONTROL ROBUSTO ---
    if (response.statusCode == 200 || response.statusCode == 201) {
      // ÉXITO: El servidor respondió con JSON válido
      final resBody = jsonDecode(response.body);
      return resBody['uuid']?.toString();
    } 
    else if (response.statusCode >= 500) {
      // ERROR DE SERVIDOR (502, 503...): La respuesta suele ser HTML
      print("SERVIDOR NO DISPONIBLE (${response.statusCode}) en subida de archivo. Abortando intento actual.");
      return null; // Devolvemos null para que SyncService reintente luego
    } 
    else {
      // OTROS ERRORES (400, 401, 404): Intentamos leer el JSON de error si es posible
      print("ERROR SERVIDOR (${response.statusCode})");
      try {
        final errorJson = jsonDecode(response.body);
        print("Detalle del error: ${errorJson['error']}");
      } catch (_) {
        print("No se pudo decodificar el detalle del error (posible respuesta no-JSON).");
      }
      return null;
    }
  } catch (e) {
    // GESTIÓN DE EXCEPCIONES (Red o Formato HTML)
    if (e is FormatException) {
      print("ERROR DE FORMATO en subida: El servidor devolvió HTML en lugar de JSON (posible 502).");
    } else if (e is TimeoutException) {
      print("TIEMPO AGOTADO en la subida del archivo.");
    } else {
      print("EXCEPCIÓN SUBIDA: $e");
    }
    return null; // No rompemos la App, simplemente cancelamos este archivo por ahora
  }
}

Future<List<Trabajador>> fetchTrabajadoresActivos() async {
  try {
    // CAMBIO: fetchParticular en lugar de getParticular
    final response = await fetchParticular('trabajadores/activos');
    
    // Asegúrate de que response sea una lista antes de mapear
    return response.map((json) => Trabajador.fromJson(json)).toList();
      return [];
  } catch (e) {
    print("Error cargando trabajadores activos: $e");
    return [];
  }
}

// Future<void> postGeneric(String tabla, Map<String, dynamic> data) async {
//   final url = Uri.parse('$baseUrl/insertar/$tabla');
//   final response = await http.post(
//     url, 
//     headers: await _getHeaders(), 
//     body: jsonEncode(data)
//   );
  
//   if (response.statusCode != 200 && response.statusCode != 201) {
//     throw 'Error al insertar en $tabla: ${response.body}';
//   }
// }

Future<void> postGeneric(String tabla, Map<String, dynamic> data) async {
  final url = Uri.parse('$baseUrl/crear/$tabla');
  
  // OBTENEMOS HEADERS Y LOS IMPRIMIMOS
  final headers = await _getHeaders();
  print("DEBUG POST: URL -> $url");
  print("DEBUG POST: Headers -> $headers"); // <--- MIRA ESTO EN LA CONSOLA
  print("DEBUG POST: Body -> ${jsonEncode(data)}");

  final response = await http.post(
    url, 
    headers: headers, 
    body: jsonEncode(data)
  );
  
  print("DEBUG POST: Respuesta (${response.statusCode}) -> ${response.body}");

  if (response.statusCode != 200 && response.statusCode != 201) {
    throw 'Error al insertar en $tabla: ${response.body}';
  }
}

}

