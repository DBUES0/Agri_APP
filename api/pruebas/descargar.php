<?php
// /var/www/html/api/gastos/descargar.php
$host = '192.168.1.226';
$db   = 'testdb';
$user = 'admin';
$pass = '123456789a*';
$charset = 'utf8mb4';

$id = $_GET['id'] ?? null;
if (!$id) {
    die("Falta el parámetro ID");
}

$dsn = "mysql:host=$host;dbname=$db;charset=$charset";
$options = [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
];

try {
    $pdo = new PDO($dsn, $user, $pass, $options);

    $stmt = $pdo->prepare("SELECT descripcion, contenido FROM archivos WHERE id = ?");
    $stmt->execute([$id]);
    $archivo = $stmt->fetch();

    if ($archivo) {
        header('Content-Type: application/octet-stream');
        header('Content-Disposition: attachment; filename="archivo_'.$id.'.bin"');
        echo $archivo['contenido'];
    } else {
        echo "Archivo no encontrado.";
    }

} catch (PDOException $e) {
    echo "Error: " . $e->getMessage();
}
