<?php
// notas.php

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;


// Obtener todas las notas de un agricultor con sus archivos adjuntos
//$app->get('/api/notas', function (Request $request, Response $response) use ($servername, $username, $password, $dbname) {

function getNotas(Request $request, Response $response): Response {
    global $servername, $username, $password, $dbname;

    try {
        $jwt = $request->getAttribute('jwt');
        $kagricultor = $jwt->sub;

        $conn = conectarDB($servername, $username, $password, $dbname);

        // 1. Obtener todas las notas del agricultor
        $stmt = $conn->prepare("SELECT knota, kagricultor, titulo_str, nota_str, fecha_dtm 
                               FROM tblnota 
                               WHERE kagricultor = ? AND (eliminado_bit IS NULL OR eliminado_bit = 0) 
                               ORDER BY fecha_dtm DESC");
        $stmt->bind_param("s", $kagricultor);
        $stmt->execute();
        $result = $stmt->get_result();
        $notas = $result->fetch_all(MYSQLI_ASSOC);
        $stmt->close();

        if (empty($notas)) {
            return jsonResponse($response, []);
        }

        // 2. Para cada nota, obtener sus archivos asociados (sin el BLOB)
        $responseData = [];
        foreach ($notas as $nota) {
            $stmtArchivos = $conn->prepare("SELECT karchivos, kagricultor, kuuid, orden_int, fecha_dtm, formato_str, sizemb_flt, comentario_str, nombrearchivo_str, rutacompleta_str, campo1_str, tipo_str 
                                           FROM tblArchivos 
                                           WHERE kuuid = ? AND kagricultor = ? AND (eliminado_bit IS NULL OR eliminado_bit = 0) 
                                           ORDER BY fecha_dtm");
            $stmtArchivos->bind_param("ss", $nota['knota'], $kagricultor);
            $stmtArchivos->execute();
            $resultArchivos = $stmtArchivos->get_result();
            $archivos = $resultArchivos->fetch_all(MYSQLI_ASSOC);
            $stmtArchivos->close();

            // Insertamos el array de archivos dentro de la nota
            $nota['archivos'] = $archivos ?: [];
            $responseData[] = $nota;
        }

        $conn->close();
        return jsonResponse($response, $responseData);

    } catch (Exception $e) {
        if (isset($conn) && $conn) {
            $conn->close();
        }
        return jsonResponse($response, ["error" => "Error al cargar notas: " . $e->getMessage()], 500);
    }
};

?>