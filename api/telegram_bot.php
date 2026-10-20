// <?php
// telegram_bot.php
header('Content-Type: application/json');

$token = "8936272952:AAFfK0asPRWnt0mBySAW9OIy6hMj06_qeUY";
$apiUrl = "https://api.telegram.org/bot" . $token;

// Configuración de base de datos
$db_host = "192.168.1.226";
$db_user = "admin";
$db_pass = "123456789a*";
$db_name = "agri";
$conn = new mysqli($db_host, $db_user, $db_pass, $db_name);
if ($conn->connect_error) {
    die("Error DB: " . $conn->connect_error);
}

$content = file_get_contents("php://input");
$update = json_decode($content, true);

if (!isset($update["message"])) {
    exit;
}

$chat_id = $update["message"]["chat"]["id"];
$text = trim($update["message"]["text"] ?? "");

function enviarMensaje($chat_id, $texto, $apiUrl) {
    $data = [
        'chat_id' => $chat_id,
        'text' => $texto,
        'parse_mode' => 'HTML'
    ];
    $options = [
        'http' => [
            'header'  => "Content-Type: application/x-www-form-urlencoded\r\n",
            'method'  => 'POST',
            'content' => http_build_query($data)
        ]
    ];
    $context  = stream_context_create($options);
    file_get_contents($apiUrl . "/sendMessage", false, $context);
}

if (strpos($text, "/start") === 0) {
    $parts = explode(" ", $text);
    if (count($parts) > 1) {
        $codigo = trim($parts[1]);
        validarCodigo($codigo, $chat_id, $conn, $apiUrl);
    } else {
        enviarMensaje($chat_id, "<b>¡Hola!</b> 👋\nPor favor, introduce el <b>código de activación</b> de 6 dígitos proporcionado por AgriAPP.", $apiUrl);
    }
} else {
    validarCodigo($text, $chat_id, $conn, $apiUrl);
}

function validarCodigo($codigo, $chat_id, $conn, $apiUrl) {
    // Usamos tblAgricultores y sus nombres de columna correspondientes
    $stmt = $conn->prepare("SELECT kagricultor, nombre_str FROM tblAgricultores WHERE codigo_validacion_str = ? AND (validado_bit = 0 OR validado_bit IS NULL) AND (eliminado_bit IS NULL OR eliminado_bit = b'0')");
    $stmt->bind_param("s", $codigo);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($row = $result->fetch_assoc()) {
        $kagricultor = $row['kagricultor'];
        $nombre = $row['nombre_str'];

        $updateStmt = $conn->prepare("UPDATE tblAgricultores SET validado_bit = 1, codigo_validacion_str = NULL WHERE kagricultor = ?");
        $updateStmt->bind_param("s", $kagricultor);
        $updateStmt->execute();

        enviarMensaje($chat_id, "✅ <b>¡Cuenta activada con éxito!</b>\n\nHola <b>$nombre</b>, tu usuario ha sido verificado. Puedes volver a <b>AgriAPP</b> e iniciar sesión.", $apiUrl);
    } else {
        enviarMensaje($chat_id, "❌ <b>Código inválido o ya utilizado.</b>\n\nComprueba el código en AgriAPP e inténtalo de nuevo.", $apiUrl);
    }
}

$conn->close();
?>