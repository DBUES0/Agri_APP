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
function conectarDB() {
    $servername = $_ENV['DB_HOST'];
    $username   = $_ENV['DB_USER'];
    $password   = $_ENV['DB_PASS'];
    $dbname     = $_ENV['DB_NAME'];

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


function subirArchivo(Request $request, Response $response, $servername, $username, $password, $dbname, $uploadDir): Response
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

