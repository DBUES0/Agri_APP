<?php
// funciones.php

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Psr\Http\Server\RequestHandlerInterface as RequestHandler;
use Firebase\JWT\JWT;
use Firebase\JWT\Key;

// Función para enviar una respuesta JSON
function jsonResponse(Response $response, $data, int $status = 200): Response {
    $json = json_encode($data);
    if ($json === false) {
        $json = json_encode(["error" => "Error al codificar los datos"]);
        $status = 500;
    }
    $response->getBody()->write($json);
    return $response->withStatus($status)->withHeader('Content-Type', 'application/json');
}

// Conexión a la base de datos desde variables de entorno
function conectarDB($servername = null, $username = null, $password = null, $dbname = null) {
    // Si no vienen parámetros, usa las variables de entorno (como ya tenías)
    $servername = $servername ?? $_ENV['DB_HOST'];
    $username   = $username   ?? $_ENV['DB_USER'];
    $password   = $password   ?? $_ENV['DB_PASS'];
    $dbname     = $dbname     ?? $_ENV['DB_NAME'];

    $conn = new mysqli($servername, $username, $password, $dbname);
    if ($conn->connect_error) {
        throw new Exception("Conexión fallida: " . $conn->connect_error);
    }
    return $conn;
}

// Middleware JWT
function jwtMiddleware($secret)
{
    return function (Request $request, RequestHandler $handler) use ($secret) {
        $path = $request->getUri()->getPath();

        if ($path === '/api/login' || $path === '/' || $path === '/swagger.json') {
            return $handler->handle($request);
        }

        $authHeader = $request->getHeaderLine('Authorization');
        if (!$authHeader || !preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
            $response = new \Slim\Psr7\Response();
            $response->getBody()->write(json_encode(['error' => 'Token no proporcionado']));
            return $response->withStatus(401)->withHeader('Content-Type', 'application/json');
        }

        try {
            $token = $matches[1];
            $decoded = JWT::decode($token, new Key($secret, 'HS256'));
            $request = $request->withAttribute('jwt', $decoded);
            return $handler->handle($request);
        } catch (Exception $e) {
            $response = new \Slim\Psr7\Response();
            $response->getBody()->write(json_encode(['error' => 'Token inválido: ' . $e->getMessage()]));
            return $response->withStatus(401)->withHeader('Content-Type', 'application/json');
        }
    };
}

// Generador UUID
function generateUUID() {
    return sprintf(
        '%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        mt_rand(0, 0xffff), mt_rand(0, 0xffff),
        mt_rand(0, 0xffff),
        mt_rand(0, 0x0fff) | 0x4000,
        mt_rand(0, 0x3fff) | 0x8000,
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
    );
}


//function subirArchivo(Request $request, Response $response, $servername, $username, $password, $dbname, $uploadDir): Response
function subirArchivov1(Request $request, Response $response, $servername, $username, $password, $dbname, $uploadDir): Response
{
    $uploadedFiles = $request->getUploadedFiles();
    $parsedBody = $request->getParsedBody();

    $jwt = $request->getAttribute('jwt');
    $kagricultor = $jwt->sub;
    
    if (!isset($uploadedFiles['archivo'])) {
        return jsonResponse($response, ["error" => "No se proporcionó archivo"], 400);
    }

    $file = $uploadedFiles['archivo'];
    $kuuid = $parsedBody['kuuid'] ?? null;
    $tipo = $parsedBody['tipo'] ?? null;

    if (!$kuuid || !$tipo) {
        return jsonResponse($response, ["error" => "Faltan parámetros kuuid o tipo"], 400);
    }

    $filename = $file->getClientFilename();
    $format = strtoupper(pathinfo($filename, PATHINFO_EXTENSION));
    $sizeMB = round($file->getSize() / 1048576, 2);
    $fileContent = $file->getStream()->getContents();

    try {
        $conn = conectarDB($servername, $username, $password, $dbname);

        $stmt = $conn->prepare("INSERT INTO tblArchivos 
                              (kuuid, tipo_str, archivo_bin, formato_str, sizemb_flt, nombrearchivo_str, kagricultor) 
                              VALUES (?, ?, ?, ?, ?, ?, ?)");
        $null = null;
        // Los tipos son: string, string, blob (se maneja con send_long_data), string, float, string, string
        $stmt->bind_param("ssbsdss", $kuuid, $tipo, $null, $format, $sizeMB, $filename, $kagricultor);
        $stmt->send_long_data(2, $fileContent);
        
        if (!$stmt->execute()) {
            throw new Exception("Error al ejecutar la consulta: " . $stmt->error);
        }
        
        $fileId = $conn->insert_id;
        $stmt->close();

        // Obtener el ID del archivo recién insertado
        $uuidStmt = $conn->prepare("SELECT karchivos FROM tblArchivos WHERE kuuid = ? AND kagricultor = ? ORDER BY fecha_dtm DESC LIMIT 1");
        $uuidStmt->bind_param("ss", $kuuid, $kagricultor);
        $uuidStmt->execute();
        $uuidStmt->bind_result($uuid);
        $uuidStmt->fetch();
        $uuidStmt->close();

        // Verificar que el archivo se almacenó correctamente
        $verifyStmt = $conn->prepare("SELECT OCTET_LENGTH(archivo_bin) FROM tblArchivos WHERE karchivos = ? AND kagricultor = ?");
        $verifyStmt->bind_param("ss", $uuid, $kagricultor);
        $verifyStmt->execute();
        $verifyStmt->bind_result($storedLength);
        $verifyStmt->fetch();
        $verifyStmt->close();

        if ($storedLength != strlen($fileContent)) {
            $conn->query("DELETE FROM tblArchivos WHERE karchivos = '$uuid' AND kagricultor = '$kagricultor'");
            $conn->close();
            return jsonResponse($response, ["error" => "El archivo no se almacenó correctamente"], 500);
        }

        // Guardar también en el sistema de archivos
        $extension = strtolower(pathinfo($filename, PATHINFO_EXTENSION));
        $finalPath = rtrim($uploadDir, '/') . '/' . $uuid . '.' . $extension;

        file_put_contents($finalPath, $fileContent);

        // Actualizar la ruta en la base de datos
        $stmt = $conn->prepare("UPDATE tblArchivos SET rutacompleta_str = ? WHERE karchivos = ?");
        $stmt->bind_param("ss", $finalPath, $uuid);
        $stmt->execute();
        $stmt->close();

        $conn->close();
        return jsonResponse($response, ["mensaje" => "Archivo subido correctamente", "uuid" => $uuid], 200);
        
    } catch (Exception $e) {
        error_log("Error al subir archivo: " . $e->getMessage());
        return jsonResponse($response, ["error" => $e->getMessage()], 500);
    }
}

/**
 * Procesa la subida de archivos vinculándolos a un registro (Albarán, Gasto, etc.)
 * Soporta la recepción de UUIDs generados por el cliente para sincronización offline.
 */
// function subirArchivo(Request $request, Response $response, $servername, $username, $password, $dbname, $uploadDir): Response
// {
//     $uploadedFiles = $request->getUploadedFiles();
//     $parsedBody = $request->getParsedBody();

//     $jwt = $request->getAttribute('jwt');
//     $kagricultor = $jwt->sub;
    
//     if (!isset($uploadedFiles['archivo'])) {
//         return jsonResponse($response, ["error" => "No se ha recibido ningún archivo"], 400);
//     }

//     $file = $uploadedFiles['archivo'];
//     $kuuidPadre = $parsedBody['kuuid'] ?? null;
//     $tipo = $parsedBody['tipo'] ?? null;
//     $karchivos_cliente = $parsedBody['karchivos'] ?? null; 

//     if (!$kuuidPadre || !$tipo) {
//         return jsonResponse($response, ["error" => "Parámetros kuuid o tipo no proporcionados"], 400);
//     }

//     // --- CORRECCIÓN 1: Definir idFinal PRIMERO ---
//     // 1. Aseguramos el ID y la extensión
//     $idFinal = $karchivos_cliente ?: generarUUIDv4(); 
//     $extension = strtolower(pathinfo($filename, PATHINFO_EXTENSION));
//     $finalPath = rtrim($uploadDir, '/') . '/' . $idFinal . '.' . $extension;

//     try {
//         $conn = conectarDB($servername, $username, $password, $dbname);

//         // ERROR AQUÍ: Cuenta bien las columnas (9) y los placeholders (9)
//         // 1.karchivos, 2.kagricultor, 3.kuuid, 4.tipo_str, 5.archivo_bin, 6.formato_str, 7.sizemb_flt, 8.nombrearchivo_str, 9.rutacompleta_str
//         $sql = "INSERT INTO tblArchivos 
//                 (karchivos, kagricultor, kuuid, tipo_str, archivo_bin, formato_str, sizemb_flt, nombrearchivo_str, rutacompleta_str) 
//                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";
        
//         $stmt = $conn->prepare($sql);
//         $null = null; 
        
//         // CORRECCIÓN: "ssssbsdss" -> 9 letras para 9 parámetros
//         // s=string, b=blob, d=double
//         $stmt->bind_param("ssssbsdss", 
//             $idFinal,           // 1
//             $kagricultor,       // 2
//             $kuuidPadre,        // 3
//             $tipo,              // 4
//             $null,              // 5 (BLOB placeholder)
//             $format,            // 6
//             $sizeMB,            // 7
//             $filename,          // 8
//             $finalPath          // 9
//         );

//         $stmt->send_long_data(4, $fileContent); // El 4 corresponde al campo archivo_bin
        
//         if (!$stmt->execute()) {
//             throw new Exception("Error ejecución SQL: " . $stmt->error);
//         }
        
//         $stmt->close();
//         $conn->close();

//         // Guardar físicamente en el NAS
//         file_put_contents($finalPath, $fileContent);

//         return jsonResponse($response, [
//             "mensaje" => "Sincronizado", 
//             "uuid" => (string)$idFinal 
//         ], 200);
        
//     } catch (Exception $e) {
//         return jsonResponse($response, ["error" => $e->getMessage()], 500);
//     }
// }

//este medio va
// function subirArchivo(Request $request, Response $response, $servername, $username, $password, $dbname, $uploadDir): Response
// {
//     $uploadedFiles = $request->getUploadedFiles();
//     $parsedBody = $request->getParsedBody();

//     $jwt = $request->getAttribute('jwt');
//     $kagricultor = $jwt->sub;
    
//     if (!isset($uploadedFiles['archivo'])) {
//         return jsonResponse($response, ["error" => "No se ha recibido ningún archivo"], 400);
//     }

//     $file = $uploadedFiles['archivo'];
//     $kuuidPadre = $parsedBody['kuuid'] ?? null;
//     $tipo = $parsedBody['tipo'] ?? null;
//     $karchivos_cliente = $parsedBody['karchivos'] ?? null; 

//     if (!$kuuidPadre || !$tipo) {
//         return jsonResponse($response, ["error" => "Parámetros kuuid o tipo no proporcionados"], 400);
//     }

//     // --- CORRECCIÓN 1: Definir variables del archivo ---
//     $filename = $file->getClientFilename();
//     $format = strtoupper(pathinfo($filename, PATHINFO_EXTENSION));
//     $sizeMB = round($file->getSize() / 1048576, 2);
//     $fileContent = $file->getStream()->getContents(); // Obtenemos el binario real

//     $idFinal = $karchivos_cliente ?: generarUUIDv4(); 
//     $extension = strtolower(pathinfo($filename, PATHINFO_EXTENSION));
//     $finalPath = rtrim($uploadDir, '/') . '/' . $idFinal . '.' . $extension;

//     try {
//         $conn = conectarDB($servername, $username, $password, $dbname);

//         // --- CORRECCIÓN 2: ON DUPLICATE KEY UPDATE ---
//         // Si la fila ya existe (creada por mergealbaran), actualizamos el binario y la ruta NAS
//         $sql = "INSERT INTO tblArchivos 
//                 (karchivos, kagricultor, kuuid, tipo_str, archivo_bin, formato_str, sizemb_flt, nombrearchivo_str, rutacompleta_str) 
//                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
//                 ON DUPLICATE KEY UPDATE 
//                     archivo_bin = VALUES(archivo_bin), 
//                     rutacompleta_str = VALUES(rutacompleta_str),
//                     sizemb_flt = VALUES(sizemb_flt),
//                     formato_str = VALUES(formato_str)";
        
//         $stmt = $conn->prepare($sql);
//         $null = null; 
        
//         // "ssssbsdss" -> 9 parámetros
//         $stmt->bind_param("ssssbsdss", 
//             $idFinal,           // 1. karchivos
//             $kagricultor,       // 2. kagricultor
//             $kuuidPadre,        // 3. kuuid
//             $tipo,              // 4. tipo_str
//             $null,              // 5. archivo_bin (BLOB placeholder)
//             $format,            // 6. formato_str
//             $sizeMB,            // 7. sizemb_flt
//             $filename,          // 8. nombrearchivo_str
//             $finalPath          // 9. rutacompleta_str (Ruta en el NAS)
//         );

//         // Inyectamos el binario en el parámetro 4 (archivo_bin)
//         $stmt->send_long_data(4, $fileContent); 
        
//         if (!$stmt->execute()) {
//             throw new Exception("Error ejecución SQL: " . $stmt->error);
//         }
        
//         $stmt->close();
//         $conn->close();

//         // --- CORRECCIÓN 3: Guardar físicamente en el NAS ---
//         if (!file_exists($uploadDir)) {
//             mkdir($uploadDir, 0777, true);
//         }
//         file_put_contents($finalPath, $fileContent);

//         // RESPUESTA LIMPIA (Sin print_r ni printf que rompan el JSON de Flutter)
//         return jsonResponse($response, [
//             "mensaje" => "Sincronizado", 
//             "uuid" => (string)$idFinal 
//         ], 200);
        
//     } catch (Exception $e) {
//         return jsonResponse($response, ["error" => $e->getMessage()], 500);
//     }
// }

//este igaual, funciona pero regulín
// function subirArchivo(Request $request, Response $response, $servername, $username, $password, $dbname, $uploadDir): Response
// {
//     $uploadedFiles = $request->getUploadedFiles();
//     $parsedBody = $request->getParsedBody();
//     $jwt = $request->getAttribute('jwt');
//     $kagricultor = $jwt->sub;
    
//     if (!isset($uploadedFiles['archivo'])) {
//         return jsonResponse($response, ["error" => "No se ha recibido ningún archivo"], 400);
//     }

//     $file = $uploadedFiles['archivo'];
//     $kuuidPadre = $parsedBody['kuuid'] ?? null;
//     $tipo = $parsedBody['tipo'] ?? null;
//     $karchivos_cliente = $parsedBody['karchivos'] ?? null; 

//     if (!$kuuidPadre || !$tipo) {
//         return jsonResponse($response, ["error" => "Parámetros kuuid o tipo no proporcionados"], 400);
//     }

//     // --- CONFIGURACIÓN DEL ARCHIVO (DEFINIR ANTES DE USAR) ---
//     $filename = $file->getClientFilename(); // <--- Aquí definimos el nombre
//     $format = strtoupper(pathinfo($filename, PATHINFO_EXTENSION));
//     $sizeMB = round($file->getSize() / 1048576, 2);
//     $fileContent = $file->getStream()->getContents(); // <--- Aquí extraemos el binario

//     $idFinal = $karchivos_cliente ?: generarUUIDv4(); 
//     $extension = strtolower(pathinfo($filename, PATHINFO_EXTENSION));
//     $finalPath = rtrim($uploadDir, '/') . '/' . $idFinal . '.' . $extension;

//     try {
//         $conn = conectarDB($servername, $username, $password, $dbname);

//         $sql = "INSERT INTO tblArchivos 
//                 (karchivos, kagricultor, kuuid, tipo_str, archivo_bin, formato_str, sizemb_flt, nombrearchivo_str, rutacompleta_str) 
//                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
//                 ON DUPLICATE KEY UPDATE 
//                     archivo_bin = VALUES(archivo_bin), 
//                     rutacompleta_str = VALUES(rutacompleta_str),
//                     sizemb_flt = VALUES(sizemb_flt),
//                     nombrearchivo_str = VALUES(nombrearchivo_str)";
        
//         $stmt = $conn->prepare($sql);
//         $null = null; 
        
//         // sssisssss -> 9 parámetros
//         $stmt->bind_param("ssssbsdss", 
//             $idFinal,           // 1. karchivos
//             $kagricultor,       // 2. kagricultor
//             $kuuidPadre,        // 3. kuuid
//             $tipo,              // 4. tipo_str
//             $null,              // 5. archivo_bin (Placeholder)
//             $format,            // 6. formato_str
//             $sizeMB,            // 7. sizemb_flt
//             $filename,          // 8. nombrearchivo_str
//             $finalPath          // 9. rutacompleta_str
//         );

//         $stmt->send_long_data(4, $fileContent); // Enviamos el binario real
        
//         if (!$stmt->execute()) {
//             throw new Exception("Error ejecución SQL: " . $stmt->error);
//         }
        
//         $stmt->close();
//         $conn->close();

//         // Guardar físicamente en el NAS
//         if (!file_exists($uploadDir)) { mkdir($uploadDir, 0777, true); }
//         file_put_contents($finalPath, $fileContent);

//         return jsonResponse($response, ["mensaje" => "Sincronizado", "uuid" => (string)$idFinal], 200);
        
//     } catch (Exception $e) {
//         return jsonResponse($response, ["error" => $e->getMessage()], 500);
//     }
// }

function subirArchivo(Request $request, Response $response, $servername, $username, $password, $dbname, $uploadDir): Response
{
    $uploadedFiles = $request->getUploadedFiles();
    $parsedBody = $request->getParsedBody();
    $jwt = $request->getAttribute('jwt');
    $kagricultor = $jwt->sub;
    
    if (!isset($uploadedFiles['archivo'])) {
        return jsonResponse($response, ["error" => "No se recibió el archivo"], 400);
    }

    $file = $uploadedFiles['archivo'];
    $kuuidPadre = $parsedBody['kuuid'] ?? null;
    $tipo = $parsedBody['tipo'] ?? null;
    $karchivos_cliente = $parsedBody['karchivos'] ?? null; 

    // --- DEFINICIÓN CRÍTICA DE VARIABLES ---
    $filename = $file->getClientFilename() ?? 'archivo_sin_nombre'; // <--- DEFINIR AQUÍ
    $fileContent = $file->getStream()->getContents();             // <--- DEFINIR AQUÍ
    $format = strtoupper(pathinfo($filename, PATHINFO_EXTENSION));
    $sizeMB = round($file->getSize() / 1048576, 2);

    $idFinal = $karchivos_cliente ?: generarUUIDv4(); 
    $extension = strtolower(pathinfo($filename, PATHINFO_EXTENSION));
    $finalPath = rtrim($uploadDir, '/') . '/' . $idFinal . '.' . $extension;

    try {
        $conn = conectarDB($servername, $username, $password, $dbname);

        $sql = "INSERT INTO tblArchivos 
                (karchivos, kagricultor, kuuid, tipo_str, archivo_bin, formato_str, sizemb_flt, nombrearchivo_str, rutacompleta_str) 
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE 
                    archivo_bin = VALUES(archivo_bin), 
                    rutacompleta_str = VALUES(rutacompleta_str),
                    sizemb_flt = VALUES(sizemb_flt),
                    nombrearchivo_str = VALUES(nombrearchivo_str)";
        
        $stmt = $conn->prepare($sql);
        $null = null; 
        
        $stmt->bind_param("ssssbsdss", 
            $idFinal, $kagricultor, $kuuidPadre, $tipo, 
            $null, $format, $sizeMB, $filename, $finalPath
        );

        $stmt->send_long_data(4, $fileContent); // Inyectamos el binario real
        
        $stmt->execute();
        $stmt->close();
        $conn->close();

        if (!file_exists($uploadDir)) { mkdir($uploadDir, 0777, true); }
        file_put_contents($finalPath, $fileContent);

        return jsonResponse($response, ["mensaje" => "Sincronizado", "uuid" => (string)$idFinal], 200);
        
    } catch (Exception $e) {
        return jsonResponse($response, ["error" => $e->getMessage()], 500);
    }
}
/**
 * Función auxiliar para generar UUID v4 compatible con MariaDB/MySQL
 */
function generarUUIDv4() {
    $data = random_bytes(16);
    $data[6] = chr(ord($data[6]) & 0x0f | 0x40); // versión 4
    $data[8] = chr(ord($data[8]) & 0x3f | 0x80); // variante RFC 4122
    return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($data), 4));
}