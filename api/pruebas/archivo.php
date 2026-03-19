<?php
// /var/www/html/api/gastos/archivo

header('Content-Type: application/json');

if (!isset($_FILES['archivo']) || !isset($_POST['descripcion'])) {
    echo json_encode(["error" => "Faltan datos o archivo no enviado."]);
    http_response_code(400);
    exit;
}

$descripcion = $_POST['descripcion'];
$archivo = $_FILES['archivo'];

if ($archivo['error'] !== UPLOAD_ERR_OK) {
    echo json_encode(["error" => "Error al subir el archivo."]);
    http_response_code(400);
    exit;
}

// Carpeta destino
$carpetaDestino = __DIR__ . "/uploads/";
if (!file_exists($carpetaDestino)) {
    mkdir($carpetaDestino, 0777, true);
}

$nombreFinal = $carpetaDestino . basename($archivo['name']);
if (!move_uploaded_file($archivo['tmp_name'], $nombreFinal)) {
    echo json_encode(["error" => "No se pudo mover el archivo."]);
    http_response_code(500);
    exit;
}

echo json_encode([
    "mensaje" => "Archivo subido correctamente",
    "nombre" => $archivo['name'],
    "descripcion" => $descripcion
]);


$host = '192.168.1.226';
$db   = 'testdb';
$user = 'admin';
$pass = '123456789a*';
$charset = 'utf8mb4';

// Validar que se hayan enviado los datos y el archivo
if (!isset($_POST['descripcion']) || !isset($_FILES['archivo'])) {
    echo json_encode(['error' => 'Faltan datos o archivo no enviado.']);
    exit;
}

// Recoger datos
$descripcion = $_POST['descripcion'];
$archivo_tmp = $_FILES['archivo']['tmp_name'];
$contenido = file_get_contents($archivo_tmp);

// Crear conexión a la base de datos
$dsn = "mysql:host=$host;dbname=$db;charset=$charset";
$options = [
    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
];

try {
    $pdo = new PDO($dsn, $user, $pass, $options);

    // Insertar en base de datos
    $stmt = $pdo->prepare("INSERT INTO archivos (descripcion, contenido) VALUES (?, ?)");
    $stmt->bindParam(1, $descripcion);
    $stmt->bindParam(2, $contenido, PDO::PARAM_LOB);
    $stmt->execute();

    echo json_encode(['success' => true, 'id' => $pdo->lastInsertId()]);
} catch (PDOException $e) {
    echo json_encode(['error' => $e->getMessage()]);
}
