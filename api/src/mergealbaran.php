<?php
// mergealbaran.php

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

function mergeAlbaran(Request $request, Response $response): Response {

    global $servername, $username, $password, $dbname;

    $conn = conectarDB($servername, $username, $password, $dbname);

    $jwt = $request->getAttribute('jwt');
    $kagricultor = $jwt->sub;

    // $input = json_decode($request->getBody()->getContents(), true);

    // if (!$input || !isset($input[0])) {
    //     return jsonResponse($response, ["error" => "JSON vacío o malformado"], 400);
    // }

    // $albaran = $input[0];
    $input = json_decode($request->getBody()->getContents(), true);

    if (!$input) {
        return jsonResponse($response, ["error" => "JSON vacío o malformado"], 400);
    }

    // Si viene como objeto directo o como array de un elemento
    $albaran = isset($input[0]) ? $input[0] : $input;

    $albaran['kagricultor'] = $kagricultor;

    $conn->begin_transaction();

    try {

        //--------------------------------------------------
        // 1. CABECERA
        //--------------------------------------------------

        $stmt = $conn->prepare("SELECT COUNT(*) FROM tblalbaran WHERE kalbaran=?");
        $stmt->bind_param("s", $albaran["kalbaran"]);
        $stmt->execute();
        $stmt->bind_result($existsCount);
        $stmt->fetch();
        $stmt->close();

        $exists = $existsCount > 0;

        if ($exists) {

            $sql = "UPDATE tblalbaran SET 
                    fecha_dtm=?,
                    kalmacen=?,
                    ktipodeprecio=?,
                    comentario_str=?,
                    eliminado_bit=?,
                    fechaeliminacion_dtm=?,
                    ktipoalbaran=?,
                    fechadesde_dtm=?,
                    fechahasta_dtm=?,
                    numcampanias_int=?,
                    idalbaran_str=?
                    WHERE kalbaran=?";

            $stmt = $conn->prepare($sql);

            //print_r($albaran["idalbaran_str"]);
            $stmt->bind_param(
                "ssssissssiss",
                $albaran["fecha_dtm"],
                $albaran["kalmacen"],
                $albaran["ktipodeprecio"],
                $albaran["comentario_str"],
                $albaran["eliminado_bit"],
                $albaran["fechaeliminacion_dtm"],
                $albaran["ktipoalbaran"],
                $albaran["fechadesde_dtm"],
                $albaran["fechahasta_dtm"],
                $albaran["numcampanias_int"],
                $albaran["idalbaran_str"],
                $albaran["kalbaran"]
            );

        } else {

            $sql = "INSERT INTO tblalbaran
            (kalbaran,fecha_dtm,kalmacen,ktipodeprecio,comentario_str,
             eliminado_bit,fechaeliminacion_dtm,ktipoalbaran,
             fechadesde_dtm,fechahasta_dtm,numcampanias_int,kagricultor,idalbaran_str)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?, ?)";

            $stmt = $conn->prepare($sql);

            $stmt->bind_param(
                "sssssissssiss",
                $albaran["kalbaran"],
                $albaran["fecha_dtm"],
                $albaran["kalmacen"],
                $albaran["ktipodeprecio"],
                $albaran["comentario_str"],
                $albaran["eliminado_bit"],
                $albaran["fechaeliminacion_dtm"],
                $albaran["ktipoalbaran"],
                $albaran["fechadesde_dtm"],
                $albaran["fechahasta_dtm"],
                $albaran["numcampanias_int"],
                $kagricultor,
                $albaran["idalbaran_str"]
            );
        }

        if (!$stmt->execute()) {
            throw new Exception($stmt->error);
        }

        $stmt->close();

        //--------------------------------------------------
        // 2. BORRADO EN CASCADA
        //--------------------------------------------------

        if ($albaran["eliminado_bit"]) {

            $fecha = $albaran["fechaeliminacion_dtm"];
            $kalbaran = $albaran["kalbaran"];

            $stmt = $conn->prepare(
                "UPDATE tblalbarandetalle 
                 SET eliminado_bit=1, fechaeliminacion_dtm=? 
                 WHERE kalbaran=?"
            );

            $stmt->bind_param("ss", $fecha, $kalbaran);
            $stmt->execute();
            $stmt->close();

            $stmt = $conn->prepare(
                "UPDATE tblArchivos 
                 SET eliminado_bit=1, fechaeliminacion_dtm=? 
                 WHERE kuuid=?"
            );

            $stmt->bind_param("ss", $fecha, $kalbaran);
            $stmt->execute();
            $stmt->close();
        }

        //--------------------------------------------------
        // 3. DETALLES
        //--------------------------------------------------

        if (!isset($albaran["detalles"])) {
            $albaran["detalles"] = [];
        }

        foreach ($albaran["detalles"] as $detalle) {

            // valores seguros
            $detalle["precio_flt"] = $detalle["precio_flt"] ?? 0;
            $detalle["total_flt"] = $detalle["total_flt"] ?? 0;
            $detalle["numeropallets_int"] = $detalle["numeropallets_int"] ?? 0;
            $detalle["numerocajas_int"] = $detalle["numerocajas_int"] ?? 0;
            $detalle["kg_float"] = $detalle["kg_float"] ?? 0;

            //--------------------------------------------------

            $stmt = $conn->prepare(
                "SELECT COUNT(*) FROM tblalbarandetalle 
                 WHERE kalbarandetalle=?"
            );

            $stmt->bind_param("s", $detalle["kalbarandetalle"]);
            $stmt->execute();
            $stmt->bind_result($existsCount);
            $stmt->fetch();
            $stmt->close();

            $exists = $existsCount > 0;

            //--------------------------------------------------

            if ($exists) {

                $sql = "UPDATE tblalbarandetalle SET
                        kfinca=?,
                        linea_int=?,
                        kg_float=?,
                        numeropallets_int=?,
                        numerocajas_int=?,
                        precio_flt=?,
                        kproducto=?,
                        comentario_str=?,
                        eliminado_bit=?,
                        fechaeliminacion_dtm=?,
                        fecha_dtm=?,
                        total_flt=?
                        WHERE kalbarandetalle=?";

                $stmt = $conn->prepare($sql);

                $stmt->bind_param(
                    "sidiidssissds",
                    $detalle["kfinca"],
                    $detalle["linea_int"],
                    $detalle["kg_float"],
                    $detalle["numeropallets_int"],
                    $detalle["numerocajas_int"],
                    $detalle["precio_flt"],
                    $detalle["kproducto"],
                    $detalle["comentario_str"],
                    $detalle["eliminado_bit"],
                    $detalle["fechaeliminacion_dtm"],
                    $detalle["fecha_dtm"],
                    $detalle["total_flt"],
                    $detalle["kalbarandetalle"]
                );

            } else {

                $sql = "INSERT INTO tblalbarandetalle
                (kalbarandetalle,kalbaran,kfinca,linea_int,kg_float,
                 numeropallets_int,numerocajas_int,precio_flt,kproducto,
                 comentario_str,eliminado_bit,fechaeliminacion_dtm,
                 fecha_dtm,kagricultor,total_flt)
                VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)";

                $stmt = $conn->prepare($sql);

                $stmt->bind_param(
                    "sssidiidssisssd",
                    $detalle["kalbarandetalle"],
                    $albaran["kalbaran"],
                    $detalle["kfinca"],
                    $detalle["linea_int"],
                    $detalle["kg_float"],
                    $detalle["numeropallets_int"],
                    $detalle["numerocajas_int"],
                    $detalle["precio_flt"],
                    $detalle["kproducto"],
                    $detalle["comentario_str"],
                    $detalle["eliminado_bit"],
                    $detalle["fechaeliminacion_dtm"],
                    $detalle["fecha_dtm"],
                    $kagricultor,
                    $detalle["total_flt"]
                );

            }

            if (!$stmt->execute()) {
                throw new Exception($stmt->error);
            }

            $stmt->close();
        }

         // 2. DETALLES
        foreach ($albaran["detalles"] as $detalle) {
            $detalle["precio_flt"] = $detalle["precio_flt"] ?? 0;
            $detalle["total_flt"] = $detalle["total_flt"] ?? 0;

            $stmt = $conn->prepare("SELECT COUNT(*) FROM tblalbarandetalle WHERE kalbarandetalle = ?");
            $stmt->bind_param("s", $detalle["kalbarandetalle"]);
            $stmt->execute();
            $stmt->bind_result($dExistsCount);
            $stmt->fetch();
            $stmt->close();

            if ($dExistsCount > 0) {
                // UPDATE: 13 campos + 1 del WHERE = 14 parámetros
                $sql = "UPDATE tblalbarandetalle SET kfinca=?, linea_int=?, kg_float=?, numeropallets_int=?, numerocajas_int=?, precio_flt=?, kproducto=?, comentario_str=?, eliminado_bit=?, fechaeliminacion_dtm=?, fecha_dtm=?, total_flt=? WHERE kalbarandetalle=?";
                $stmt = $conn->prepare($sql);
                $stmt->bind_param(
                    "sidiidssissds", // 13 caracteres
                    $detalle["kfinca"],
                    $detalle["linea_int"],
                    $detalle["kg_float"],
                    $detalle["numeropallets_int"],
                    $detalle["numerocajas_int"],
                    $detalle["precio_flt"],
                    $detalle["kproducto"],
                    $detalle["comentario_str"],
                    $detalle["eliminado_bit"],
                    $detalle["fechaeliminacion_dtm"],
                    $detalle["fecha_dtm"],
                    $detalle["total_flt"],
                    $detalle["kalbarandetalle"]
                );
            } else {
                // INSERT: 15 campos = 15 parámetros
                $sql = "INSERT INTO tblalbarandetalle (kalbarandetalle, kalbaran, kfinca, linea_int, kg_float, numeropallets_int, numerocajas_int, precio_flt, kproducto, comentario_str, eliminado_bit, fechaeliminacion_dtm, fecha_dtm, kagricultor, total_flt) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
                $stmt = $conn->prepare($sql);
                
                // CORRECCIÓN: Añadida la 'd' final para total_flt y la variable correspondiente
                $stmt->bind_param(
                    "ssidiidssissdsd", // 15 caracteres
                    $detalle["kalbarandetalle"],
                    $albaran["kalbaran"],
                    $detalle["kfinca"],
                    $detalle["linea_int"],
                    $detalle["kg_float"],
                    $detalle["numeropallets_int"],
                    $detalle["numerocajas_int"],
                    $detalle["precio_flt"],
                    $detalle["kproducto"],
                    $detalle["comentario_str"],
                    $detalle["eliminado_bit"],
                    $detalle["fechaeliminacion_dtm"],
                    $detalle["fecha_dtm"],
                    $kagricultor,
                    $detalle["total_flt"]
                );
            }
            $stmt->execute();
            $stmt->close();
        }

        // 4. ARCHIVOS
        if (isset($albaran["archivos"]) && is_array($albaran["archivos"])) {
            foreach ($albaran["archivos"] as $archivo) {
                $stmt = $conn->prepare("SELECT COUNT(*) FROM tblArchivos WHERE karchivos = ?");
                $stmt->bind_param("s", $archivo["karchivos"]);
                $stmt->execute();
                $stmt->bind_result($aExists);
                $stmt->fetch();
                $stmt->close();

                if ($aExists > 0) {
                    // CORRECCIÓN: Vinculamos el kalbaran al campo kcampo1
                    $sql = "UPDATE tblArchivos SET kuuid=?, eliminado_bit=?, fechaeliminacion_dtm=?, comentario_str=? WHERE karchivos=? AND kagricultor=?";
                    $stmt = $conn->prepare($sql);
                    // 6 parámetros: s, i, s, s, s, s
                    $stmt->bind_param(
                        "sissss", 
                        $albaran["kalbaran"], 
                        $archivo["eliminado_bit"], 
                        $archivo["fechaeliminacion_dtm"], 
                        $archivo["comentario_str"], 
                        $archivo["karchivos"], 
                        $kagricultor
                    );
                } else {
                    $sql = "INSERT INTO tblArchivos (karchivos, kagricultor, kuuid, orden_int, fecha_dtm, formato_str, nombrearchivo_str, tipo_str, eliminado_bit, comentario_str) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
                    $stmt = $conn->prepare($sql);
                    // 11 parámetros: s, s, s, i, s, s, s, s, s, i, s
                    $stmt->bind_param(
                        "sssisssssis", 
                        $archivo["karchivos"], 
                        $kagricultor, 
                        $albaran["kalbaran"], // Vinculamos el kalbaran al campo kuuid  
                        $archivo["orden_int"], 
                        $archivo["fecha_dtm"], 
                        $archivo["formato_str"], 
                        $archivo["nombrearchivo_str"], 
                        $archivo["tipo_str"], 
                        //$archivo["kcampo1"], 
                        $archivo["eliminado_bit"], 
                        $archivo["comentario_str"]
                    );
                }
                $stmt->execute();
                $stmt->close();
            }
        }
    

        //--------------------------------------------------
        // FIN
        //--------------------------------------------------

        $conn->commit();

        return jsonResponse($response, [
            "success" => true
        ], 200);

    } catch (Exception $e) {

        $conn->rollback();

        return jsonResponse($response, [
            "error" => $e->getMessage()
        ], 500);
    }
}

/*<?php
// mergealbaran.php

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

function mergeAlbaran(Request $request, Response $response): Response
{
    global $servername, $username, $password, $dbname;

    $conn = conectarDB($servername, $username, $password, $dbname);
    $jwt = $request->getAttribute("jwt");
    $kagricultor = $jwt->sub;

    $input = json_decode($request->getBody()->getContents(), true);

    if (!$input || !isset($input[0])) {
        return jsonResponse($response, ["error" => "JSON malformado o vacío."], 400);
    }

    $albaran = $input[0];

    $conn->begin_transaction();
    try {
        // 1. CABECERA (INSERT o UPDATE)
        $stmt = $conn->prepare("SELECT COUNT(*) FROM tblalbaran WHERE kalbaran = ?");
        $stmt->bind_param("s", $albaran["kalbaran"]);
        $stmt->execute();
        $stmt->bind_result($existsCount);
        $stmt->fetch();
        $stmt->close();

        if ($existsCount > 0) {
            $sql = "UPDATE tblalbaran SET fecha_dtm=?, kalmacen=?, ktipodeprecio=?, comentario_str=?, eliminado_bit=?, fechaeliminacion_dtm=?, ktipoalbaran=?, fechadesde_dtm=?, fechahasta_dtm=?, numcampanias_int=? WHERE kalbaran=?";
            $stmt = $conn->prepare($sql);
            $stmt->bind_param("ssssissssis", 
                $albaran["fecha_dtm"], $albaran["kalmacen"], $albaran["ktipodeprecio"], 
                $albaran["comentario_str"], $albaran["eliminado_bit"], $albaran["fechaeliminacion_dtm"], 
                $albaran["ktipoalbaran"], $albaran["fechadesde_dtm"], $albaran["fechahasta_dtm"], 
                $albaran["numcampanias_int"], $albaran["kalbaran"]);
        } else {
            $sql = "INSERT INTO tblalbaran (kalbaran, fecha_dtm, kalmacen, ktipodeprecio, comentario_str, eliminado_bit, fechaeliminacion_dtm, ktipoalbaran, fechadesde_dtm, fechahasta_dtm, numcampanias_int, kagricultor, idalbaran_str) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
            $stmt = $conn->prepare($sql);
            $stmt->bind_param("sssssissssiss", 
                $albaran["kalbaran"], $albaran["fecha_dtm"], $albaran["kalmacen"], 
                $albaran["ktipodeprecio"], $albaran["comentario_str"], $albaran["eliminado_bit"], 
                $albaran["fechaeliminacion_dtm"], $albaran["ktipoalbaran"], $albaran["fechadesde_dtm"], 
                $albaran["fechahasta_dtm"], $albaran["numcampanias_int"], $kagricultor, $albaran["idalbaran_str"]);
        }
        $stmt->execute();
        $stmt->close();

        // 2. DETALLES
        foreach ($albaran["detalles"] as $detalle) {
            $detalle["precio_flt"] = $detalle["precio_flt"] ?? 0;
            $detalle["total_flt"] = $detalle["total_flt"] ?? 0;

            $stmt = $conn->prepare("SELECT COUNT(*) FROM tblalbarandetalle WHERE kalbarandetalle = ?");
            $stmt->bind_param("s", $detalle["kalbarandetalle"]);
            $stmt->execute();
            $stmt->bind_result($dExistsCount);
            $stmt->fetch();
            $stmt->close();

            if ($dExistsCount > 0) {
                // ACTUALIZAR LÍNEA EXISTENTE
                $sql = "UPDATE tblalbarandetalle SET kfinca=?, linea_int=?, kg_float=?, numeropallets_int=?, numerocajas_int=?, precio_flt=?, kproducto=?, comentario_str=?, eliminado_bit=?, fechaeliminacion_dtm=?, fecha_dtm=?, total_flt=? WHERE kalbarandetalle=?";
                $stmt = $conn->prepare($sql);
                $stmt->bind_param("sidiidssissds", 
                    $detalle["kfinca"], $detalle["linea_int"], $detalle["kg_float"], 
                    $detalle["numeropallets_int"], $detalle["numerocajas_int"], $detalle["precio_flt"], 
                    $detalle["kproducto"], $detalle["comentario_str"], $detalle["eliminado_bit"], 
                    $detalle["fechaeliminacion_dtm"], $detalle["fecha_dtm"], $detalle["total_flt"], 
                    $detalle["kalbarandetalle"]);
            } else {
                // INSERTAR LÍNEA NUEVA
                $sql = "INSERT INTO tblalbarandetalle (kalbarandetalle, kalbaran, kfinca, linea_int, kg_float, numeropallets_int, numerocajas_int, precio_flt, kproducto, comentario_str, eliminado_bit, fechaeliminacion_dtm, fecha_dtm, kagricultor, total_flt) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
                $stmt = $conn->prepare($sql);
                // 15 parámetros: ssidiidssissdsd
                $stmt->bind_param("sssidiidssisssd", 
                    $detalle["kalbarandetalle"], $albaran["kalbaran"], $detalle["kfinca"], 
                    $detalle["linea_int"], $detalle["kg_float"], $detalle["numeropallets_int"], 
                    $detalle["numerocajas_int"], $detalle["precio_flt"], $detalle["kproducto"], 
                    $detalle["comentario_str"], $detalle["eliminado_bit"], $detalle["fechaeliminacion_dtm"], 
                    $detalle["fecha_dtm"], $kagricultor, $detalle["total_flt"]);
            }
            $stmt->execute();
            $stmt->close();
        }

        // 3. ARCHIVOS
        if (isset($albaran["archivos"]) && is_array($albaran["archivos"])) {
            foreach ($albaran["archivos"] as $archivo) {
                $stmt = $conn->prepare("SELECT COUNT(*) FROM tblArchivos WHERE karchivos = ?");
                $stmt->bind_param("s", $archivo["karchivos"]);
                $stmt->execute();
                $stmt->bind_result($aExists);
                $stmt->fetch();
                $stmt->close();

                if ($aExists > 0) {
                    // Actualizar vínculo (kcampo1 es la clave foránea al albarán)
                    $sql = "UPDATE tblArchivos SET kcampo1=?, eliminado_bit=?, fechaeliminacion_dtm=?, comentario_str=? WHERE karchivos=? AND kagricultor=?";
                    $stmt = $conn->prepare($sql);
                    $stmt->bind_param("sissss", 
                        $albaran["kalbaran"], $archivo["eliminado_bit"], 
                        $archivo["fechaeliminacion_dtm"], $archivo["comentario_str"], 
                        $archivo["karchivos"], $kagricultor);
                } else {
                    // Insertar si no existe (con el kalbaran en kcampo1)
                    $sql = "INSERT INTO tblArchivos (karchivos, kagricultor, kuuid, orden_int, fecha_dtm, formato_str, nombrearchivo_str, tipo_str, kcampo1, eliminado_bit, comentario_str) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
                    $stmt = $conn->prepare($sql);
                    $stmt->bind_param("sssisssssis", 
                        $archivo["karchivos"], $kagricultor, $archivo["kuuid"], 
                        $archivo["orden_int"], $archivo["fecha_dtm"], $archivo["formato_str"], 
                        $archivo["nombrearchivo_str"], $archivo["tipo_str"], $albaran["kalbaran"], 
                        $archivo["eliminado_bit"], $archivo["comentario_str"]);
                }
                $stmt->execute();
                $stmt->close();
            }
        }

        $conn->commit();
        return jsonResponse($response, ["success" => true], 200);
    } catch (Exception $e) {
        $conn->rollback();
        return jsonResponse($response, ["error" => $e->getMessage()], 500);
    }
}*/