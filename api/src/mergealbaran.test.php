<?php
//mergealbaran.php

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

function mergeAlbaran(Request $request, Response $response): Response {
    global $servername, $username, $password, $dbname;

    $conn = conectarDB($servername, $username, $password, $dbname);
    $jwt = $request->getAttribute('jwt');
    $kagricultor = $jwt->sub;

    //$input = $request->getParsedBody();
    $input = json_decode($request->getBody()->getContents(), true);

	
	if (!$input || !isset($input[0])) {
        return jsonResponse($response, ["error" => "JSON malformado o vacío."], 400);
    }

    $albaran = $input[0];
    $albaran['kagricultor'] = $kagricultor;  // <- Forzar que usemos el del token
	
	$conn->begin_transaction();
    try {
        // 1. CABECERA
        
		$stmt = $conn->prepare("SELECT COUNT(*) FROM tblalbaran WHERE kalbaran = ?");
        $stmt->bind_param("s", $albaran["kalbaran"]);
        $stmt->execute();
        $stmt->bind_result($existsCount);
        $stmt->fetch();
        $stmt->close();

        $exists = $existsCount > 0;

        if ($exists) {
            $sql = "UPDATE tblalbaran SET fecha_dtm=?, kalmacen=?, ktipodeprecio=?, comentario_str=?, eliminado_bit=?, fechaeliminacion_dtm=?, ktipoalbaran=?, fechadesde_dtm=?, fechahasta_dtm=?, numcampanias_int=? WHERE kalbaran=?";
            $stmt = $conn->prepare($sql);
            $stmt->bind_param(
                //"ssssissssds",
                "ssssissssis",
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
                $albaran["kalbaran"]
            );
        } else {
            $sql = "INSERT INTO tblalbaran (kalbaran, fecha_dtm, kalmacen, ktipodeprecio, comentario_str, eliminado_bit, fechaeliminacion_dtm, ktipoalbaran, fechadesde_dtm, fechahasta_dtm, numcampanias_int, kagricultor, idalbaran_str) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, '')";
            $stmt = $conn->prepare($sql);
            $stmt->bind_param(
                //"ssssissssdis",
                  "sssssissssis",
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
                $albaran["kagricultor"]
            );
        }
        $stmt->execute();
        $stmt->close();

        // Si eliminado_bit = 1, cascada
        if ($albaran["eliminado_bit"]) {
            $fecha = $albaran["fechaeliminacion_dtm"];
            $kalbaran = $albaran["kalbaran"];

            $stmt = $conn->prepare("UPDATE tblalbarandetalle SET eliminado_bit=1, fechaeliminacion_dtm=? WHERE kalbaran=?");
            $stmt->bind_param("ss", $fecha, $kalbaran);
            $stmt->execute();
            $stmt->close();

            $stmt = $conn->prepare("UPDATE tblArchivos SET eliminado_bit=1, fechaeliminacion_dtm=? WHERE kuuid=?");
            $stmt->bind_param("ss", $fecha, $kalbaran);
            $stmt->execute();
            $stmt->close();
        }

        // 2. DETALLES
        foreach ($albaran["detalles"] as $detalle) {

																	  
																 
																

            $stmt = $conn->prepare("SELECT COUNT(*) FROM tblalbarandetalle WHERE kalbarandetalle = ?");
            $stmt->bind_param("s", $detalle["kalbarandetalle"]);
            $stmt->execute();
            $stmt->bind_result($existsCount);
            $stmt->fetch();
            $stmt->close();
            $exists = $existsCount > 0;

            if ($exists) {
                $sql = "UPDATE tblalbarandetalle SET kfinca=?, linea_int=?, kg_float=?, numeropallets_int=?, numerocajas_int=?, precio_flt=?, kproducto=?, comentario_str=?, eliminado_bit=?, fechaeliminacion_dtm=?, fecha_dtm=?, total_flt=? WHERE kalbarandetalle=?";
                $stmt = $conn->prepare($sql);
				$stmt->bind_param(
					//"siiddsssssdss",  // ← 13 letras
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
                $sql = "INSERT INTO tblalbarandetalle (kalbarandetalle, kalbaran, kfinca, linea_int, kg_float, numeropallets_int, numerocajas_int, precio_flt, kproducto, comentario_str, eliminado_bit, fechaeliminacion_dtm, fecha_dtm, kagricultor, total_flt) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
                $stmt = $conn->prepare($sql);
				$stmt->bind_param(
					//"sssiiddsssssds",  // CORREGIDO
					"ssidiidssissds",
					$detalle["kalbarandetalle"],
					$albaran["kalbaran"],
					$detalle["kfinca"],
					$detalle["linea_int"],
					$detalle["kg_float"],
					$detalle["numeropallets_int"],
					$detalle["numerocajas_int"],
					$detalle["precio_flt"],
					$detalle["kproducto"],  // <-- string (UUID)
					$detalle["comentario_str"],
					$detalle["eliminado_bit"],
					$detalle["fechaeliminacion_dtm"],
					$detalle["fecha_dtm"],
					$albaran["kagricultor"],
					$detalle["total_flt"]
				);
            }
            $stmt->execute();
            $stmt->close();
        }

/*
        // 3. ARCHIVOS
        foreach ($albaran["archivos"] as $archivo) {
            $stmt = $conn->prepare("SELECT COUNT(*) FROM tblArchivos WHERE karchivos = ?");
            $stmt->bind_param("s", $archivo["karchivos"]);
            $stmt->execute();
            $stmt->bind_result($existsCount);
            $stmt->fetch();
            $stmt->close();
            $exists = $existsCount > 0;

            if ($exists) {
                $sql = "UPDATE tblArchivos SET orden_int=?, fecha_dtm=?, formato_str=?, sizemb_flt=?, comentario_str=?, nombrearchivo_str=?, rutacompleta_str=?, campo1_str=?, tipo_str=?, eliminado_bit=?, fechaeliminacion_dtm=?, kuuid=? WHERE karchivos=?";
                $stmt = $conn->prepare($sql);
                $stmt->bind_param(
                    "issdsssssisss",
                    $archivo["orden_int"],
                    $archivo["fecha_dtm"],
                    $archivo["formato_str"],
                    $archivo["sizemb_flt"],
                    $archivo["comentario"],
                    $archivo["nombrearchivo_str"],
                    $archivo["rutacompleta_str"],
                    $archivo["campo1_str"],
                    $archivo["tipo_str"],
                    $archivo["eliminado_bit"],
                    $archivo["fechaeliminacion_dtm"],
                    $albaran["kalbaran"],
                    $archivo["karchivos"]
                );
            } else {
                $sql = "INSERT INTO tblArchivos (karchivos, kagricultor, kuuid, orden_int, fecha_dtm, formato_str, sizemb_flt, comentario_str, nombrearchivo_str, rutacompleta_str, campo1_str, tipo_str, eliminado_bit, fechaeliminacion_dtm) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
                $stmt = $conn->prepare($sql);
                $stmt->bind_param(
                    "sssissdsssssis",
                    $archivo["karchivos"],
											  
													 
										  
                    $albaran["kagricultor"],
                    $albaran["kalbaran"],
                    $archivo["orden_int"],
                    $archivo["fecha_dtm"],
                    $archivo["formato_str"],
                    $archivo["sizemb_flt"],
                    $archivo["comentario"],
                    $archivo["nombrearchivo_str"],
                    $archivo["rutacompleta_str"],
                    $archivo["campo1_str"],
                    $archivo["tipo_str"],
                    $archivo["eliminado_bit"],
                    $archivo["fechaeliminacion_dtm"]
                );
            }
            $stmt->execute();
            $stmt->close();
        }
*/
        $conn->commit();
        return jsonResponse($response, ["success" => true], 200);

    } catch (Exception $e) {
        $conn->rollback();
        return jsonResponse($response, ["error" => $e->getMessage()], 500);
    }
}
	