<?php
// src/operaciones.php
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

function getOperacionesV2(Request $request, Response $response): Response {
    global $servername, $username, $password, $dbname;
    try {
        $jwt = $request->getAttribute('jwt');
        $kagricultor = $jwt->sub;
        $conn = conectarDB($servername, $username, $password, $dbname);

        // AÑADIDO: kfinca en el SELECT
        $stmt = $conn->prepare("SELECT koperacion, ktipooperacion, kagricultor, kfinca, fecha_dtm, fechainicio_dtm, fechafin_dtm, descripcion_str, numpersonas_int 
                               FROM tbloperacion 
                               WHERE kagricultor = ? AND (eliminado_bit IS NULL OR eliminado_bit = 0) 
                               ORDER BY fechainicio_dtm DESC, fecha_dtm DESC");
        $stmt->bind_param("s", $kagricultor);
        $stmt->execute();
        $result = $stmt->get_result();
        $operaciones = $result->fetch_all(MYSQLI_ASSOC);
        $stmt->close();

        if (empty($operaciones)) return jsonResponse($response, []);

        $responseData = [];
        foreach ($operaciones as $op) {
            $stmtTrab = $conn->prepare("SELECT ot.koperaciontrabjador, ot.ktrabajador, ot.comentario_str, t.nombre_str 
                                       FROM tbloperaciontrabajador ot 
                                       JOIN tbltrabajador t ON ot.ktrabajador = t.ktrabajador 
                                       WHERE ot.koperacion = ? AND (ot.eliminado_bit IS NULL OR ot.eliminado_bit = 0)");
            $stmtTrab->bind_param("s", $op['koperacion']);
            $stmtTrab->execute();
            $op['trabajadores'] = $stmtTrab->get_result()->fetch_all(MYSQLI_ASSOC) ?: [];
            $stmtTrab->close();

            $stmtArch = $conn->prepare("SELECT karchivos, nombrearchivo_str, formato_str 
                                       FROM tblArchivos 
                                       WHERE kuuid = ? AND (eliminado_bit IS NULL OR eliminado_bit = 0)");
            $stmtArch->bind_param("s", $op['koperacion']);
            $stmtArch->execute();
            $op['archivos'] = $stmtArch->get_result()->fetch_all(MYSQLI_ASSOC) ?: [];
            $stmtArch->close();

            $responseData[] = $op;
        }

        $conn->close();
        return jsonResponse($response, $responseData);
    } catch (Exception $e) {
        return jsonResponse($response, ["error" => $e->getMessage()], 500);
    }
}

function mergeOperacion(Request $request, Response $response): Response {
    global $servername, $username, $password, $dbname;
    $data = json_decode($request->getBody()->getContents(), true);
    $jwt = $request->getAttribute('jwt');
    $kagricultor = $jwt->sub;

    if (!isset($data['koperacion'], $data['ktipooperacion'])) {
        return jsonResponse($response, ["error" => "Faltan datos obligatorios"], 400);
    }

    try {
        $conn = conectarDB($servername, $username, $password, $dbname);
        
        // AÑADIDO: Soporte para kfinca (puede ser null)
        $kfinca = (isset($data['kfinca']) && $data['kfinca'] !== '') ? $data['kfinca'] : null;

        $stmt = $conn->prepare("INSERT INTO tbloperacion (koperacion, ktipooperacion, kagricultor, kfinca, fechainicio_dtm, fechafin_dtm, descripcion_str, eliminado_bit) 
                                VALUES (?, ?, ?, ?, ?, ?, ?, 0) 
                                ON DUPLICATE KEY UPDATE ktipooperacion=VALUES(ktipooperacion), kfinca=VALUES(kfinca), fechainicio_dtm=VALUES(fechainicio_dtm), fechafin_dtm=VALUES(fechafin_dtm), descripcion_str=VALUES(descripcion_str)");
        $stmt->bind_param("sssssss", $data['koperacion'], $data['ktipooperacion'], $kagricultor, $kfinca, $data['fechainicio_dtm'], $data['fechafin_dtm'], $data['descripcion_str']);
        $stmt->execute();
        $stmt->close();

        $stmtDel = $conn->prepare("UPDATE tbloperaciontrabajador SET eliminado_bit = 1, fechaeliminacion_dtm = NOW() WHERE koperacion = ?");
        $stmtDel->bind_param("s", $data['koperacion']);
        $stmtDel->execute();
        $stmtDel->close();

        if (isset($data['trabajadores']) && is_array($data['trabajadores'])) {
            $stmtIns = $conn->prepare("INSERT INTO tbloperaciontrabajador (koperaciontrabjador, koperacion, ktrabajador, kagricultor, comentario_str, eliminado_bit, fechaeliminacion_dtm, fecha_dtm) 
                                       VALUES (UUID(), ?, ?, ?, '', 0, NULL, NOW())");
            foreach ($data['trabajadores'] as $idTrabajador) {
                $stmtIns->bind_param("sss", $data['koperacion'], $idTrabajador, $kagricultor);
                $stmtIns->execute();
            }
            $stmtIns->close();
        }

        $conn->close();
        return jsonResponse($response, ["mensaje" => "Operación guardada correctamente"]);
    } catch (Exception $e) {
        return jsonResponse($response, ["error" => $e->getMessage()], 500);
    }
}
?>