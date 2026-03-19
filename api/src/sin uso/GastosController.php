<?php
require __DIR__ . '/config.php';

function obtenerGastosPorAgricultor($request, $response, $args) {
    global $pdo;
    
    $kagricultor = $args['kagricultor'];

    try {
        $stmt = $pdo->prepare("SELECT * FROM tblFincaGastos WHERE kagricultor = :kagricultor");
        $stmt->bindParam(':kagricultor', $kagricultor);
        $stmt->execute();
        
        $gastos = $stmt->fetchAll(PDO::FETCH_ASSOC);
        return $response->withJson($gastos);
    } catch (PDOException $e) {
        return $response->withJson(['error' => $e->getMessage()], 500);
    }
}
