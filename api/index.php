<?php
// index.php

require 'vendor/autoload.php';
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Psr\Http\Server\RequestHandlerInterface as RequestHandler;
use Slim\Factory\AppFactory;
use Firebase\JWT\JWT;
use Firebase\JWT\Key;


// 1. Cargar variables de entorno antes de cualquier uso
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();

// 2. Requiere tus utilidades y funciones
require_once 'src/funciones.php';
require_once 'src/mergealbaran.php';
require_once 'src/albaranesv2.php';
//asíme lo pone Gepeto: require_once __DIR__ . '/src/albaranesv2.php';

// 3. Configuración de la app y claves
$app = AppFactory::create();
$secretKey = $_ENV['JWT_SECRET'] ?? '123456789a*';  // puedes forzar aquí si lo prefieres

// 4. Registrar el middleware usando la clave correcta
$app->add(jwtMiddleware($secretKey));

//pendiente de borrar :)
$servername = $_ENV['DB_HOST'];
$username = $_ENV['DB_USER'];
$password = $_ENV['DB_PASS'];
$dbname = $_ENV['DB_NAME'];
$uploadDir = $_ENV['FILE_UPLOAD_PATH'];

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

// Funcion para usar JWTMIDDELWARE que sabe dios lo que es eso
// Reemplaza tu función jwtMiddleware con esta versión mejorada
/*function jwtMiddleware($secret)
{
    return function (Request $request, RequestHandler $handler) use ($secret) {
        $path = $request->getUri()->getPath();
        
        // Excluye rutas públicas
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
*/
//
// .:RUTAS PUBLICAS:.
//

//implementacion del login
$app->post('/api/login', function (Request $request, Response $response) use ($servername, $username, $password, $dbname) {
    $data = json_decode($request->getBody()->getContents(), true);
    
    $email = $data['email'] ?? '';
    $password_input = $data['password'] ?? '';

    if (!$email || !$password_input) {
        return jsonResponse($response, ['error' => 'Email y contraseña requeridos'], 400);
    }

    try {
        $conn = conectarDB($servername, $username, $password, $dbname);
        $stmt = $conn->prepare("SELECT kagricultor, nombre_str, password_str, bloqueado_bit, numintentos_int, ultimointentologin_dtm FROM tblAgricultores WHERE email_str = ? AND eliminado_bit = b'0'");
        $stmt->bind_param("s", $email);
        $stmt->execute();
        $stmt->store_result();

        if ($stmt->num_rows === 0) {
            return jsonResponse($response, ['error' => 'Usuario no encontrado'], 401);
        }

        $stmt->bind_result($id, $nombre, $hashedPassword, $bloqueado, $numintentos, $ultimoIntento);
        $stmt->fetch();

        $now = new DateTime();
        $ultimoIntentoDT = $ultimoIntento ? new DateTime($ultimoIntento) : null;

        if ($bloqueado == 1) {
            return jsonResponse($response, ['error' => 'Usuario bloqueado por múltiples intentos fallidos.'], 403);
        }

        if ($ultimoIntentoDT && $now->getTimestamp() - $ultimoIntentoDT->getTimestamp() < 5) {
            return jsonResponse($response, ['error' => 'Espere al menos 5 segundos antes de intentar nuevamente.'], 429);
        }

        if ($password_input !== $hashedPassword) {
            $numintentos = ($numintentos ?? 0) + 1;
            $bloqueado = ($numintentos >= 5) ? 1 : 0;

            $stmtUpdate = $conn->prepare("UPDATE tblAgricultores SET numintentos_int = ?, bloqueado_bit = ?, ultimointentologin_dtm = NOW() WHERE email_str = ?");
            $stmtUpdate->bind_param("iis", $numintentos, $bloqueado, $email);
            $stmtUpdate->execute();

            return jsonResponse($response, ['error' => 'Contraseña incorrecta'], 401);
        }

        // Resetear intentos fallidos
        $stmtReset = $conn->prepare("UPDATE tblAgricultores SET numintentos_int = 0, ultimointentologin_dtm = NOW() WHERE email_str = ?");
        $stmtReset->bind_param("s", $email);
        $stmtReset->execute();

        // Obtener todos los campos del agricultor salvo los que no queremos devolver
        $stmtUser = $conn->prepare("SELECT * FROM tblAgricultores WHERE kagricultor = ?");
        $stmtUser->bind_param("s", $id);
        $stmtUser->execute();
        $result = $stmtUser->get_result();
        $usuario = $result->fetch_assoc();
        $stmtUser->close();
        $conn->close();

        // Eliminar campos sensibles
        unset($usuario['kagricultor']);
        unset($usuario['password_str']);

        // Generar token
        $payload = [
            "iss" => "agri.api",
            "sub" => $id,
            "name" => $nombre,
            "iat" => time(),
            "exp" => time() + (60 * 60 * 24)  // 24 horas
        ];

        $jwt = JWT::encode($payload, $_ENV['JWT_SECRET'], 'HS256');

        return jsonResponse($response, [
            'token' => $jwt,
            'usuario' => $usuario
        ]);

    } catch (Exception $e) {
        return jsonResponse($response, ['error' => $e->getMessage()], 500);
    }
});



// Ruta de prueba
$app->get('/', function (Request $request, Response $response) {
    $contenido = file_get_contents(__DIR__ . '/docs/docs.html');
    $response->getBody()->write($contenido);
    return $response->withHeader('Content-Type', 'text/html');
        //return jsonResponse($response, [$contenido]);  //200 porque patatas
});

if ($_SERVER['REQUEST_URI'] === '/' || $_SERVER['REQUEST_URI'] === '/index.php') {
    header('Location: /docs.html');
    exit;
}

// Rutas Swagger
$app->get('/swagger.json', function (Request $request, Response $response) {
    $swaggerFile = __DIR__ . '/swagger.json';
    if (file_exists($swaggerFile)) {
        $response->getBody()->write(file_get_contents($swaggerFile));
        return $response->withHeader('Content-Type', 'application/json');
                //return jsonResponse($response, [file_get_contents($swaggerFile)], 200);  //200 porque patatas
    }
    //$response->getBody()->write(json_encode(["error" => "Swagger file not found"]));
    //return $response->withStatus(404)->withHeader('Content-Type', 'application/json');
        return jsonResponse($response, ["error" => "Swagger file not found"], 404);  
});


//
// .:RUTAS PRIVADAS:.
//
$app->add(jwtMiddleware($secretKey));

//desbloquear usuario
$app->post('/api/admin/unlock/{identificador}', function (Request $request, Response $response, array $args) use ($servername, $username, $password, $dbname) {
    $identificador = $args['identificador'];

    // Obtener token y verificar autenticación
//    $token = getBearerToken($request);
    $authHeader = $request->getHeaderLine('Authorization');
    if (preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
        $token = $matches[1];
    }

    // 
    $decoded = JWT::decode($token, new Key($_ENV['JWT_SECRET'], 'HS256'));

    $usuarioActual = $decoded->sub;

    // Conexión a la BD
    $conn = conectarDB($servername, $username, $password, $dbname);

    // Verificar si el usuario actual es administrador total
    $stmt = $conn->prepare("SELECT ktipodeusuario FROM tblAgricultores WHERE kagricultor = ?");
    $stmt->bind_param("s", $usuarioActual);
    $stmt->execute();
    $stmt->bind_result($ktipodeusuario);
    $stmt->fetch();
    $stmt->close();

    if ($ktipodeusuario !== 'af7a6cb3-1912-11f0-9fba-e2b6c6b4d8df') {
        return jsonResponse($response, ['error' => 'No autorizado. Solo administradores pueden desbloquear usuarios.'], 403);
    }

    // Buscar el usuario a desbloquear por identificador (uuid, email o telegram)
    $stmt = $conn->prepare("
        SELECT kagricultor 
        FROM tblAgricultores 
        WHERE kagricultor = ? OR email_str = ? OR telegramid_str = ?
    ");
    $stmt->bind_param("sss", $identificador, $identificador, $identificador);
    $stmt->execute();
    $stmt->store_result();

    if ($stmt->num_rows === 0) {
        return jsonResponse($response, ['error' => 'Usuario no encontrado'], 404);
    }

    $stmt->bind_result($kagricultorObjetivo);
    $stmt->fetch();
    $stmt->close();

    // Desbloquear usuario
    $stmt = $conn->prepare("UPDATE tblAgricultores SET bloqueado_bit = 0, numintentos_int = 0 WHERE kagricultor = ?");
    $stmt->bind_param("s", $kagricultorObjetivo);
    $stmt->execute();

    return jsonResponse($response, ['message' => "Usuario desbloqueado correctamente"]);
});



// Obtener gastos de un agricultor
//$app->get('/api/gastos/{id}', function (Request $request, Response $response, array $args) use ($servername, $username, $password, $dbname) {
 $app->get('/api/gastos[/]', function (Request $request, Response $response, array $args) use ($servername, $username, $password, $dbname) {
   try {
                $jwt = $request->getAttribute('jwt');
                $kagricultor = $jwt->sub;
    
        $conn = conectarDB($servername, $username, $password, $dbname);
        $stmt = $conn->prepare("SELECT * FROM tblFincaGastos WHERE kagricultor = ?");
        $stmt->bind_param("s", $kagricultor);
        $stmt->execute();
        $result = $stmt->get_result();
        $gastos = $result->fetch_all(MYSQLI_ASSOC);
        $stmt->close();
        $conn->close();
        //$response->getBody()->write(json_encode($gastos));
        //return $response->withHeader('Content-Type', 'application/json');
                return jsonResponse($response, $gastos);  
    } catch (Exception $e) {
        //$response->getBody()->write(json_encode(["error" => $e->getMessage()]));
        //return $response->withStatus(500)->withHeader('Content-Type', 'application/json');
                return jsonResponse($response, ["error" => $e->getMessage()], 500);  
    }
});

// Insertar un nuevo gasto
$app->post('/api/gastos[/]', function (Request $request, Response $response) use ($servername, $username, $password, $dbname) {
    $data = json_decode($request->getBody()->getContents(), true);

	$jwt = $request->getAttribute('jwt');
	$kagricultor = $jwt->sub;

	if (!isset($data['importe'], $data['concepto'], $data['campo4'])) {
		return jsonResponse($response, ["error" => "Faltan datos."], 400);
	}
	$kfinca = $data['kfinca'] ?? null;
	$ktipogasto = $data['ktipogasto'] ?? null;
	$numcampanias_flt = $data['numcampanias_flt'] ?? 1;

	try {
		$conn = conectarDB($servername, $username, $password, $dbname);

		// Insertar el nuevo gasto usando UUID() de MySQL
		$stmt = $conn->prepare("INSERT INTO tblFincaGastos (kfincagastos, kagricultor, importe_flt, concepto_str, campo4, kfinca, ktipogasto, numcampanias_flt) VALUES (UUID(), ?, ?, ?, ?, ?, ?, ?)");
		$stmt->bind_param("sdsssss", $kagricultor, $data['importe'], $data['concepto'], $data['campo4'], $kfinca, $ktipogasto, $numcampanias_flt);
		$stmt->execute();
		$stmt->close();

		// Obtener el kfincagastos del nuevo registro
		$stmt2 = $conn->prepare("SELECT kfincagastos FROM tblFincaGastos WHERE kagricultor = ? ORDER BY fecha_dtm DESC LIMIT 1");
		$stmt2->bind_param("s", $kagricultor);  //Usamos prepared statement
		$stmt2->execute();
		$result = $stmt2->get_result();
		$row = $result->fetch_assoc();
		$kfincagastos = $row['kfincagastos'];
		$stmt2->close();
		$conn->close();

		return jsonResponse($response, [
			"mensaje" => "Nuevo gasto insertado correctamente",
			"kfincagastos" => $kfincagastos
		]);
	} catch (Exception $e) {
		return jsonResponse($response, ["error" => $e->getMessage()], 500);
	}
});
// Insertar una nueva cabecera de albaran
// Insertar una nueva cabecera de albaran corregida
$app->post('/api/albarancabecera[/]', function (Request $request, Response $response) use ($servername, $username, $password, $dbname) {
    $data = json_decode($request->getBody()->getContents(), true);
    $jwt = $request->getAttribute('jwt');
    $kagricultor = $jwt->sub;
    
    $kalmacen = $data['kalmacen'] ?? null;  
    $ktipoprecio = $data['ktipodeprecio'] ?? null;  
    $comentario = $data['comentario_str'] ?? null;  
    $kfecha = $data['fecha_dtm'] ?? date('Y-m-d');
    // NUEVOS CAMPOS RECIBIDOS DESDE FLUTTER
    $ktipoalbaran = $data['ktipoalbaran'] ?? 'b42f149b-6744-11f0-ac9b-e2b6c6b4d8df'; 
    $idalbaran_str = $data['idalbaran_str'] ?? '';
    $archivos_ids = $data['archivos_ids'] ?? []; // Recibimos los IDs desde Flutter

    try {
        $conn = conectarDB($servername, $username, $password, $dbname);
        
        // 1. Insertar Cabecera (Tu código actual)
        $stmt = $conn->prepare("INSERT INTO tblalbaran(kagricultor, fecha_dtm, kalmacen, ktipodeprecio, comentario_str, ktipoalbaran, idalbaran_str) VALUES (?, ?, ?, ?, ?, ?, ?)");
        $stmt->bind_param("sssssss", $kagricultor, $kfecha, $kalmacen, $ktipoprecio, $comentario, $ktipoalbaran, $idalbaran_str);
        $stmt->execute();

        // 2. Obtener el kalbaran recién creado
        $kalbaran = $conn->insert_id; // Si es auto-increment
        // Si usas UUID, mejor tu consulta actual:
        $uuidStmt = $conn->prepare("SELECT kalbaran FROM tblalbaran WHERE kagricultor = ? ORDER BY fecha_dtm DESC LIMIT 1");
        $uuidStmt->bind_param("s", $kagricultor);
        $uuidStmt->execute();
        $uuidStmt->bind_result($kalbaran);
        $uuidStmt->fetch();
        $uuidStmt->close();

        // 3. VINCULAR ARCHIVOS (NUEVO)
        if (!empty($archivos_ids)) {
            foreach ($archivos_ids as $id_archivo) {
                // Suponiendo que tblArchivos tiene una columna 'kalbaran' para relacionarlos
                // O una tabla intermedia. Aquí lo asociamos directamente:
                $updateArchivos = $conn->prepare("UPDATE tblArchivos SET kuuid = ? WHERE karchivos = ? AND kagricultor = ?");
                $updateArchivos->bind_param("sss", $kalbaran, $id_archivo, $kagricultor);
                $updateArchivos->execute();
                $updateArchivos->close();
            }
        }

        $conn->close();
        return jsonResponse($response, ["mensaje" => "Cabecera y archivos vinculados", "kalbaran" => $kalbaran]);
        
    } catch (Exception $e) {
        return jsonResponse($response, ["error" => $e->getMessage()], 500);
    }
});

//     try {
//         $conn = conectarDB($servername, $username, $password, $dbname);
        
//         // INSERT actualizado con 7 campos para cumplir con las restricciones de la BBDD
//         $stmt = $conn->prepare("INSERT INTO tblalbaran(kagricultor, fecha_dtm, kalmacen, ktipodeprecio, comentario_str, ktipoalbaran, idalbaran_str) VALUES (?, ?, ?, ?, ?, ?, ?)");
        
//         $stmt->bind_param("sssssss", $kagricultor, $kfecha, $kalmacen, $ktipoprecio, $comentario, $ktipoalbaran, $idalbaran_str);
        
//         if (!$stmt->execute()) {
//             throw new Exception("Error al ejecutar la consulta: " . $stmt->error);
//         }
        
//         $uuidStmt = $conn->prepare("SELECT kalbaran FROM tblalbaran WHERE kagricultor = ? ORDER BY fecha_dtm DESC LIMIT 1");
//         $uuidStmt->bind_param("s", $kagricultor);
//         $uuidStmt->execute();
//         $uuidStmt->bind_result($kalbaran);
//         $uuidStmt->fetch();
//         $uuidStmt->close();
//         $conn->close();
        
//         return jsonResponse($response, [
//             "mensaje" => "Cabecera de albarán creada correctamente",
//             "kalbaran" => $kalbaran
//         ]);
        
//     } catch (Exception $e) {
//         return jsonResponse($response, ["error" => "Error al procesar el albarán", "detalle" => $e->getMessage()], 500);
//     }
// });

/* Antiguo
$app->post('/api/albarancabecera[/]', function (Request $request, Response $response) use ($servername, $username, $password, $dbname) {
    $data = json_decode($request->getBody()->getContents(), true);

        $jwt = $request->getAttribute('jwt');
        $kagricultor = $jwt->sub;
    
    //if (!isset($data['kagricultor'])) {
    //    return jsonResponse($response, ["error" => "Faltan datos."], 400);  
    //}
    
    $kalmacen = $data['kalmacen'] ?? null;  
    $ktipoprecio = $data['ktipodeprecio'] ?? null;  
    $comentario = $data['comentario_str'] ?? null;  
    //$kfecha = $data['kfecha'] ?? date('Y-m-d'); // Valor por defecto si no se envía
    $kfecha = $data['fecha_dtm'] ?? date('Y-m-d'); // Valor por defecto si no se env  a

    try {
        $conn = conectarDB($servername, $username, $password, $dbname);
        
        // CORRECCIÓN PRINCIPAL: Paréntesis cerrado correctamente
        $stmt = $conn->prepare("INSERT INTO tblalbaran(kagricultor, fecha_dtm, kalmacen, ktipodeprecio, comentario_str) VALUES (?, ?, ?, ?, ?)");
        
        $stmt->bind_param("sssss", $kagricultor, $kfecha, $kalmacen, $ktipoprecio, $comentario);
        
        if (!$stmt->execute()) {
            throw new Exception("Error al ejecutar la consulta: " . $stmt->error);
        }
        
        $nuevoId = $conn->insert_id;
        $stmt->close();

                $uuidStmt = $conn->prepare("SELECT kalbaran FROM tblalbaran WHERE kagricultor = ? ORDER BY fecha_dtm DESC LIMIT 1");
        $uuidStmt->bind_param("s", $kagricultor);
        $uuidStmt->execute();
        $uuidStmt->bind_result($kalbaran);
        $uuidStmt->fetch();
        $uuidStmt->close();

        $conn->close();
        
        return jsonResponse($response, [
            "mensaje" => "Cabecera de albarán creada correctamente",
            "kalbaran" => $kalbaran,
            "nuevoid" => $kalbaran
        ]);
        
    } catch (Exception $e) {
        error_log("Error en albarancabecera: " . $e->getMessage());
        return jsonResponse($response, [
            "error" => "Error al procesar el albarán",
            "detalle" => $e->getMessage()
        ], 500);
    }
});
*/
// Insertar un nuevo detalle de albarán
// Insertar un nuevo detalle de albarán (Corregido para total_flt)
$app->post('/api/albarandetalles[/]', function (Request $request, Response $response) use ($servername, $username, $password, $dbname) {
    $data = json_decode($request->getBody()->getContents(), true);
    $jwt = $request->getAttribute('jwt');
    $kagricultor = $jwt->sub;

    if (!isset($data['kalbaran'], $data['kg_float'], $data['kproducto'])) {
        return jsonResponse($response, ["error" => "Faltan campos obligatorios"], 400);
    }

    try {
        $conn = conectarDB($servername, $username, $password, $dbname);

        // Calculamos el total aquí por si el trigger de la BBDD falla o la columna es estricta
        $kg = floatval($data['kg_float']);
        $precio = isset($data['precio_flt']) ? floatval($data['precio_flt']) : 0;
        $total = $kg * $precio; //

        $stmt = $conn->prepare("INSERT INTO tblalbarandetalle 
                              (kagricultor, kalbaran, kg_float, numeropallets_int, numerocajas_int, precio_flt, kproducto, comentario_str, kfinca, total_flt) 
                              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");

        $numeropallets = $data['numeropallets_int'] ?? 0;
        $numerocajas = $data['numerocajas_int'] ?? 0;
        $comentario = $data['comentario_str'] ?? '';
        $kfinca = $data['kfinca'] ?? null;

        // Se añade la "d" final para el campo total_flt (double/float)
        $stmt->bind_param("ssdiidsssd",
            $kagricultor,
            $data['kalbaran'],
            $kg,
            $numeropallets,
            $numerocajas,
            $precio,
            $data['kproducto'],
            $comentario,
            $kfinca,
            $total
        );

        if (!$stmt->execute()) {
            throw new Exception("Error al insertar detalle: " . $stmt->error);
        }
        
        // ... (resto del código para devolver el detalle creado)
        $stmt->close();
        $conn->close();

        return jsonResponse($response, ["mensaje" => "Detalle creado correctamente"], 201);

    } catch (Exception $e) {
        return jsonResponse($response, ["error" => $e->getMessage()], 500);
    }
});
/* Antiguo
$app->post('/api/albarandetalles[/]', function (Request $request, Response $response) use ($servername, $username, $password, $dbname) {
    $data = json_decode($request->getBody()->getContents(), true);

    // Obtener kagricultor del JWT
    $jwt = $request->getAttribute('jwt');
    $kagricultor = $jwt->sub;

    // Validación de campos obligatorios
    if (!isset($data['kalbaran'], $data['kg_float'], $data['kproducto'])) {
        return jsonResponse($response, ["error" => "Faltan campos obligatorios (kalbaran, kg_float, kproducto)"], 400);
    }

    try {
        $conn = conectarDB($servername, $username, $password, $dbname);

        // El trigger se encargará del autonumérico de línea
        $stmt = $conn->prepare("INSERT INTO tblalbarandetalle 
                              (kagricultor, kalbaran, kg_float, numeropallets_int, numerocajas_int, precio_flt, kproducto, comentario_str,kfinca) 
                              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");

        // Asignamos valores a variables primero
        $numeropallets = $data['numeropallets_int'] ?? null;
        $numerocajas = $data['numerocajas_int'] ?? null;
        $precio = $data['precio_flt'] ?? null;
        $comentario = $data['comentario_str'] ?? null;

        // Corregir tipos: numeropallets_int y numerocajas_int son enteros (i)
        $stmt->bind_param("ssdiidsss",
            $kagricultor,
            $data['kalbaran'],
            $data['kg_float'],
            $numeropallets,
            $numerocajas,
            $precio,
            $data['kproducto'],
            $comentario,
            $data['kfinca']
        );

        if (!$stmt->execute()) {
            throw new Exception("Error al insertar detalle: " . $stmt->error);
        }

        $stmt->close();

        // Obtener el kalbarandetalle del registro recién creado
        $stmt = $conn->prepare("SELECT kalbarandetalle FROM tblalbarandetalle 
                               WHERE kalbaran = ? AND kagricultor = ? 
                               ORDER BY linea_int DESC LIMIT 1");
        $stmt->bind_param("ss", $data['kalbaran'], $kagricultor);
        $stmt->execute();
        $stmt->bind_result($kalbarandetalle);
        $stmt->fetch();
        $stmt->close();

        if (!$kalbarandetalle) {
            throw new Exception("No se encontró el detalle recién creado");
        }

        // Obtener el detalle completo
        $stmt = $conn->prepare("SELECT tblalbarandetalle.* 
                               FROM tblalbarandetalle 
                               WHERE kalbarandetalle = ? AND kagricultor = ?");
        $stmt->bind_param("ss", $kalbarandetalle, $kagricultor);
        $stmt->execute();
        $result = $stmt->get_result();
        $detalle = $result->fetch_assoc();

        $stmt->close();
        $conn->close();

        if (!$detalle) {
            throw new Exception("No se encontró el detalle completo");
        }

        return jsonResponse($response, [
            "mensaje" => "Detalle de albarán creado correctamente",
            "detalle" => $detalle
        ], 201);

    } catch (Exception $e) {
        if (isset($conn) && $conn) {
            $conn->close();
        }
        return jsonResponse($response, ["error" => $e->getMessage()], 500);
    }
});
*/

// Obtener detalles de un albarán
$app->get('/api/albarandetalles/{kalbaran}', function (Request $request, Response $response, array $args) use ($servername, $username, $password, $dbname) {
    try {

        $jwt = $request->getAttribute('jwt');
        $kagricultor = $jwt->sub;
    
        $conn = conectarDB($servername, $username, $password, $dbname);
        //$stmt = $conn->prepare("SELECT * FROM tblalbarandetalle WHERE kalbaran = ? ORDER BY linea_int");
                //$stmt = $conn->prepare("SELECT tblalbarandetalle.* FROM tblalbarandetalle, tblalbaran WHERE kalbaran = ?  and tblalbaran.kalbaran = tblalbarandetalle.kalbaran and tblalbaran.kagricultor= ?  ORDER BY linea_int"
        $stmt = $conn->prepare("SELECT tblalbarandetalle.* FROM tblalbarandetalle, tblalbaran WHERE tblalbarandetalle.kalbaran = ? AND tblalbaran.kalbaran = tblalbarandetalle.kalbaran AND tblalbaran.kagricultor = ? ORDER BY linea_int");
                $stmt->bind_param("ss", $args['kalbaran'], $kagricultor);
        $stmt->execute();
        $result = $stmt->get_result();
        $detalles = $result->fetch_all(MYSQLI_ASSOC);
        
        if (empty($detalles)) {
            return jsonResponse($response, ["error" => "No se encontraron detalles para el albarán especificado"], 404);
        }
        
        $stmt->close();
        $conn->close();
        
        return jsonResponse($response, $detalles);
        
    } catch (Exception $e) {
        if (isset($conn) && $conn) {
            $conn->close();
        }
        return jsonResponse($response, ["error" => $e->getMessage()], 500);
    }
});

// ENDPOINT GENÉRICO: Listar vista por agricultor (protegida por JWT)
$app->get('/api/productos', function (Request $request, Response $response, array $args) use ($servername, $username, $password, $dbname) {
    $jwt = $request->getAttribute('jwt');
    $kagricultor = $jwt->sub;
    $conn = conectarDB($servername, $username, $password, $dbname);
    //$stmt = $conn->prepare("SELECT * FROM `$tabla` WHERE kagricultor = ? AND (eliminado_bit IS NULL OR eliminado_bit = b'0')");
    $stmt = $conn->prepare("SELECT 
                tp.kproducto, 
                tp.producto_str, 
                MAX(ta.fecha_dtm) AS ufecha_ultimo_uso_dtm,
                tp.ktipoproducto,
                ttp.descripcion_str as tipoproducto_str
            FROM tblproducto tp
            LEFT JOIN tblalbarandetalle tad ON tp.kproducto = tad.kproducto
            LEFT JOIN tblalbaran ta ON tad.kalbaran = ta.kalbaran 
                AND ta.kagricultor = ?
            inner join tbltipoproducto ttp on tp.ktipoproducto = ttp.ktipoproducto
            WHERE (tp.eliminado_bit IS NULL OR tp.eliminado_bit = b'0')
            GROUP BY tp.kproducto, tp.producto_str, tp.ktipoproducto
            ORDER BY 
                MAX(ta.fecha_dtm) IS NULL ASC, 
                MAX(ta.fecha_dtm) DESC, 
                tp.producto_str ASC;");
    $stmt->bind_param("s", $kagricultor);
    $stmt->execute();
    $result = $stmt->get_result();
    $datos = $result->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    return jsonResponse($response, $datos);
});

// Obtener todos los albaranes de un agricultor con sus detalles y archivos
$app->get('/api/albaranes[/]', function (Request $request, Response $response) use ($servername, $username, $password, $dbname) {
    try {
        // Obtener kagricultor del JWT
        $jwt = $request->getAttribute('jwt');
        $kagricultor = $jwt->sub;

        $conn = conectarDB($servername, $username, $password, $dbname);

        // Obtener todos los albaranes del agricultor
        $stmt = $conn->prepare("SELECT kalbaran, fecha_dtm, kalmacen, ktipodeprecio, comentario_str,idalbaran_str
                               FROM tblalbaran 
                               WHERE kagricultor = ? AND (eliminado_bit IS NULL OR eliminado_bit = 0) 
                               ORDER BY fecha_dtm DESC");
        $stmt->bind_param("s", $kagricultor);
        $stmt->execute();
        $result = $stmt->get_result();
        $albaranes = $result->fetch_all(MYSQLI_ASSOC);
        $stmt->close();

        // Si no hay albaranes, devolver un array vacío en lugar de un error
        if (empty($albaranes)) {
            return jsonResponse($response, []);
        }

        // Para cada albarán, obtener sus detalles
        $responseData = [];
        foreach ($albaranes as $albaran) {
            // Obtener detalles del albarán
            $stmt = $conn->prepare("SELECT * FROM tblalbarandetalle 
                                   WHERE kalbaran = ? AND kagricultor = ? AND (eliminado_bit IS NULL OR eliminado_bit = 0) 
                                   ORDER BY linea_int");
            $stmt->bind_param("ss", $albaran['kalbaran'], $kagricultor);
            $stmt->execute();
            $result = $stmt->get_result();
            $detalles = $result->fetch_all(MYSQLI_ASSOC);
            $stmt->close();

            // Obtener archivos asociados al albarán
            $stmt = $conn->prepare("SELECT karchivos ,kagricultor,kuuid,orden_int,fecha_dtm,formato_str,sizemb_flt,comentario_str,nombrearchivo_str,rutacompleta_str,campo1_str,tipo_str FROM tblArchivos 
                                    WHERE kuuid = ? AND kagricultor = ? AND (eliminado_bit IS NULL OR eliminado_bit = 0) 
                                    ORDER BY fecha_dtm");
            $stmt->bind_param("ss", $albaran['kalbaran'], $kagricultor);
            $stmt->execute();
            $result = $stmt->get_result();
            $archivos = $result->fetch_all(MYSQLI_ASSOC);
            $stmt->close();

            // Asegurarse de que los detalles y archivos son arrays, incluso si están vacíos
            $albaran['detalles'] = $detalles ?: [];
            $albaran['archivos'] = $archivos ?: [];
            $responseData[] = $albaran;
        }

        $conn->close();

        // Asegurarse de que siempre devolvemos un array
        return jsonResponse($response, $responseData ?: []);

    } catch (Exception $e) {
        if (isset($conn) && $conn) {
            $conn->close();
        }
        error_log("Error en /api/albaranes: " . $e->getMessage());
        return jsonResponse($response, ["error" => "Error al procesar la solicitud"], 500);
    }
});

// Obtener todos los albaranes de un agricultor con sus detalles y archivos, pero en un nuevo formato con todos los campos nuevos
$app->get('/api/albaranesv2', function (Request $request, Response $response) {
    return getAlbaranesV2($request, $response);
});

// Insertar o actualizar un albarán y sus detalles.
$app->post('/api/mergealbaran', function (Request $request, Response $response) {
    return mergeAlbaran($request, $response);
});

//Inserta un nuevo archivo en la BBDD y en el NAS
$app->post('/api/archivo', function (Request $request, Response $response) use ($servername, $username, $password, $dbname, $uploadDir) {
    return subirArchivo($request, $response, $servername, $username, $password, $dbname, $uploadDir);
});

// Descargar archivo por ID de la BBDD
$app->get('/api/gastos/descargararchivo/{id}', function (Request $request, Response $response, array $args) use ($servername, $username, $password, $dbname) {
    try {

                $jwt = $request->getAttribute('jwt');
                $kagricultor = $jwt->sub;
    
        $conn = conectarDB($servername, $username, $password, $dbname);
        $stmt = $conn->prepare("SELECT archivo_bin, formato_str, nombrearchivo_str FROM tblArchivos WHERE karchivos = ? and kagricultor = ?");
        $stmt->bind_param("ss", $args['id'], $kagricultor);
        $stmt->execute();
        $stmt->store_result();
        if ($stmt->num_rows === 0) {
            $stmt->close();
            $conn->close();
            //$response->getBody()->write(json_encode(["error" => "Archivo no encontrado."]));
            //return $response->withStatus(404)->withHeader('Content-Type', 'application/json');
                        return jsonResponse($response,["error" => "Archivo no encontrado."],404);  
        }
        $stmt->bind_result($archivoBin, $formato, $nombreArchivo);
        $stmt->fetch();
        $stmt->close();
        $conn->close();
        $downloadName = $nombreArchivo ?: "archivo_{$args['id']}.$formato";
        //return $response
        //    ->withHeader('Content-Type', 'application/octet-stream')
        //    ->withHeader('Content-Disposition', 'attachment; filename="' . $downloadName . '"')
        //    ->withHeader('Content-Length', strlen($archivoBin))
                //      ->withHeader('X-Content-Type-Options', 'nosniff')
        //    ->write($archivoBin);
                //
                $body = $response->getBody();
                $body->write($archivoBin);
                return $response
                ->withHeader('Content-Type', 'application/octet-stream')
                ->withHeader('Content-Disposition', 'attachment; filename="' . $downloadName . '"')
                ->withHeader('Content-Length', strlen($archivoBin))
                ->withHeader('X-Content-Type-Options', 'nosniff');

    } catch (Exception $e) {
        //return $response->withStatus(500)->withHeader('Content-Type', 'application/json')
        //    ->write(json_encode(["error" => $e->getMessage()]));
                return jsonResponse($response,["error" => $e->getMessage()],500);  
    }
});


// Descargar archivo por ID desde ruta en NAS - Versión definitiva
$app->get('/api/gastos/descargararchivonas/{id}', function (Request $request, Response $response, array $args) use ($servername, $username, $password, $dbname, $uploadDir) {


        $jwt = $request->getAttribute('jwt');
    $kagricultor = $jwt->sub;
    
    try {
        // Primero obtenemos la ruta de la base de datos
        $conn = conectarDB($servername, $username, $password, $dbname);
        $stmt = $conn->prepare("SELECT rutacompleta_str, formato_str, nombrearchivo_str FROM tblArchivos WHERE karchivos = ? and kagricultor = ? ");
        $stmt->bind_param("ss", $args['id'], $kagricultor);
        $stmt->execute();
        $stmt->store_result();
        
        if ($stmt->num_rows === 0) {
            $stmt->close();
            $conn->close();
            //$response->getBody()->write(json_encode(["error" => "Archivo no encontrado en la base de datos."]));
            //return $response->withStatus(404)->withHeader('Content-Type', 'application/json');
                        return jsonResponse($response,["error" => "Archivo no encontrado en la base de datos."],404);  
        }
        
        $stmt->bind_result($rutaCompleta, $formato, $nombreArchivo);
        $stmt->fetch();
        $stmt->close();
        $conn->close();
        
        // Ahora validamos la ruta
        $basePath = realpath($uploadDir);
        $rutaAbsoluta = realpath($rutaCompleta);
        
        if ($rutaAbsoluta === false || strpos($rutaAbsoluta, $basePath) !== 0) {
            //$response->getBody()->write(json_encode(["error" => "Ruta de archivo no permitida.", "detalle" => "El archivo no está dentro del directorio permitido."]));
            //return $response->withStatus(403)->withHeader('Content-Type', 'application/json');
            return jsonResponse($response,["error" => "Ruta de archivo no permitida.", "detalle" => "El archivo no está dentro del directorio permitido."],403);
        }
        
        // Verificar que la ruta existe
        if (!file_exists($rutaAbsoluta)) {
            //$response->getBody()->write(json_encode(["error" => "Archivo no encontrado en la ruta especificada."]));
            //return $response->withStatus(404)->withHeader('Content-Type', 'application/json');
            return jsonResponse($response,["error" => "Archivo no encontrado en la ruta especificada."],404);  
        }
        
        $downloadName = $nombreArchivo ?: "archivo_{$args['id']}.$formato";
        
        // Usar readfile() para mejor manejo de memoria con archivos grandes
        $response = $response
            ->withHeader('Content-Type', 'application/octet-stream')
            ->withHeader('Content-Disposition', 'attachment; filename="' . $downloadName . '"')
            ->withHeader('Content-Length', filesize($rutaAbsoluta))
            ->withHeader('X-Content-Type-Options', 'nosniff');
        
        // Abrir el archivo y enviarlo directamente al output
        $file = fopen($rutaAbsoluta, 'rb');
        $stream = new \Slim\Psr7\Stream($file);
        return $response->withBody($stream);
            
    } catch (Exception $e) {
        $response->getBody()->write(json_encode([
            "error" => $e->getMessage(),
            "trace" => $e->getTraceAsString()
        ]));
        return $response
            ->withStatus(500)
            ->withHeader('Content-Type', 'application/json');
    }
});

//crear finca
$app->post('/api/crearfinca[/]', function (Request $request, Response $response) use ($servername, $username, $password, $dbname) {
    $data = json_decode($request->getBody()->getContents(), true);

        $jwt = $request->getAttribute('jwt');
    $kagricultor = $jwt->sub;
    
    if (!isset($data['nombre_str'])) {
        return jsonResponse($response, ["error" => "Falta el nombre de la finca"], 400);
    }

    try {
        $conn = conectarDB($servername, $username, $password, $dbname);
        $stmt = $conn->prepare("INSERT INTO tblfinca 
            (kfincapadre, nombre_str, descripcion_str, kagricultor, Ubicacion_str, aream2_float, campo1_str, campo2_str) 
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)");

        $descripcion_str        = $data['descripcion_str']  ?? null;
        $kfincapadre            = $data['kfincapadre']      ?? null;
        $ubicacion              = $data['Ubicacion_str']    ?? null;
        $aream2                 = $data['aream2_float']     ?? null;
        $campo1                 = $data['campo1_str']       ?? null;
        $campo2                 = $data['campo2_str']       ?? null;

        $stmt->bind_param(
            "sssssdss",
            $kfincapadre,
            $data['nombre_str'],
            $descripcion_str,
            $kagricultor,
            $ubicacion,
            $aream2,
            $campo1,
            $campo2
        );
        $stmt->execute();
        $stmt->close();

                //Obtenemos el ultimo registro de finca creado para este agricultor
                $uuidStmt = $conn->prepare("SELECT kfinca FROM tblfinca WHERE kagricultor = ? ORDER BY fecha DESC LIMIT 1");
        $uuidStmt->bind_param("s", $kagricultor);
        $uuidStmt->execute();
        $uuidStmt->bind_result($kfinca);
        $uuidStmt->fetch();
        $uuidStmt->close();

        $conn->close();

        return jsonResponse($response, ["mensaje" => "Finca creada correctamente", "kfinca" => $kfinca]);
    } catch (Exception $e) {
        return jsonResponse($response, ["error" => $e->getMessage()], 500);
    }
});

// Modificar finca Corregir para solo modificar los campos entregados
$app->put('/api/finca[/]', function (Request $request, Response $response) use ($servername, $username, $password, $dbname) {
    $data = json_decode($request->getBody()->getContents(), true);

        $jwt = $request->getAttribute('jwt');
    $kagricultor = $jwt->sub;
    
        if (!isset($data['kfinca'])) {
        return jsonResponse($response, ["error" => "Faltan kfinca"], 400);
    }

    try {
        $conn = conectarDB($servername, $username, $password, $dbname);
        $stmt = $conn->prepare("UPDATE tblfinca SET 
            kfincapadre = ?, nombre_str = ?, descripcion_str = ?, Ubicacion_str = ?, aream2_float = ?, campo1_str = ?, campo2_str = ?
            WHERE kfinca = ? AND kagricultor = ?");

        $stmt->bind_param(
            "sssssdsss",
            $data['kfincapadre'], $data['nombre_str'], $data['descripcion_str'],
            $data['Ubicacion_str'], $data['aream2_float'], $data['campo1_str'], $data['campo2_str'],
            $data['kfinca'], $kagricultor
        );
        $stmt->execute();
        $stmt->close();
        $conn->close();

        return jsonResponse($response, ["mensaje" => "Finca modificada correctamente"]);
    } catch (Exception $e) {
        return jsonResponse($response, ["error" => $e->getMessage()], 500);
    }
});

// Eliminar una finca
$app->delete('/api/finca/{kfinca}[/]', function (Request $request, Response $response, array $args) use ($servername, $username, $password, $dbname) {
//$app->delete('/api/finca/{kfinca}[/]' Response $response, array $args) use ($servername, $username, $password, $dbname) {
        $jwt = $request->getAttribute('jwt');
    $kagricultor = $jwt->sub;
    try {
        $conn = conectarDB($servername, $username, $password, $dbname);
        $stmt = $conn->prepare("DELETE FROM tblfinca WHERE kfinca = ? AND kagricultor = ?");
        $stmt->bind_param("ss", $args['kfinca'],$kagricultor);
        $stmt->execute();
        $stmt->close();
        $conn->close();

        return jsonResponse($response, ["mensaje" => "Finca eliminada correctamente"]);
    } catch (Exception $e) {
        return jsonResponse($response, ["error" => $e->getMessage()], 500);
    }
});

//Listar fincas
$app->get('/api/fincas', function (Request $request, Response $response) use ($servername, $username, $password, $dbname) {
    $jwt = $request->getAttribute('jwt');
    $kagricultor = $jwt->sub;

    try {
        $conn = conectarDB($servername, $username, $password, $dbname);
        $stmt = $conn->prepare("SELECT * FROM tblfinca WHERE kagricultor = ?");
        $stmt->bind_param("s", $kagricultor);
        $stmt->execute();
        $result = $stmt->get_result();
        $fincas = $result->fetch_all(MYSQLI_ASSOC);
        $stmt->close();
        $conn->close();

        return jsonResponse($response, $fincas);
    } catch (Exception $e) {
        return jsonResponse($response, ["error" => $e->getMessage()], 500);
    }
});

//Listado de trabajadores activos a fecha de ahora.
$app->get('/api/trabajadores/activos[/]', function (Request $request, Response $response, array $args) use ($servername, $username, $password, $dbname) {

        $jwt = $request->getAttribute('jwt');
    $kagricultor = $jwt->sub;

    $query = "SELECT t.* FROM tbltrabajadores t
              JOIN tbltrabajadoraltas a ON t.ktrabajador = a.ktrabajador
              WHERE t.kagricultor = ? AND t.eliminado_bit = b'0' AND (a.fechafin_dtm IS NULL OR a.fechafin_dtm > NOW())";
    $conn = conectarDB($servername, $username, $password, $dbname);
    $stmt = $conn->prepare($query);
    $stmt->bind_param("s", $kagricultor);
    $stmt->execute();
    $result = $stmt->get_result();
    return jsonResponse($response, $result->fetch_all(MYSQLI_ASSOC));
});

//Listado de trabajadores activos a una fecha dada.
$app->get('/api/trabajadores/activos/{fecha}', function (Request $request, Response $response, array $args) use ($servername, $username, $password, $dbname) {

        $jwt = $request->getAttribute('jwt');
    $kagricultor = $jwt->sub;

    $query = "SELECT t.* FROM tbltrabajadores t
              JOIN tbltrabajadoraltas a ON t.ktrabajador = a.ktrabajador
              WHERE t.kagricultor = ? AND t.eliminado_bit = b'0'
              AND a.fechainicio_dtm <= ? AND (a.fechafin_dtm IS NULL OR a.fechafin_dtm > ?)";
    $conn = conectarDB($servername, $username, $password, $dbname);
    $stmt = $conn->prepare($query);
    $stmt->bind_param("sss", $kagricultor, $args['fecha'], $args['fecha']);
    $stmt->execute();
    $result = $stmt->get_result();
    return jsonResponse($response, $result->fetch_all(MYSQLI_ASSOC));
});

// ENDPOINT GENÉRICO: Listar tabla por agricultor (protegida por JWT)
$app->get('/api/listar/{tabla}', function (Request $request, Response $response, array $args) use ($servername, $username, $password, $dbname) {
    $tabla = $args['tabla'];
    $jwt = $request->getAttribute('jwt');
    $kagricultor = $jwt->sub;

        $tablasPermitidas = ['tblagricultores','tblalbaran','tblalbarandetalle','tblalmacen','tblaltatrabajador','tblArchivos','tblfinca','tblfincagastos','tbljornada','tblnota','tbloperacion','tbltrabajador']; // etc.
        if (!in_array($args['tabla'], $tablasPermitidas)) {
                return jsonResponse($response, ["error" => "Tabla no permitida"], 403);
        }
        $conn = conectarDB($servername, $username, $password, $dbname);
    $stmt = $conn->prepare("SELECT * FROM `$tabla` WHERE kagricultor = ? AND (eliminado_bit IS NULL OR eliminado_bit = b'0')");
    $stmt->bind_param("s", $kagricultor);
    $stmt->execute();
    $result = $stmt->get_result();
    $datos = $result->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    return jsonResponse($response, $datos);
});

// ENDPOINT GENÉRICO: Listar vista por agricultor (protegida por JWT)
$app->get('/api/vista/{tabla}', function (Request $request, Response $response, array $args) use ($servername, $username, $password, $dbname) {
    $tabla = $args['tabla'];
    $jwt = $request->getAttribute('jwt');
    $kagricultor = $jwt->sub;

        $tablasPermitidas = ['vfincas']; // etc.
        if (!in_array($args['tabla'], $tablasPermitidas)) {
                return jsonResponse($response, ["error" => "Tabla no permitida"], 403);
        }
        $conn = conectarDB($servername, $username, $password, $dbname);
    $stmt = $conn->prepare("SELECT * FROM `$tabla` WHERE kagricultor = ?");
    $stmt->bind_param("s", $kagricultor);
    $stmt->execute();
    $result = $stmt->get_result();
    $datos = $result->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    return jsonResponse($response, $datos);
});


// ENDPOINT GENÉRICO: Listar tabla sin restricción por agricultor (tablas comunes)
$app->get('/api/listarcomun/{tabla}', function (Request $request, Response $response, array $args) use ($servername, $username, $password, $dbname) {
    $tabla = $args['tabla'];

    // Lista blanca de tablas común
    $tablasComunes = [
        'tblproducto', 'tbltipodeprecio', 'tbltipogasto', 'tbltipooperacion', 'tbltiposdeusuario'
    ];

    if (!in_array($tabla, $tablasComunes)) {
        return jsonResponse($response, ["error" => "Tabla no permitida para listado común"], 403);
    }
        $conn = conectarDB($servername, $username, $password, $dbname);
    $stmt = $conn->prepare("SELECT * FROM `$tabla` WHERE (eliminado_bit IS NULL OR eliminado_bit = b'0')");
    $stmt->execute();
    $result = $stmt->get_result();
    $datos = $result->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    return jsonResponse($response, $datos);
});

//edicion generica de cualquier tabla siempre que el ID primario de la tabla sea el mismo que el nombre de la tabla pero sustituyendo tbl -> k
$app->put('/api/editar/{tabla}/{id}', function (Request $request, Response $response, array $args) use ($servername, $username, $password, $dbname) {
    $tabla = $args['tabla'];
    $id = $args['id'];
    $clavePrimaria = 'k' . strtolower(preg_replace('/^tbl/i', '', $tabla));  // Asume claves primarias como ktabla

    $jwt = $request->getAttribute('jwt');
    $kagricultor = $jwt->sub;

    $data = json_decode($request->getBody()->getContents(), true);
    if (!$data || !is_array($data)) {
        return jsonResponse($response, ["error" => "Datos inválidos"], 400);
    }

    try {
        $conn = conectarDB($servername, $username, $password, $dbname);

        // Verificar que el registro le pertenece al agricultor
        $stmt = $conn->prepare("SELECT 1 FROM $tabla WHERE $clavePrimaria = ? AND kagricultor = ?");
        $stmt->bind_param("ss", $id, $kagricultor);
        $stmt->execute();
        $stmt->store_result();
        if ($stmt->num_rows === 0) {
            return jsonResponse($response, ["error" => "No autorizado o no encontrado"], 403);
        }
        $stmt->close();

        // Construir dinámicamente el SET de los campos
        $campos = [];
        $valores = [];
        $tipos = '';

        foreach ($data as $clave => $valor) {
            if ($clave === $clavePrimaria || $clave === 'kagricultor') {
                continue; // No se puede editar ID ni agricultor
            }
            $campos[] = "$clave = ?";
            $valores[] = $valor;
            $tipos .= is_int($valor) ? 'i' : (is_float($valor) ? 'd' : 's');
        }

        if (empty($campos)) {
            return jsonResponse($response, ["error" => "No hay campos editables enviados"], 400);
        }

        $sql = "UPDATE $tabla SET " . implode(', ', $campos) . " WHERE $clavePrimaria = ?";
        $stmt = $conn->prepare($sql);
        $tipos .= 's'; // Añadir tipo para el ID
        $valores[] = $id;

        $stmt->bind_param($tipos, ...$valores);
        $stmt->execute();
        $stmt->close();
        $conn->close();

        return jsonResponse($response, ["mensaje" => "Registro actualizado correctamente"]);
    } catch (Exception $e) {
        return jsonResponse($response, ["error" => $e->getMessage()], 500);
    }
});

//borrado generico de cualquier tabla siempre que el ID primario de la tabla sea el mismo que el nombre de la tabla pero sustituyendo tbl -> k
$app->delete('/api/eliminar/{tabla}/{id}', function (Request $request, Response $response, array $args) use ($servername, $username, $password, $dbname) {
    $tabla = $args['tabla'];
    $id = $args['id'];
    $clavePrimaria = 'k' . strtolower(preg_replace('/^tbl/i', '', $tabla));  // Asume claves primarias como ktabla

    $jwt = $request->getAttribute('jwt');
    $kagricultor = $jwt->sub;

    try {
        $conn = conectarDB($servername, $username, $password, $dbname);

        // Validar existencia y propiedad del registro
        $stmt = $conn->prepare("SELECT 1 FROM $tabla WHERE $clavePrimaria = ? AND kagricultor = ?");
        $stmt->bind_param("ss", $id, $kagricultor);
        $stmt->execute();
        $stmt->store_result();
        if ($stmt->num_rows === 0) {
            return jsonResponse($response, ["error" => "No autorizado o no encontrado"], 403);
        }
        $stmt->close();

        // Ejecutar borrado lógico
        $now = date('Y-m-d H:i:s');
        $stmt = $conn->prepare("UPDATE $tabla SET eliminado_bit = b'1', fechaeliminacion_dtm = ? WHERE $clavePrimaria = ?");
        $stmt->bind_param("ss", $now, $id);
        $stmt->execute();
        $stmt->close();
        $conn->close();

        return jsonResponse($response, ["mensaje" => "Registro marcado como eliminado"]);
    } catch (Exception $e) {
        return jsonResponse($response, ["error" => $e->getMessage()], 500);
    }
});

//creación de un generico de cualquier tabla siempre que el ID primario de la tabla sea el mismo que el nombre de la tabla pero sustituyendo tbl -> k
$app->post('/api/crear/{tabla}', function (Request $request, Response $response, array $args) use ($servername, $username, $password, $dbname) {
    $tabla = $args['tabla'];
    $data = json_decode($request->getBody()->getContents(), true);
    $jwt = $request->getAttribute('jwt');
    $kagricultor = $jwt->sub;

    // Prohibir insertar directamente en tblAgricultores
    if (strtolower($tabla) === 'tblagricultores') {
        return jsonResponse($response, ["error" => "No está permitido insertar registros en esta tabla."], 403);
    }

    try {
        $conn = conectarDB($servername, $username, $password, $dbname);

        // Obtener columnas válidas de la tabla
        $columnsResult = $conn->query("SHOW COLUMNS FROM `$tabla`");
        if (!$columnsResult) {
            throw new Exception("Tabla '$tabla' no encontrada o error al acceder.");
        }

        $allowedColumns = [];
        while ($col = $columnsResult->fetch_assoc()) {
            $allowedColumns[] = $col['Field'];
        }

        // Insertar automáticamente el kagricultor
        $data['kagricultor'] = $kagricultor;

        // Filtrar solo columnas existentes
        $insertData = array_intersect_key($data, array_flip($allowedColumns));
        if (empty($insertData)) {
            throw new Exception("No se proporcionaron columnas válidas para insertar.");
        }

        $columns = implode(", ", array_keys($insertData));
        $placeholders = implode(", ", array_fill(0, count($insertData), "?"));
        $values = array_values($insertData);

        // Preparar tipos para bind_param
        $types = str_repeat("s", count($values)); // por simplicidad asumimos todo como string

        $stmt = $conn->prepare("INSERT INTO `$tabla` ($columns) VALUES ($placeholders)");
        $stmt->bind_param($types, ...$values);
        $stmt->execute();

        $insertedId = $conn->insert_id;
        $stmt->close();

                // Obtener nombre de la columna UUID primaria: k + nombre sin "tbl"
                $primaryKey = 'k' . strtolower(preg_replace('/^tbl/', '', $tabla));

                // Buscar el último UUID insertado para este agricultor
                $uuidStmt = $conn->prepare("SELECT `$primaryKey` FROM `$tabla` WHERE kagricultor = ? ORDER BY fecha_dtm DESC LIMIT 1");
                $uuidStmt->bind_param("s", $kagricultor);
                $uuidStmt->execute();
                $uuidStmt->bind_result($uuid);
                $uuidStmt->fetch();
                $uuidStmt->close();


        $conn->close();

                return jsonResponse($response, [
                        "mensaje" => "Registro insertado correctamente",
                        "tabla" => $tabla,
                        "uuid" => $uuid
                ]);
    } catch (Exception $e) {
        return jsonResponse($response, ["error" => $e->getMessage()], 500);
    }
});

// Listado de operaciones para un agricultor. Habría que revisar porqué se repite la cabecera siempre...
$app->get('/api/operaciones', function (Request $request, Response $response) use ($servername, $username, $password, $dbname) {
    $jwt = $request->getAttribute('jwt');
    $kagricultor = $jwt->sub;

    try {
        $conn = conectarDB($servername, $username, $password, $dbname);

        $query = "
        SELECT o.*, 
               a.karchivos, a.nombrearchivo_str, a.formato_str, 
               t.ktrabajador, t.nombre_str
        FROM tbloperacion o
        LEFT JOIN tblArchivos a ON a.kuuid = o.koperacion AND a.eliminado_bit = b'0'
        LEFT JOIN tbloperaciontrabajador ot ON ot.koperacion = o.koperacion AND ot.eliminado_bit = b'0'
        LEFT JOIN tbltrabajador t ON t.ktrabajador = ot.ktrabajador
        WHERE o.kagricultor = ?
        ORDER BY o.fecha_dtm DESC";

        $stmt = $conn->prepare($query);
        $stmt->bind_param("s", $kagricultor);
        $stmt->execute();
        $result = $stmt->get_result();
        $operaciones = $result->fetch_all(MYSQLI_ASSOC);
        $stmt->close();
        $conn->close();

        return jsonResponse($response, $operaciones);
    } catch (Exception $e) {
        return jsonResponse($response, ['error' => $e->getMessage()], 500);
    }
});

// Listado de operaciones para un agricultor entre dos fechas. Habría que revisar porqué se repite la cabecera siempre...
$app->get('/api/operaciones/{desde}/{hasta}', function (Request $request, Response $response, array $args) use ($servername, $username, $password, $dbname) {
    $jwt = $request->getAttribute('jwt');
    $kagricultor = $jwt->sub;

    $desde = $args['desde'];
    $hasta = $args['hasta'];

    try {
        $conn = conectarDB($servername, $username, $password, $dbname);

        $query = "
        SELECT o.*, 
               a.karchivos, a.nombrearchivo_str, a.formato_str, 
               t.ktrabajador, t.nombre_str
        FROM tbloperacion o
        LEFT JOIN tblArchivos a ON a.kuuid = o.koperacion AND a.eliminado_bit = b'0'
        LEFT JOIN tbloperaciontrabajador ot ON ot.koperacion = o.koperacion AND ot.eliminado_bit = b'0'
        LEFT JOIN tbltrabajador t ON t.ktrabajador = ot.ktrabajador
        WHERE o.kagricultor = ? AND o.fecha_dtm BETWEEN ? AND ?
        ORDER BY o.fecha_dtm DESC";

        $stmt = $conn->prepare($query);
        $stmt->bind_param("sss", $kagricultor, $desde, $hasta);
        $stmt->execute();
        $result = $stmt->get_result();
        $operaciones = $result->fetch_all(MYSQLI_ASSOC);
        $stmt->close();
        $conn->close();

        return jsonResponse($response, $operaciones);
    } catch (Exception $e) {
        return jsonResponse($response, ['error' => $e->getMessage()], 500);
    }
});

//Insertar jornada
$app->post('/api/trabajadores/insertarjornada', function (Request $request, Response $response) use ($servername, $username, $password, $dbname) {
    $jwt = $request->getAttribute('jwt');
    $kagricultor = $jwt->sub;
    $data = json_decode($request->getBody()->getContents(), true);

    $ktrabajador = $data['ktrabajador'] ?? null;
    $fecha = $data['fecha'] ?? date('Y-m-d');

    if (!$ktrabajador) {
        return jsonResponse($response, ["error" => "Falta el campo ktrabajador"], 400);
    }

    try {
        $conn = conectarDB($servername, $username, $password, $dbname);

        $check = $conn->prepare("SELECT COUNT(*) FROM tbljornada WHERE ktrabajador = ? AND fecha_dtm = ? AND eliminado_bit = b'0'");
        $check->bind_param("ss", $ktrabajador, $fecha);
        $check->execute();
        $check->bind_result($existe);
        $check->fetch();
        $check->close();

        if ($existe > 0) {
            return jsonResponse($response, ["error" => "Ya existe una jornada para este trabajador en esa fecha"], 409);
        }

        $stmt = $conn->prepare("INSERT INTO tbljornada (ktrabajador, kagricultor, fecha_dtm) VALUES (?, ?, ?)");
        $stmt->bind_param("sss", $ktrabajador, $kagricultor, $fecha);
        $stmt->execute();
        $stmt->close();
        $conn->close();

        return jsonResponse($response, ["mensaje" => "Jornada insertada correctamente"]);
    } catch (Exception $e) {
        return jsonResponse($response, ["error" => $e->getMessage()], 500);
    }
});


$app->run();
