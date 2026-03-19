import 'dart:convert';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';


class ApiService {
  // Esta es la dirección de tu servidor. 
  // Al tenerla aquí, si un día cambia, solo la editas en un sitio.
  static const String baseUrl = 'https://api.bueso.duckdns.org/api';

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

    if (response.statusCode == 200) {
      // Si el servidor dice OK, devolvemos los datos (token y usuario)
      return jsonDecode(response.body);
    } else {
      // Si hay error (ej: contraseña mal), lanzamos un mensaje
      final errorData = jsonDecode(response.body);
      throw errorData['error'] ?? 'Error desconocido al iniciar sesión';
    }
  }

  // 2. Listar tablas genéricas (fincas, almacenes...)
  Future<List<dynamic>> fetchList(String endpoint, {bool isComun = false}) async {
    // Si es común usa /listarcomun/, si no /listar/
    final url = Uri.parse('$baseUrl${isComun ? '/listarcomun/' : '/listar/'}$endpoint');
    // print('Hola1');
    // print(url);
    final response = await http.get(url, headers: await _getHeaders());
    // print('Hola2');
    // print(response.body);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw 'No se pudo cargar la lista de $endpoint';
    }
  }

  // 2.1 Listar vistas (vfincas, almacenes...)
  Future<List<dynamic>> fetchListV(String endpoint, {bool isComun = false}) async {
    // Si es común usa /listarcomun/, si no /listar/
    final url = Uri.parse('$baseUrl/vista/$endpoint');
    final response = await http.get(url, headers: await _getHeaders());
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw 'No se pudo cargar la lista de $endpoint';
    }
  }
  // 3. Endpoints especiales (como los albaranes que tienen lógica compleja)
  Future<List<dynamic>> fetchParticular(String endpoint) async {
    final url = Uri.parse('$baseUrl/$endpoint');
    final response = await http.get(url, headers: await _getHeaders());
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw 'Error al obtener datos de $endpoint';
    }
  }
// En ApiService.dart añade:

Future<Map<String, dynamic>> postParticular(String endpoint, Map<String, dynamic> data) async {
  final url = Uri.parse('$baseUrl/$endpoint');
  final response = await http.post(url, headers: await _getHeaders(), body: jsonEncode(data));
  if (response.statusCode == 200 || response.statusCode == 201) return jsonDecode(response.body);
  throw 'Error en $endpoint: ${response.body}';
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
}) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');

  // Creamos la petición multipart (para enviar binarios)
  var request = http.MultipartRequest(
    'POST',
    Uri.parse('$baseUrl/archivo'),
  );

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

// Opción rápida: Abrir en el navegador del móvil
// Future<void> descargarYVerArchivo(String karchivo) async {
//   final prefs = await SharedPreferences.getInstance();
//   final token = prefs.getString('token');
  
//   // Construimos la URL completa incluyendo el token como parámetro query 
//   // para que el navegador tenga permiso de descarga
//   final String urlString = '$baseUrl/gastos/descargararchivo/$karchivo?token=$token';
//   final Uri url = Uri.parse(urlString);

//   try {
//     if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
//       throw Exception('No se pudo abrir el archivo en $urlString');
//     }
//   } catch (e) {
//     print("Error al abrir URL: $e");
//   }
// }
// Future<void> descargarYVerArchivo(String karchivo) async {
//   final prefs = await SharedPreferences.getInstance();
//   final token = prefs.getString('token');
  
//   // Construimos la URL. Usamos la variable de clase baseUrl si existe.
//   final String urlString = '$baseUrl/gastos/descargararchivo/$karchivo?token=$token';
//   final Stringresponse = await http.delete(url, headers: await _getHeaders());
//   final Uri url = Uri.parse(urlString);

//   try {
//     // launchUrl es la función que efectivamente abre el navegador o el visor de archivos
//     if (await canLaunchUrl(url)) {
//       await launchUrl(
//         url, 
//         mode: LaunchMode.externalApplication, // Abre el navegador del sistema
//       );
//     } else {
//       throw 'No se pudo abrir la URL: $urlString';
//     }
//   } catch (e) {
//     debugPrint("Error al descargar archivo: $e");
//     // Aquí no puedes llamar a mensajeEmergente directamente por lo explicado arriba,
//     // es mejor lanzar el error y que la página lo capture y lo muestre.
//     rethrow; 
//   }
// }

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
  // El endpoint espera un array de objetos según tu PHP: if (!isset($input[0]))
  final body = [albaranData]; 
  
  final url = Uri.parse('$baseUrl/mergealbaran');
  print("mensaje enviado al servidor: ${body.toString()}");
  print("mensaje enviado al servidor: ${jsonEncode(body)}");
  final response = await http.post(
    url, 
    headers: await _getHeaders(), 
    body: jsonEncode(body)
  );

if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    // Si la respuesta contiene HTML (un error de PHP), no intentamos decodificarlo como JSON
    if (response.body.contains('<br />') || response.body.contains('<b>Fatal error</b>')) {
       throw 'Error interno del servidor (PHP). Revise los logs del servidor.';
    }
    
    // Si es un error controlado por tu API (en formato JSON)
    try {
      final error = jsonDecode(response.body);
      throw error['error'] ?? 'Error desconocido';
    } catch (_) {
      throw 'Error en la respuesta del servidor (${response.statusCode})';
    }
  }
}

}
