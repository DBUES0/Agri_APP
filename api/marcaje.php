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
            $stmtInsert = $conn->prepare("INSERT INTO tblmarcaje (kmarcaje, kagricultor, ktrabajador, tipodemarcaje_str, latitud_dec, longitud_dec) VALUES (UUID(), ?, ?, 'Web', ?, ?)");
            // Enlazar doubles (d) para lat y lon
            $stmtInsert->bind_param("ssdd", $kagricultor, $ktrabajador, $lat, $lon);
            $stmtInsert->execute();
            $stmtInsert->close();

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
    <style>
        body { font-family: 'Segoe UI', sans-serif; background-color: #f4f7f6; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
        .login-container { background-color: #ffffff; padding: 40px; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.1); width: 100%; max-width: 350px; text-align: center; }
        .logo { font-size: 40px; color: #2E7D32; margin-bottom: 5px; }
        .title { color: #333; font-size: 18px; margin-bottom: 30px; }
        .input-group { margin-bottom: 20px; text-align: left; }
        .input-group label { display: block; font-size: 13px; color: #666; margin-bottom: 5px; font-weight: bold; }
        .input-group input { width: 100%; padding: 12px; border: 1px solid #ccc; border-radius: 8px; box-sizing: border-box; font-size: 15px; }
        .input-group input[readonly] { background-color: #f9f9f9; color: #555; }
        .input-group input:not([readonly]):focus { border-color: #2E7D32; outline: none; }
        .btn-submit { background-color: #2E7D32; color: white; border: none; padding: 14px; width: 100%; border-radius: 8px; font-size: 16px; font-weight: bold; cursor: pointer; }
        .btn-submit:disabled { background-color: #9e9e9e; cursor: not-allowed; }
        #mensaje { margin-top: 15px; font-size: 14px; font-weight: bold; }
        .success { color: #2E7D32; }
        .error { color: #d32f2f; }
    </style>
</head>
<body>

<div class="login-container">
    <div class="logo">🌿</div>
    <div class="title">Registro de Jornada</div>

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

        <!-- Campos ocultos para el GPS -->
        <input type="hidden" id="lat" name="lat">
        <input type="hidden" id="lon" name="lon">

        <?php if (!$esExito): ?>
            <button type="submit" id="btnFichar" class="btn-submit">FICHAR AHORA</button>
        <?php endif; ?>
    </form>
</div>

<script>
    const form = document.getElementById('marcajeForm');
    const btnFichar = document.getElementById('btnFichar');

    form.addEventListener('submit', function(e) {
        // Pausamos el envío para capturar el GPS primero
        e.preventDefault();
        btnFichar.disabled = true;
        btnFichar.innerText = 'Obteniendo ubicación...';

        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                (position) => {
                    document.getElementById('lat').value = position.coords.latitude;
                    document.getElementById('lon').value = position.coords.longitude;
                    form.submit(); // GPS obtenido, enviamos a PHP
                },
                (error) => {
                    // Si el usuario deniega el GPS, enviamos el formulario igualmente sin coordenadas
                    form.submit();
                }
            );
        } else {
            form.submit(); // Navegador sin soporte GPS
        }
    });
</script>

</body>
</html>