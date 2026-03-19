-- phpMyAdmin SQL Dump
-- version 5.2.1deb1
-- https://www.phpmyadmin.net/
--
-- Servidor: localhost:3306
-- Tiempo de generación: 19-03-2026 a las 22:00:20
-- Versión del servidor: 10.11.11-MariaDB-0+deb12u1
-- Versión de PHP: 8.2.28

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de datos: `agri`
--

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tblAgricultores`
--

CREATE TABLE `tblAgricultores` (
  `kagricultor` uuid NOT NULL DEFAULT uuid(),
  `fechaCreacion_dtm` datetime NOT NULL DEFAULT current_timestamp(),
  `nombre_str` varchar(50) NOT NULL,
  `apellidos_str` varchar(100) NOT NULL,
  `dni_str` varchar(15) NOT NULL,
  `direccion_str` varchar(200) NOT NULL,
  `email_str` varchar(50) DEFAULT NULL,
  `telefono_str` varchar(20) DEFAULT NULL,
  `validado_bit` bit(1) NOT NULL DEFAULT b'0',
  `campo1_str` varchar(300) DEFAULT NULL,
  `telegramid_str` varchar(20) DEFAULT NULL,
  `password_str` varchar(100) DEFAULT NULL,
  `activado_bit` bit(1) DEFAULT NULL,
  `bloqueado_bit` bit(1) DEFAULT NULL COMMENT 'Este campo indica si el usuario puede hacer login o no por tener la cuenta bloqueada por superar el maxímo número de intentos fallidos al hacer login',
  `numintentos_int` int(3) DEFAULT NULL COMMENT 'num intentos fallidos al hacer login desde la última conexión correcta',
  `ultimointentologin_dtm` datetime DEFAULT NULL COMMENT 'ultimo intento de hacer login. Nos valdrá para que no se pueda hacer login en los últimos x segundos/minutos etc.',
  `kidioma` uuid NOT NULL DEFAULT 'ac588b21-6ba1-11f0-ac9b-e2b6c6b4d8df',
  `ktipodeusuario` uuid DEFAULT NULL,
  `eliminado_bit` bit(1) NOT NULL DEFAULT b'0',
  `fechaeliminacion_dtm` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `tblAgricultores`
--

INSERT INTO `tblAgricultores` (`kagricultor`, `fechaCreacion_dtm`, `nombre_str`, `apellidos_str`, `dni_str`, `direccion_str`, `email_str`, `telefono_str`, `validado_bit`, `campo1_str`, `telegramid_str`, `password_str`, `activado_bit`, `bloqueado_bit`, `numintentos_int`, `ultimointentologin_dtm`, `kidioma`, `ktipodeusuario`, `eliminado_bit`, `fechaeliminacion_dtm`) VALUES
('ab6cb5c7-29db-11f0-8a69-e2b6c6b4d8df', '2025-05-05 18:06:29', 'Agricultor de prueba', 'Fernez', '1234567a', 'calle la casa', 'correo@mentira.es', '1234567', b'1', NULL, '123456789', '123456', b'1', b'0', 0, '2025-05-05 18:16:57', 'ac588b21-6ba1-11f0-ac9b-e2b6c6b4d8df', 'e068546d-1912-11f0-9fba-e2b6c6b4d8df', b'0', NULL),
('6223c8a4-0f95-11f0-ab54-e2b6c6b4d8df', '2025-04-02 07:37:51', 'Prueba', 'Pruebez', '123456789x', '213', 'davidbueso@gmail.com', '619318257', b'1', NULL, NULL, '1234a*', NULL, b'0', 0, '2026-03-18 23:09:20', 'ac588b21-6ba1-11f0-ac9b-e2b6c6b4d8df', 'af7a6cb3-1912-11f0-9fba-e2b6c6b4d8df', b'0', NULL);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tblalbaran`
--

CREATE TABLE `tblalbaran` (
  `kalbaran` uuid NOT NULL DEFAULT uuid(),
  `kagricultor` uuid NOT NULL,
  `fecha_dtm` datetime NOT NULL DEFAULT current_timestamp(),
  `kalmacen` uuid DEFAULT NULL COMMENT 'Almacen o proveedor',
  `ktipodeprecio` uuid DEFAULT NULL,
  `ktipoalbaran` uuid NOT NULL,
  `fechadesde_dtm` datetime NOT NULL DEFAULT current_timestamp(),
  `fechahasta_dtm` datetime NOT NULL DEFAULT current_timestamp(),
  `numcampanias_int` int(2) NOT NULL DEFAULT 1,
  `comentario_str` varchar(500) DEFAULT NULL,
  `idalbaran_str` varchar(100) NOT NULL COMMENT 'Numeracion del albaran por parte del almacén',
  `eliminado_bit` bit(1) NOT NULL DEFAULT b'0',
  `fechaeliminacion_dtm` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tblalbarandetalle`
--

CREATE TABLE `tblalbarandetalle` (
  `kalbarandetalle` uuid NOT NULL DEFAULT uuid(),
  `kalbaran` uuid NOT NULL,
  `kfinca` uuid NOT NULL,
  `linea_int` int(11) NOT NULL,
  `kg_float` float NOT NULL COMMENT 'kg de genero o unidades de cosas\r\n',
  `numeropallets_int` int(11) DEFAULT NULL,
  `numerocajas_int` int(11) DEFAULT NULL,
  `precio_flt` float DEFAULT NULL,
  `kproducto` uuid NOT NULL COMMENT 'tomates, plastico, pimientos, tenacillas',
  `comentario_str` varchar(500) DEFAULT NULL,
  `eliminado_bit` bit(1) NOT NULL DEFAULT b'0',
  `fechaeliminacion_dtm` datetime DEFAULT NULL,
  `kagricultor` uuid NOT NULL,
  `fecha_dtm` datetime DEFAULT current_timestamp(),
  `total_flt` float NOT NULL COMMENT 'En euros'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Disparadores `tblalbarandetalle`
--
DELIMITER $$
CREATE TRIGGER `trg_before_kalbarandetalle_insert` BEFORE INSERT ON `tblalbarandetalle` FOR EACH ROW BEGIN
    IF NEW.precio_flt IS NULL OR NEW.kg_float IS NULL THEN
        SET NEW.total_flt = NULL;
    ELSE
        SET NEW.total_flt = NEW.precio_flt * NEW.kg_float;
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_before_kalbarandetalle_update` BEFORE UPDATE ON `tblalbarandetalle` FOR EACH ROW BEGIN
    IF NEW.precio_flt IS NULL OR NEW.kg_float IS NULL THEN
        SET NEW.total_flt = NULL;
    ELSE
        SET NEW.total_flt = NEW.precio_flt * NEW.kg_float;
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_linea_autonumerica` BEFORE INSERT ON `tblalbarandetalle` FOR EACH ROW BEGIN
  DECLARE siguiente INT;

  SELECT IFNULL(MAX(linea_int), 0) + 1 INTO siguiente
  FROM tblalbarandetalle
  WHERE kalbaran = NEW.kalbaran;

  SET NEW.linea_int = siguiente;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tblalmacen`
--

CREATE TABLE `tblalmacen` (
  `kalmacen` uuid NOT NULL DEFAULT uuid(),
  `nombre_str` varchar(100) NOT NULL,
  `ktipoalbaran` uuid NOT NULL DEFAULT 'b42f149b-6744-11f0-ac9b-e2b6c6b4d8df',
  `fecha_dtm` datetime NOT NULL DEFAULT current_timestamp(),
  `eliminado_bit` bit(1) NOT NULL DEFAULT b'0',
  `fechaeliminacion_dtm` datetime DEFAULT NULL,
  `kagricultor` uuid NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `tblalmacen`
--

INSERT INTO `tblalmacen` (`kalmacen`, `nombre_str`, `ktipoalbaran`, `fecha_dtm`, `eliminado_bit`, `fechaeliminacion_dtm`, `kagricultor`) VALUES
('47876d3a-16d3-11f0-ab54-e2b6c6b4d8df', 'Almacen el pepeillo', 'b42f149b-6744-11f0-ac9b-e2b6c6b4d8df', '2025-04-11 12:48:34', b'0', NULL, '6223c8a4-0f95-11f0-ab54-e2b6c6b4d8df'),
('494e7d82-16d3-11f0-ab54-e2b6c6b4d8df', 'BuesoSol', 'b42f149b-6744-11f0-ac9b-e2b6c6b4d8df', '2025-04-11 12:48:37', b'0', NULL, '6223c8a4-0f95-11f0-ab54-e2b6c6b4d8df'),
('4ac2194b-67d5-11f0-ac9b-e2b6c6b4d8df', 'MABE', 'b42f149b-6744-11f0-ac9b-e2b6c6b4d8df', '2025-07-23 14:57:02', b'0', NULL, '6223c8a4-0f95-11f0-ab54-e2b6c6b4d8df'),
('4ac21a12-67d5-11f0-ac9b-e2b6c6b4d8df', 'Fertoal', 'c4755f6d-6744-11f0-ac9b-e2b6c6b4d8df', '2025-07-23 14:57:02', b'0', NULL, '6223c8a4-0f95-11f0-ab54-e2b6c6b4d8df'),
('6f17c937-67d5-11f0-ac9b-e2b6c6b4d8df', 'MABE', 'c4755f6d-6744-11f0-ac9b-e2b6c6b4d8df', '2025-07-23 14:56:06', b'0', NULL, '6223c8a4-0f95-11f0-ab54-e2b6c6b4d8df');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tblaltatrabajador`
--

CREATE TABLE `tblaltatrabajador` (
  `kaltatrabajador` uuid NOT NULL DEFAULT uuid(),
  `ktrabajador` uuid NOT NULL,
  `kagricultor` uuid NOT NULL,
  `fechainicio_dtm` date NOT NULL,
  `fechafin_dtm` date DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tblArchivos`
--

CREATE TABLE `tblArchivos` (
  `karchivos` uuid NOT NULL DEFAULT uuid(),
  `kagricultor` uuid NOT NULL,
  `kuuid` uuid DEFAULT NULL COMMENT 'Este campo puede ser: kfincagasto; kalbaran o kagricultor',
  `orden_int` int(11) DEFAULT NULL,
  `archivo_bin` longblob DEFAULT NULL,
  `fecha_dtm` datetime NOT NULL DEFAULT current_timestamp(),
  `formato_str` varchar(30) DEFAULT NULL,
  `sizemb_flt` float DEFAULT NULL,
  `comentario_str` varchar(500) DEFAULT NULL,
  `nombrearchivo_str` varchar(255) DEFAULT NULL,
  `rutacompleta_str` varchar(1024) DEFAULT NULL,
  `campo1_str` varchar(100) DEFAULT NULL,
  `tipo_str` varchar(100) DEFAULT NULL,
  `eliminado_bit` bit(1) NOT NULL DEFAULT b'0',
  `fechaeliminacion_dtm` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Disparadores `tblArchivos`
--
DELIMITER $$
CREATE TRIGGER `before_insert_archivos` BEFORE INSERT ON `tblArchivos` FOR EACH ROW BEGIN
    DECLARE new_order INT;

    -- Calcular el número de archivos previos con el mismo kfincagastos
    SELECT COUNT(*) + 1 INTO new_order FROM tblArchivos WHERE kuuid = NEW.kuuid;
    
    -- Asignar el orden
    SET NEW.orden_int = new_order;
    SET NEW.formato_str = UPPER(NEW.formato_str);
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tblfinca`
--

CREATE TABLE `tblfinca` (
  `kfinca` uuid NOT NULL DEFAULT uuid(),
  `kfincapadre` uuid DEFAULT NULL,
  `nombre_str` varchar(100) NOT NULL,
  `descripcion_str` varchar(500) DEFAULT NULL,
  `kagricultor` uuid NOT NULL,
  `Ubicacion_str` varchar(200) DEFAULT NULL,
  `aream2_float` float DEFAULT NULL,
  `campo1_str` varchar(1000) DEFAULT NULL,
  `campo2_str` varchar(1000) DEFAULT NULL,
  `fecha` datetime NOT NULL DEFAULT current_timestamp(),
  `eliminado_bit` bit(1) NOT NULL DEFAULT b'0',
  `fechaeliminacion_dtm` datetime DEFAULT NULL,
  `fechaultimouso_dtm` datetime NOT NULL DEFAULT '1970-01-01 00:00:00'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tblFincaGastos`
--

CREATE TABLE `tblFincaGastos` (
  `kagricultor` uuid DEFAULT NULL,
  `kfincagastos` uuid NOT NULL DEFAULT uuid(),
  `fecha_dtm` datetime NOT NULL DEFAULT current_timestamp(),
  `importe_flt` float NOT NULL,
  `concepto_str` varchar(300) NOT NULL,
  `ktipogasto` uuid DEFAULT NULL,
  `campo4` varchar(300) DEFAULT NULL,
  `archivo` longblob DEFAULT NULL,
  `kfinca` uuid DEFAULT NULL,
  `eliminado_bit` bit(1) NOT NULL DEFAULT b'0',
  `fechaeliminacion_dtm` datetime DEFAULT NULL,
  `fechadesde_dtm` date NOT NULL DEFAULT current_timestamp(),
  `fechahasta_dtm` date NOT NULL DEFAULT current_timestamp(),
  `numcampanias_flt` float NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Disparadores `tblFincaGastos`
--
DELIMITER $$
CREATE TRIGGER `tr_tblFincaGastos_insert` BEFORE INSERT ON `tblFincaGastos` FOR EACH ROW BEGIN
    IF NEW.numcampanias_flt = 1 THEN
        SET NEW.fechahasta_dtm = NEW.fechadesde_dtm;
    ELSEIF NEW.numcampanias_flt > 1 THEN
        SET NEW.fechahasta_dtm = DATE(CONCAT(YEAR(NEW.fechadesde_dtm) + NEW.numcampanias_flt - 1, '-08-31'));
        -- Si el 31 de agosto ya pasó en el año de inicio, se suma un año.
        IF NEW.fechahasta_dtm < NEW.fechadesde_dtm THEN
           SET NEW.fechahasta_dtm = DATE(CONCAT(YEAR(NEW.fechadesde_dtm) + NEW.numcampanias_flt, '-08-31'));
        END IF;
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `tr_tblFincaGastos_update` BEFORE UPDATE ON `tblFincaGastos` FOR EACH ROW BEGIN
    IF NEW.numcampanias_flt = 1 THEN
        SET NEW.fechahasta_dtm = NEW.fechadesde_dtm;
    ELSEIF NEW.numcampanias_flt > 1 THEN
       SET NEW.fechahasta_dtm = DATE(CONCAT(YEAR(NEW.fechadesde_dtm) + NEW.numcampanias_flt - 1, '-08-31'));
       -- Si el 31 de agosto ya pasó en el año de inicio, se suma un año.
        IF NEW.fechahasta_dtm < NEW.fechadesde_dtm THEN
           SET NEW.fechahasta_dtm = DATE(CONCAT(YEAR(NEW.fechadesde_dtm) + NEW.numcampanias_flt, '-08-31'));
        END IF;
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tblidioma`
--

CREATE TABLE `tblidioma` (
  `kidioma` uuid NOT NULL DEFAULT uuid() COMMENT 'ID',
  `Idioma` varchar(50) NOT NULL,
  `kagricultor` uuid NOT NULL,
  `eliminado_bit` bit(1) DEFAULT b'0',
  `fechaeliminacion_dtm` datetime DEFAULT NULL,
  `Descripcion` varchar(500) DEFAULT NULL COMMENT '??'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `tblidioma`
--

INSERT INTO `tblidioma` (`kidioma`, `Idioma`, `kagricultor`, `eliminado_bit`, `fechaeliminacion_dtm`, `Descripcion`) VALUES
('ac588b21-6ba1-11f0-ac9b-e2b6c6b4d8df', 'ES-ES', 'ab6cb5c7-29db-11f0-8a69-e2b6c6b4d8df', b'0', NULL, NULL);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tbljornada`
--

CREATE TABLE `tbljornada` (
  `kjornada` uuid NOT NULL DEFAULT uuid(),
  `ktrabajador` uuid NOT NULL,
  `kagricultor` uuid NOT NULL,
  `fecha_dtm` date NOT NULL,
  `observaciones_str` varchar(500) DEFAULT NULL,
  `horas_flt` float DEFAULT NULL,
  `horario_str` varchar(200) DEFAULT NULL,
  `eliminado_bit` bit(1) DEFAULT NULL,
  `fechaeliminacion_dtm` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tblnota`
--

CREATE TABLE `tblnota` (
  `knota` uuid NOT NULL DEFAULT uuid(),
  `nota_str` varchar(1000) DEFAULT NULL,
  `fecha_dtm` datetime NOT NULL DEFAULT current_timestamp(),
  `kagricultor` uuid NOT NULL,
  `eliminado_bit` bit(1) NOT NULL DEFAULT b'0',
  `fechaeliminacion_dtm` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tbloperacion`
--

CREATE TABLE `tbloperacion` (
  `koperacion` uuid NOT NULL DEFAULT uuid(),
  `ktipooperacion` uuid NOT NULL,
  `kagricultor` uuid NOT NULL,
  `fecha_dtm` datetime NOT NULL DEFAULT current_timestamp(),
  `fechainicio_dtm` datetime DEFAULT NULL,
  `fechafin_dtm` datetime DEFAULT NULL,
  `descripcion_str` varchar(500) DEFAULT NULL,
  `numpersonas_int` int(11) DEFAULT NULL,
  `eliminado_bit` bit(1) NOT NULL DEFAULT b'0',
  `fechaeliminacion_dtm` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tbloperaciontrabajador`
--

CREATE TABLE `tbloperaciontrabajador` (
  `koperaciontrabjador` uuid NOT NULL DEFAULT uuid(),
  `koperacion` uuid DEFAULT NULL,
  `ktrabajador` uuid DEFAULT NULL,
  `kagricultor` uuid NOT NULL,
  `eliminado_bit` bit(1) NOT NULL DEFAULT b'0',
  `fechaeliminacion_dtm` datetime NOT NULL,
  `comentario_str` varchar(200) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Disparadores `tbloperaciontrabajador`
--
DELIMITER $$
CREATE TRIGGER `trg_optrab_insert` AFTER INSERT ON `tbloperaciontrabajador` FOR EACH ROW BEGIN
  UPDATE tbloperacion
  SET numpersonas_int = (
    SELECT COUNT(*) FROM tbloperaciontrabajador
    WHERE koperacion = NEW.koperacion AND eliminado_bit = b'0'
  )
  WHERE koperacion = NEW.koperacion;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_optrab_update` AFTER UPDATE ON `tbloperaciontrabajador` FOR EACH ROW BEGIN
  IF NEW.koperacion IS NOT NULL THEN
    UPDATE tbloperacion
    SET numpersonas_int = (
      SELECT COUNT(*) FROM tbloperaciontrabajador
      WHERE koperacion = NEW.koperacion AND eliminado_bit = b'0'
    )
    WHERE koperacion = NEW.koperacion;
  END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tblpantalla`
--

CREATE TABLE `tblpantalla` (
  `kpantalla` uuid NOT NULL,
  `pantalla` varchar(100) NOT NULL,
  `kagricultor` uuid NOT NULL,
  `eliminado_bit` bit(1) DEFAULT NULL,
  `fechaeliminacion_dtm` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tblpantallaidioma`
--

CREATE TABLE `tblpantallaidioma` (
  `kpantallaidioma` uuid NOT NULL DEFAULT uuid() COMMENT 'ID',
  `kidioma` uuid NOT NULL COMMENT 'relacion con idioma',
  `kpantalla` uuid NOT NULL COMMENT 'relacion con pantalla',
  `campo_str` varchar(100) NOT NULL COMMENT 'el campo de la pantalla',
  `traduccion_str` varchar(100) NOT NULL COMMENT 'el texto que se mostrara',
  `kagricultor` uuid NOT NULL,
  `eliminado_bit` bit(1) DEFAULT NULL,
  `fechaeliminacion_dtm` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tblproducto`
--

CREATE TABLE `tblproducto` (
  `kproducto` uuid NOT NULL DEFAULT uuid(),
  `producto_str` varchar(100) NOT NULL,
  `ktipoalbaran` uuid NOT NULL,
  `fecha_dtm` datetime NOT NULL DEFAULT current_timestamp(),
  `eliminado_bit` bit(1) NOT NULL DEFAULT b'0',
  `fechaeliminacion_dtm` datetime DEFAULT NULL,
  `ktipoproducto` uuid NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `tblproducto`
--

INSERT INTO `tblproducto` (`kproducto`, `producto_str`, `ktipoalbaran`, `fecha_dtm`, `eliminado_bit`, `fechaeliminacion_dtm`, `ktipoproducto`) VALUES
('7a7207b8-16de-11f0-ab54-e2b6c6b4d8df', 'Pimientos', 'b42f149b-6744-11f0-ac9b-e2b6c6b4d8df', '2025-04-11 14:08:44', b'0', NULL, '944b113e-53d0-11f0-8f22-e2b6c6b4d8df'),
('7fff6af4-16de-11f0-ab54-e2b6c6b4d8df', 'Tomates', 'b42f149b-6744-11f0-ac9b-e2b6c6b4d8df', '2025-04-11 14:08:53', b'0', NULL, '944b113e-53d0-11f0-8f22-e2b6c6b4d8df'),
('44bee507-67d4-11f0-ac9b-e2b6c6b4d8df', 'Fitosanitarios', 'c4755f6d-6744-11f0-ac9b-e2b6c6b4d8df', '2025-07-23 14:49:43', b'0', NULL, 'bd2800e0-53d0-11f0-8f22-e2b6c6b4d8df'),
('58847b63-67d4-11f0-ac9b-e2b6c6b4d8df', 'Plastico', 'c4755f6d-6744-11f0-ac9b-e2b6c6b4d8df', '2025-07-23 14:50:16', b'0', NULL, 'bd2800e0-53d0-11f0-8f22-e2b6c6b4d8df'),
('588c6cef-67d4-11f0-ac9b-e2b6c6b4d8df', 'Semilla', 'c4755f6d-6744-11f0-ac9b-e2b6c6b4d8df', '2025-07-23 14:50:16', b'0', NULL, 'bd2800e0-53d0-11f0-8f22-e2b6c6b4d8df');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tbltipoalbaran`
--

CREATE TABLE `tbltipoalbaran` (
  `ktipoalbaran` uuid NOT NULL DEFAULT uuid(),
  `kagricultor` uuid NOT NULL,
  `id_int` int(11) NOT NULL,
  `descripcion_str` varchar(100) NOT NULL,
  `eliminado_bit` bit(1) NOT NULL DEFAULT b'0',
  `fechaeliminacion_dtm` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `tbltipoalbaran`
--

INSERT INTO `tbltipoalbaran` (`ktipoalbaran`, `kagricultor`, `id_int`, `descripcion_str`, `eliminado_bit`, `fechaeliminacion_dtm`) VALUES
('b42f149b-6744-11f0-ac9b-e2b6c6b4d8df', 'ab6cb5c7-29db-11f0-8a69-e2b6c6b4d8df', 1, 'ALBARAN', b'0', NULL),
('c4755f6d-6744-11f0-ac9b-e2b6c6b4d8df', 'ab6cb5c7-29db-11f0-8a69-e2b6c6b4d8df', 2, 'GASTO', b'0', NULL);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tbltipodeprecio`
--

CREATE TABLE `tbltipodeprecio` (
  `ktipodeprecio` uuid NOT NULL DEFAULT uuid(),
  `tipodeprecio_str` varchar(100) NOT NULL,
  `fecha_dtm` datetime NOT NULL DEFAULT current_timestamp(),
  `descripcion_str` varchar(500) NOT NULL,
  `eliminado_bit` bit(1) NOT NULL DEFAULT b'0',
  `fechaeliminacion_dtm` datetime DEFAULT NULL,
  `kagricultor` uuid NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `tbltipodeprecio`
--

INSERT INTO `tbltipodeprecio` (`ktipodeprecio`, `tipodeprecio_str`, `fecha_dtm`, `descripcion_str`, `eliminado_bit`, `fechaeliminacion_dtm`, `kagricultor`) VALUES
('9753d840-1a42-11f0-9fba-e2b6c6b4d8df', 'Manual', '2025-04-15 21:42:55', 'El precio del detalle del albarán se rellenará manualmente', b'0', NULL, '6223c8a4-0f95-11f0-ab54-e2b6c6b4d8df'),
('adb0827b-1a43-11f0-9fba-e2b6c6b4d8df', 'Semanal', '2025-04-15 21:50:42', 'Se aplica un precio semanal a cada tipo de producto', b'0', NULL, '6223c8a4-0f95-11f0-ab54-e2b6c6b4d8df');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tbltipogasto`
--

CREATE TABLE `tbltipogasto` (
  `ktipogasto` uuid NOT NULL DEFAULT uuid(),
  `tipogasto_str` varchar(100) NOT NULL,
  `descripcion_str` text NOT NULL,
  `fecha_dtm` datetime NOT NULL DEFAULT current_timestamp(),
  `fechamodificacion_dtm` datetime DEFAULT current_timestamp(),
  `kagricultor` uuid DEFAULT NULL,
  `eliminado_bit` bit(1) NOT NULL DEFAULT b'0',
  `fechaeliminacion_dtm` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `tbltipogasto`
--

INSERT INTO `tbltipogasto` (`ktipogasto`, `tipogasto_str`, `descripcion_str`, `fecha_dtm`, `fechamodificacion_dtm`, `kagricultor`, `eliminado_bit`, `fechaeliminacion_dtm`) VALUES
('1507519f-1978-11f0-9fba-e2b6c6b4d8df', 'Sin definir', 'Sin definir', '2025-04-14 21:33:18', '2025-04-14 21:33:18', '6223c8a4-0f95-11f0-ab54-e2b6c6b4d8df', b'0', NULL);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tbltipooperacion`
--

CREATE TABLE `tbltipooperacion` (
  `ktipooperacion` uuid NOT NULL DEFAULT uuid(),
  `tipooperacion_str` varchar(100) NOT NULL,
  `descripcion_str` text NOT NULL,
  `fecha_dtm` datetime NOT NULL DEFAULT current_timestamp(),
  `fechamodificacion_dtm` datetime DEFAULT current_timestamp(),
  `kagricultor` uuid DEFAULT NULL,
  `eliminado_bit` bit(1) NOT NULL DEFAULT b'0',
  `fechaeliminacion_dtm` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `tbltipooperacion`
--

INSERT INTO `tbltipooperacion` (`ktipooperacion`, `tipooperacion_str`, `descripcion_str`, `fecha_dtm`, `fechamodificacion_dtm`, `kagricultor`, `eliminado_bit`, `fechaeliminacion_dtm`) VALUES
('ed04effc-1976-11f0-9fba-e2b6c6b4d8df', 'Sin definir', 'Operacion sin asisgnar a ninguna operación en particular', '2025-04-14 21:25:02', '2025-04-14 21:25:02', '6223c8a4-0f95-11f0-ab54-e2b6c6b4d8df', b'0', NULL),
('0c736eca-1977-11f0-9fba-e2b6c6b4d8df', 'Regar', 'Riego', '2025-04-14 21:25:54', '2025-04-14 21:25:54', '6223c8a4-0f95-11f0-ab54-e2b6c6b4d8df', b'0', NULL);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tbltipoproducto`
--

CREATE TABLE `tbltipoproducto` (
  `ktipoproducto` uuid NOT NULL DEFAULT uuid(),
  `descripcion_str` varchar(100) NOT NULL,
  `fechacreacion_dtm` datetime NOT NULL DEFAULT current_timestamp(),
  `eliminado_int` bit(1) NOT NULL DEFAULT b'0',
  `fechaeliminacion_dtm` datetime DEFAULT NULL,
  `kagricultor` uuid DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `tbltipoproducto`
--

INSERT INTO `tbltipoproducto` (`ktipoproducto`, `descripcion_str`, `fechacreacion_dtm`, `eliminado_int`, `fechaeliminacion_dtm`, `kagricultor`) VALUES
('944b113e-53d0-11f0-8f22-e2b6c6b4d8df', 'Hortalizas', '2026-02-17 22:26:34', b'0', NULL, 'ab6cb5c7-29db-11f0-8a69-e2b6c6b4d8df'),
('bd2800e0-53d0-11f0-8f22-e2b6c6b4d8df', 'Gastos', '2026-02-17 22:27:43', b'0', NULL, 'ab6cb5c7-29db-11f0-8a69-e2b6c6b4d8df');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tbltiposdeusuario`
--

CREATE TABLE `tbltiposdeusuario` (
  `ktipodeusuario` uuid NOT NULL DEFAULT uuid(),
  `descripcion_str` varchar(100) NOT NULL,
  `eliminado_bit` bit(1) NOT NULL DEFAULT b'0',
  `fechaeliminacion_dtm` datetime DEFAULT NULL,
  `kagricultor` uuid DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `tbltiposdeusuario`
--

INSERT INTO `tbltiposdeusuario` (`ktipodeusuario`, `descripcion_str`, `eliminado_bit`, `fechaeliminacion_dtm`, `kagricultor`) VALUES
('af7a6cb3-1912-11f0-9fba-e2b6c6b4d8df', 'Administrador Total', b'0', NULL, '6223c8a4-0f95-11f0-ab54-e2b6c6b4d8df'),
('e068546d-1912-11f0-9fba-e2b6c6b4d8df', 'Usuario', b'0', NULL, '6223c8a4-0f95-11f0-ab54-e2b6c6b4d8df');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tbltrabajador`
--

CREATE TABLE `tbltrabajador` (
  `ktrabajador` uuid NOT NULL DEFAULT uuid(),
  `kagricultor` uuid NOT NULL,
  `nombre_str` varchar(100) NOT NULL,
  `dni_str` varchar(20) DEFAULT NULL,
  `telefono_str` varchar(30) DEFAULT NULL,
  `email_str` varchar(100) DEFAULT NULL,
  `eliminado_bit` bit(1) NOT NULL DEFAULT b'0',
  `fechaeliminacion_dtm` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vfincas`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vfincas` (
`kfinca` uuid
,`kfincapadre` uuid
,`nombre_str` varchar(100)
,`descripcion_str` varchar(500)
,`kagricultor` uuid
,`Ubicacion_str` varchar(200)
,`aream2_float` float
,`campo1_str` varchar(1000)
,`campo2_str` varchar(1000)
,`fecha` datetime
,`fechaultimouso_dtm` datetime
);

-- --------------------------------------------------------

--
-- Estructura para la vista `vfincas`
--
DROP TABLE IF EXISTS `vfincas`;

CREATE ALGORITHM=UNDEFINED DEFINER=`admin`@`%` SQL SECURITY DEFINER VIEW `vfincas`  AS SELECT `tblfinca`.`kfinca` AS `kfinca`, `tblfinca`.`kfincapadre` AS `kfincapadre`, `tblfinca`.`nombre_str` AS `nombre_str`, `tblfinca`.`descripcion_str` AS `descripcion_str`, `tblfinca`.`kagricultor` AS `kagricultor`, `tblfinca`.`Ubicacion_str` AS `Ubicacion_str`, `tblfinca`.`aream2_float` AS `aream2_float`, `tblfinca`.`campo1_str` AS `campo1_str`, `tblfinca`.`campo2_str` AS `campo2_str`, `tblfinca`.`fecha` AS `fecha`, max(`tblalbarandetalle`.`fecha_dtm`) AS `fechaultimouso_dtm` FROM (`tblfinca` left join `tblalbarandetalle` on(`tblfinca`.`kfinca` = `tblalbarandetalle`.`kfinca`)) GROUP BY `tblfinca`.`kfinca` ORDER BY max(`tblalbarandetalle`.`fecha_dtm`) DESC ;

--
-- Índices para tablas volcadas
--

--
-- Indices de la tabla `tblAgricultores`
--
ALTER TABLE `tblAgricultores`
  ADD PRIMARY KEY (`kagricultor`),
  ADD KEY `kagricultor` (`kagricultor`),
  ADD KEY `ktipodeusuario` (`ktipodeusuario`),
  ADD KEY `fk_idioma_tblagricultores_tblidioma` (`kidioma`);

--
-- Indices de la tabla `tblalbaran`
--
ALTER TABLE `tblalbaran`
  ADD PRIMARY KEY (`kalbaran`),
  ADD KEY `kagricultor` (`kagricultor`),
  ADD KEY `fk_almacen` (`kalmacen`),
  ADD KEY `fk_tipodeprecio` (`ktipodeprecio`),
  ADD KEY `fk_tblalbaran_tipoalbaran` (`ktipoalbaran`);

--
-- Indices de la tabla `tblalbarandetalle`
--
ALTER TABLE `tblalbarandetalle`
  ADD PRIMARY KEY (`kalbarandetalle`),
  ADD KEY `fk_albarancabecera` (`kalbaran`),
  ADD KEY `kproductos` (`kproducto`),
  ADD KEY `fk_tblalbarandetalle_agricultor` (`kagricultor`),
  ADD KEY `kfinca` (`kfinca`);

--
-- Indices de la tabla `tblalmacen`
--
ALTER TABLE `tblalmacen`
  ADD PRIMARY KEY (`kalmacen`),
  ADD KEY `fk_tblalmacen_agricultor` (`kagricultor`),
  ADD KEY `fk_tblalmacen_tbltipoalbaran_ktipoalbaran` (`ktipoalbaran`);

--
-- Indices de la tabla `tblaltatrabajador`
--
ALTER TABLE `tblaltatrabajador`
  ADD PRIMARY KEY (`kaltatrabajador`),
  ADD KEY `fk_altatrabajador_trabajador` (`ktrabajador`),
  ADD KEY `fk_altatrabajador_kagricultor` (`kagricultor`);

--
-- Indices de la tabla `tblArchivos`
--
ALTER TABLE `tblArchivos`
  ADD PRIMARY KEY (`karchivos`);

--
-- Indices de la tabla `tblfinca`
--
ALTER TABLE `tblfinca`
  ADD PRIMARY KEY (`kfinca`),
  ADD KEY `fk_kfincaparent` (`kfincapadre`),
  ADD KEY `fk_kagricultor` (`kagricultor`);

--
-- Indices de la tabla `tblFincaGastos`
--
ALTER TABLE `tblFincaGastos`
  ADD PRIMARY KEY (`kfincagastos`),
  ADD KEY `kagricultor` (`kagricultor`),
  ADD KEY `fk_fincas` (`kfinca`),
  ADD KEY `ktipooperacion` (`ktipogasto`);

--
-- Indices de la tabla `tblidioma`
--
ALTER TABLE `tblidioma`
  ADD PRIMARY KEY (`kidioma`),
  ADD KEY `fk_agricultor_tblidioma_tblagricultor` (`kagricultor`);

--
-- Indices de la tabla `tbljornada`
--
ALTER TABLE `tbljornada`
  ADD PRIMARY KEY (`kjornada`),
  ADD KEY `kjornada` (`kjornada`),
  ADD KEY `fk_tbljornada_tbltrabajadores` (`ktrabajador`);

--
-- Indices de la tabla `tblnota`
--
ALTER TABLE `tblnota`
  ADD PRIMARY KEY (`knota`),
  ADD KEY `fk_tblnota_tblagricultro` (`kagricultor`);

--
-- Indices de la tabla `tbloperacion`
--
ALTER TABLE `tbloperacion`
  ADD PRIMARY KEY (`koperacion`),
  ADD KEY `fk_tipooperacion` (`ktipooperacion`);

--
-- Indices de la tabla `tbloperaciontrabajador`
--
ALTER TABLE `tbloperaciontrabajador`
  ADD PRIMARY KEY (`koperaciontrabjador`),
  ADD KEY `koperacion` (`koperacion`),
  ADD KEY `ktrabajador` (`ktrabajador`),
  ADD KEY `kagricultor` (`kagricultor`);

--
-- Indices de la tabla `tblpantalla`
--
ALTER TABLE `tblpantalla`
  ADD PRIMARY KEY (`kpantalla`),
  ADD KEY `fk_agricultor_tblpantalla_tblagricultor` (`kagricultor`);

--
-- Indices de la tabla `tblpantallaidioma`
--
ALTER TABLE `tblpantallaidioma`
  ADD PRIMARY KEY (`kpantallaidioma`),
  ADD KEY `fk_agricultor_tblpantallaidioma_tblagricultor` (`kagricultor`),
  ADD KEY `fk_pantalla_tblpantallaidioma_tblpantalla` (`kpantalla`),
  ADD KEY `fk_idioma_tblpantallaidioma_idioma` (`kidioma`);

--
-- Indices de la tabla `tblproducto`
--
ALTER TABLE `tblproducto`
  ADD PRIMARY KEY (`kproducto`),
  ADD KEY `fk_tblproductos_tbltipoalbaran` (`ktipoalbaran`),
  ADD KEY `fk_tbproductos_tbltipoproductos` (`ktipoproducto`);

--
-- Indices de la tabla `tbltipoalbaran`
--
ALTER TABLE `tbltipoalbaran`
  ADD PRIMARY KEY (`ktipoalbaran`),
  ADD KEY `fk_tbltipoalbaran_fkagricultor` (`kagricultor`);

--
-- Indices de la tabla `tbltipodeprecio`
--
ALTER TABLE `tbltipodeprecio`
  ADD PRIMARY KEY (`ktipodeprecio`),
  ADD KEY `fk_tbltipodeprecio_agricultor` (`kagricultor`);

--
-- Indices de la tabla `tbltipogasto`
--
ALTER TABLE `tbltipogasto`
  ADD PRIMARY KEY (`ktipogasto`),
  ADD KEY `fk_tbltipogasto_agricultor` (`kagricultor`);

--
-- Indices de la tabla `tbltipooperacion`
--
ALTER TABLE `tbltipooperacion`
  ADD PRIMARY KEY (`ktipooperacion`),
  ADD KEY `fk_tbltipooperacion_agricultor` (`kagricultor`);

--
-- Indices de la tabla `tbltipoproducto`
--
ALTER TABLE `tbltipoproducto`
  ADD PRIMARY KEY (`ktipoproducto`),
  ADD UNIQUE KEY `descripcion_str` (`descripcion_str`),
  ADD KEY `fk_agricultor_tipoproducto` (`kagricultor`);

--
-- Indices de la tabla `tbltiposdeusuario`
--
ALTER TABLE `tbltiposdeusuario`
  ADD PRIMARY KEY (`ktipodeusuario`),
  ADD KEY `kagricultor` (`kagricultor`);

--
-- Indices de la tabla `tbltrabajador`
--
ALTER TABLE `tbltrabajador`
  ADD PRIMARY KEY (`ktrabajador`),
  ADD KEY `kagricultor` (`kagricultor`);

--
-- Restricciones para tablas volcadas
--

--
-- Filtros para la tabla `tblAgricultores`
--
ALTER TABLE `tblAgricultores`
  ADD CONSTRAINT `fk_idioma_tblagricultores_tblidioma` FOREIGN KEY (`kidioma`) REFERENCES `tblidioma` (`kidioma`),
  ADD CONSTRAINT `fk_tipodeusuario_agricultor` FOREIGN KEY (`ktipodeusuario`) REFERENCES `tbltiposdeusuario` (`ktipodeusuario`);

--
-- Filtros para la tabla `tblalbaran`
--
ALTER TABLE `tblalbaran`
  ADD CONSTRAINT `fk_agricultor` FOREIGN KEY (`kagricultor`) REFERENCES `tblAgricultores` (`kagricultor`),
  ADD CONSTRAINT `fk_almacen` FOREIGN KEY (`kalmacen`) REFERENCES `tblalmacen` (`kalmacen`),
  ADD CONSTRAINT `fk_tblalbaran_tipoalbaran` FOREIGN KEY (`ktipoalbaran`) REFERENCES `tbltipoalbaran` (`ktipoalbaran`),
  ADD CONSTRAINT `fk_tipodeprecio` FOREIGN KEY (`ktipodeprecio`) REFERENCES `tbltipodeprecio` (`ktipodeprecio`);

--
-- Filtros para la tabla `tblalbarandetalle`
--
ALTER TABLE `tblalbarandetalle`
  ADD CONSTRAINT `fk_albarancabecera` FOREIGN KEY (`kalbaran`) REFERENCES `tblalbaran` (`kalbaran`),
  ADD CONSTRAINT `fk_finca` FOREIGN KEY (`kfinca`) REFERENCES `tblfinca` (`kfinca`),
  ADD CONSTRAINT `fk_productos` FOREIGN KEY (`kproducto`) REFERENCES `tblproducto` (`kproducto`),
  ADD CONSTRAINT `fk_tblalbarandetalle_agricultor` FOREIGN KEY (`kagricultor`) REFERENCES `tblAgricultores` (`kagricultor`);

--
-- Filtros para la tabla `tblalmacen`
--
ALTER TABLE `tblalmacen`
  ADD CONSTRAINT `fk_tblalmacen_agricultor` FOREIGN KEY (`kagricultor`) REFERENCES `tblAgricultores` (`kagricultor`),
  ADD CONSTRAINT `fk_tblalmacen_tbltipoalbaran_ktipoalbaran` FOREIGN KEY (`ktipoalbaran`) REFERENCES `tbltipoalbaran` (`ktipoalbaran`);

--
-- Filtros para la tabla `tblaltatrabajador`
--
ALTER TABLE `tblaltatrabajador`
  ADD CONSTRAINT `fk_altatrabajador_kagricultor` FOREIGN KEY (`kagricultor`) REFERENCES `tblAgricultores` (`kagricultor`),
  ADD CONSTRAINT `fk_altatrabajador_trabajador` FOREIGN KEY (`ktrabajador`) REFERENCES `tbltrabajador` (`ktrabajador`);

--
-- Filtros para la tabla `tblfinca`
--
ALTER TABLE `tblfinca`
  ADD CONSTRAINT `fk_kagricultor` FOREIGN KEY (`kagricultor`) REFERENCES `tblAgricultores` (`kagricultor`),
  ADD CONSTRAINT `fk_kfincaparent` FOREIGN KEY (`kfincapadre`) REFERENCES `tblfinca` (`kfinca`);

--
-- Filtros para la tabla `tblFincaGastos`
--
ALTER TABLE `tblFincaGastos`
  ADD CONSTRAINT `fk_agricultor1` FOREIGN KEY (`kagricultor`) REFERENCES `tblAgricultores` (`kagricultor`),
  ADD CONSTRAINT `fk_fincagastos_tipooperacion` FOREIGN KEY (`ktipogasto`) REFERENCES `tbltipogasto` (`ktipogasto`),
  ADD CONSTRAINT `fk_fincas` FOREIGN KEY (`kfinca`) REFERENCES `tblfinca` (`kfinca`);

--
-- Filtros para la tabla `tblidioma`
--
ALTER TABLE `tblidioma`
  ADD CONSTRAINT `fk_agricultor_tblidioma_tblagricultor` FOREIGN KEY (`kagricultor`) REFERENCES `tblAgricultores` (`kagricultor`);

--
-- Filtros para la tabla `tbljornada`
--
ALTER TABLE `tbljornada`
  ADD CONSTRAINT `fk_tbljornada_tblagricultores` FOREIGN KEY (`ktrabajador`) REFERENCES `tblAgricultores` (`kagricultor`),
  ADD CONSTRAINT `fk_tbljornada_tbltrabajadores` FOREIGN KEY (`ktrabajador`) REFERENCES `tblaltatrabajador` (`kaltatrabajador`);

--
-- Filtros para la tabla `tblnota`
--
ALTER TABLE `tblnota`
  ADD CONSTRAINT `fk_tblnota_tblagricultro` FOREIGN KEY (`kagricultor`) REFERENCES `tblAgricultores` (`kagricultor`);

--
-- Filtros para la tabla `tbloperacion`
--
ALTER TABLE `tbloperacion`
  ADD CONSTRAINT `fk_tipooperacion` FOREIGN KEY (`ktipooperacion`) REFERENCES `tbltipooperacion` (`ktipooperacion`);

--
-- Filtros para la tabla `tbloperaciontrabajador`
--
ALTER TABLE `tbloperaciontrabajador`
  ADD CONSTRAINT `fk_ tbloperaciontrabjador_operacion` FOREIGN KEY (`koperacion`) REFERENCES `tbloperacion` (`koperacion`),
  ADD CONSTRAINT `fk_ tbloperaciontrabjador_tblagricultor` FOREIGN KEY (`kagricultor`) REFERENCES `tblAgricultores` (`kagricultor`),
  ADD CONSTRAINT `fk_ tbloperaciontrabjador_tbltrabajador` FOREIGN KEY (`ktrabajador`) REFERENCES `tbltrabajador` (`ktrabajador`);

--
-- Filtros para la tabla `tblpantalla`
--
ALTER TABLE `tblpantalla`
  ADD CONSTRAINT `fk_agricultor_tblpantalla_tblagricultor` FOREIGN KEY (`kagricultor`) REFERENCES `tblAgricultores` (`kagricultor`);

--
-- Filtros para la tabla `tblpantallaidioma`
--
ALTER TABLE `tblpantallaidioma`
  ADD CONSTRAINT `fk_agricultor_tblpantallaidioma_tblagricultor` FOREIGN KEY (`kagricultor`) REFERENCES `tblAgricultores` (`kagricultor`),
  ADD CONSTRAINT `fk_idioma_tblpantallaidioma_idioma` FOREIGN KEY (`kidioma`) REFERENCES `tblidioma` (`kidioma`),
  ADD CONSTRAINT `fk_pantalla_tblpantallaidioma_tblpantalla` FOREIGN KEY (`kpantalla`) REFERENCES `tblpantalla` (`kpantalla`);

--
-- Filtros para la tabla `tblproducto`
--
ALTER TABLE `tblproducto`
  ADD CONSTRAINT `fk_tblproductos_tbltipoalbaran` FOREIGN KEY (`ktipoalbaran`) REFERENCES `tbltipoalbaran` (`ktipoalbaran`),
  ADD CONSTRAINT `fk_tbproductos_tbltipoproductos` FOREIGN KEY (`ktipoproducto`) REFERENCES `tbltipoproducto` (`ktipoproducto`);

--
-- Filtros para la tabla `tbltipoalbaran`
--
ALTER TABLE `tbltipoalbaran`
  ADD CONSTRAINT `fk_tbltipoalbaran_fkagricultor` FOREIGN KEY (`kagricultor`) REFERENCES `tblAgricultores` (`kagricultor`);

--
-- Filtros para la tabla `tbltipodeprecio`
--
ALTER TABLE `tbltipodeprecio`
  ADD CONSTRAINT `fk_tbltipodeprecio_agricultor` FOREIGN KEY (`kagricultor`) REFERENCES `tblAgricultores` (`kagricultor`);

--
-- Filtros para la tabla `tbltipogasto`
--
ALTER TABLE `tbltipogasto`
  ADD CONSTRAINT `fk_tbltipogasto_agricultor` FOREIGN KEY (`kagricultor`) REFERENCES `tblAgricultores` (`kagricultor`);

--
-- Filtros para la tabla `tbltipooperacion`
--
ALTER TABLE `tbltipooperacion`
  ADD CONSTRAINT `fk_tbltipooperacion_agricultor` FOREIGN KEY (`kagricultor`) REFERENCES `tblAgricultores` (`kagricultor`);

--
-- Filtros para la tabla `tbltipoproducto`
--
ALTER TABLE `tbltipoproducto`
  ADD CONSTRAINT `fk_agricultor_tipoproducto` FOREIGN KEY (`kagricultor`) REFERENCES `tblAgricultores` (`kagricultor`);

--
-- Filtros para la tabla `tbltrabajador`
--
ALTER TABLE `tbltrabajador`
  ADD CONSTRAINT `tbltrabajador_ibfk_1` FOREIGN KEY (`kagricultor`) REFERENCES `tblAgricultores` (`kagricultor`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
