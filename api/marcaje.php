<?php
// marcaje.php
require 'vendor/autoload.php';

// Cargar variables de entorno para usar la misma BBDD que la API
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();

$mensaje = '';
$esExito = false;

// Leer los parámetros (vienen por GET en la URL o por POST al enviar el formulario)
$finca = $_GET['finca'] ?? ($_POST['finca'] ?? '');
$dni = $_GET['dni'] ?? ($_POST['dni'] ?? '');
$comentario = $_GET['comentario'] ?? ($_POST['comentario'] ?? '');

// Procesar el formulario cuando el trabajador pulsa el botón
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $password_input = $_POST['password'] ?? '';
    $lat = $_POST['lat'] ?? null;
    $lon = $_POST['lon'] ?? null;

    if (empty($finca) || empty($dni) || empty($password_input)) {
        $mensaje = "Faltan datos obligatorios.";
    } else {
        try {
            // Conexión a BBDD usando tus variables de entorno
            $conn = new mysqli($_ENV['DB_HOST'], $_ENV['DB_USER'], $_ENV['DB_PASS'], $_ENV['DB_NAME']);
            if ($conn->connect_error) throw new Exception("Error de conexión a la base de datos.");

            // 1. Buscar el ID del Agricultor (Finca)
            $stmtFinca = $conn->prepare("SELECT kagricultor FROM tblAgricultores WHERE nombrefincamarcaje_str = ? AND eliminado_bit = b'0'");
            $stmtFinca->bind_param("s", $finca);
            $stmtFinca->execute();
            $resFinca = $stmtFinca->get_result();

            if ($resFinca->num_rows === 0) {
                throw new Exception("Empresa/Finca no encontrada.");
            }
            $kagricultor = $resFinca->fetch_assoc()['kagricultor'];
            $stmtFinca->close();

            // 2. Buscar el Trabajador y su clave
            $stmtTrabajador = $conn->prepare("SELECT ktrabajador, password_str FROM tbltrabajador WHERE kagricultor = ? AND dni_str = ? AND eliminado_bit = b'0'");
            $stmtTrabajador->bind_param("ss", $kagricultor, $dni);
            $stmtTrabajador->execute();
            $resTrabajador = $stmtTrabajador->get_result();

            if ($resTrabajador->num_rows === 0) {
                throw new Exception("Trabajador no encontrado o inactivo.");
            }
            $rowTrabajador = $resTrabajador->fetch_assoc();
            $ktrabajador = $rowTrabajador['ktrabajador'];
            $hash_guardado = $rowTrabajador['password_str'];
            $stmtTrabajador->close();

            // 3. Verificar Contraseña
            //if (!password_verify($password_input, $hash_guardado)) {
            if ($password_input !== $hash_guardado) {
                // NOTA: Si guardas las claves en texto plano, usa: if ($password_input !== $hash_guardado)
                throw new Exception("Contraseña incorrecta.");
            }

            // 4. Insertar el Marcaje (fechamarcaje_dtm se autogenera)

            if (strlen($comentario) < 3) {
                $stmtInsert = $conn->prepare("INSERT INTO tblmarcaje (kmarcaje, kagricultor, ktrabajador, tipodemarcaje_str, latitud_dec, longitud_dec) VALUES (UUID(), ?, ?, 'Web', ?, ?)");
                $stmtInsert->bind_param("ssdd", $kagricultor, $ktrabajador, $lat, $lon);
            } else {
                $stmtInsert = $conn->prepare("INSERT INTO tblmarcaje (kmarcaje, kagricultor, ktrabajador, tipodemarcaje_str, latitud_dec, longitud_dec, comentarios_str) VALUES (UUID(), ?, ?, 'Web', ?, ?, ?)");
                $stmtInsert->bind_param("ssdds", $kagricultor, $ktrabajador, $lat, $lon, $comentario);
            }

            $stmtInsert->execute();
            $stmtInsert->close();
            //$stmtInsert = $conn->prepare("INSERT INTO tblmarcaje (kmarcaje, kagricultor, ktrabajador, tipodemarcaje_str, latitud_dec, longitud_dec, comentario_str) VALUES (UUID(), ?, ?, 'Web', ?, ?, ?)");
            // Enlazar doubles (d) para lat y lon
            
            $mensaje = "¡Marcaje registrado correctamente!";
            $esExito = true;

        } catch (Exception $e) {
            $mensaje = $e->getMessage();
        } finally {
            if (isset($conn)) $conn->close();
        }
    }
}
?>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Fichar - AgriAPP</title>
    <!-- FUENTES OFICIALES DE AGRIAPP -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Lato:wght@700;900&family=Roboto:wght@400;500;700&display=swap" rel="stylesheet">
    
    <link rel="stylesheet" href="src/css/estilos.css">
</head>
<body>

<div class="login-container">
<!-- Contenedor del Logo integrado -->
<!-- Icono limpio sin marco forzado -->
    <div class="logo-wrapper">
        <img src="src/images/icontransparent.png" alt="AgriAPP" class="logo-img">
    </div>

    <!-- Título y subtítulo -->
    <div class="brand-title">Agri<span>APP</span></div>
    <div class="subtitle">Registro de Jornada</div>

    <?php if ($mensaje): ?>
        <div id="mensaje" class="<?= $esExito ? 'success' : 'error' ?>"><?= htmlspecialchars($mensaje) ?></div>
        <br>
    <?php endif; ?>

    <form id="marcajeForm" method="POST" action="">
        <!-- Campos visibles pero bloqueados -->
        <div class="input-group">
            <label>Empresa / Finca</label>
            <input type="text" name="finca" value="<?= htmlspecialchars($finca) ?>" readonly>
        </div>
        <div class="input-group">
            <label>DNI del Trabajador</label>
            <input type="text" name="dni" value="<?= htmlspecialchars($dni) ?>" readonly>
        </div>
        
        <!-- Campo para la clave -->
        <div class="input-group">
            <label>Contraseña</label>
            <input type="password" id="password" name="password" placeholder="Introduce tu contraseña" required <?= $esExito ? 'disabled' : '' ?>>
        </div>

        <div class="input-group">
            <label>Comentario</label>
            <input type="text" name="comentario" value="<?= htmlspecialchars($comentario) ?>">
        </div>

        <!-- Campos ocultos para el GPS -->
        <input type="hidden" id="lat" name="lat">
        <input type="hidden" id="lon" name="lon">

        <?php if (!$esExito): ?>
            <button type="submit" id="btnFichar" class="btn-submit">FICHAR AHORA</button>
        <?php endif; ?>
    </form>
</div>

<script src="src/js/marcaje.js" defer></script>

</body>
</html>