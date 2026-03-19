<?php
//albaranesv2.php

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

function getAlbaranesV2(Request $request, Response $response): Response {
    global $servername, $username, $password, $dbname;

    try {
        $conn = conectarDB($servername, $username, $password, $dbname);
        $jwt = $request->getAttribute('jwt');
        $kagricultor = $jwt->sub;

        $albaranes = [];

        // Obtener cabeceras de albaranes
        $stmt = $conn->prepare("
            SELECT kalbaran, fecha_dtm, kalmacen, ktipodeprecio, comentario_str,
                   eliminado_bit, fechaeliminacion_dtm, ktipoalbaran,
                   fechadesde_dtm, fechahasta_dtm, numcampanias_int, kagricultor
            FROM tblalbaran
            WHERE kagricultor = ?
        ");
        $stmt->bind_param("s", $kagricultor);
        $stmt->execute();
        $result = $stmt->get_result();
        while ($row = $result->fetch_assoc()) {
            $kalbaran = $row['kalbaran'];

            // Obtener detalles
            $detalles = [];
            $stmtDetalle = $conn->prepare("
                SELECT kalbarandetalle, kalbaran, kfinca, linea_int, kg_float,
                       numeropallets_int, numerocajas_int, precio_flt, kproducto,
                       comentario_str, eliminado_bit, fechaeliminacion_dtm,
                       fecha_dtm, total_flt
                FROM tblalbarandetalle
                WHERE kalbaran = ?
            ");
            $stmtDetalle->bind_param("s", $kalbaran);
            $stmtDetalle->execute();
            $resDetalle = $stmtDetalle->get_result();
            while ($detalle = $resDetalle->fetch_assoc()) {
                $detalles[] = $detalle;
            }
            $stmtDetalle->close();

            // Obtener archivos
            $archivos = [];
            $stmtArchivo = $conn->prepare("
                SELECT karchivos, orden_int, fecha_dtm, formato_str, sizemb_flt,
                       comentario_str AS comentario, nombrearchivo_str, rutacompleta_str,
                       campo1_str, tipo_str, eliminado_bit, fechaeliminacion_dtm
                FROM tblArchivos
                WHERE kuuid = ?
            ");
            $stmtArchivo->bind_param("s", $kalbaran);
            $stmtArchivo->execute();
            $resArchivo = $stmtArchivo->get_result();
            while ($archivo = $resArchivo->fetch_assoc()) {
                $archivos[] = $archivo;
            }
            $stmtArchivo->close();

            $row['detalles'] = $detalles;
            $row['archivos'] = $archivos;
            $albaranes[] = $row;
        }

        $stmt->close();
        $conn->close();
        return jsonResponse($response, $albaranes);

    } catch (Exception $e) {
        return jsonResponse($response, ['error' => $e->getMessage()], 500);
    }
}
