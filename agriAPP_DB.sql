-- phpMyAdmin SQL Dump
-- version 5.2.1deb1
-- https://www.phpmyadmin.net/
--
-- Servidor: localhost:3306
-- Tiempo de generación: 21-08-2026 a las 14:37:28
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
  `fechaeliminacion_dtm` datetime DEFAULT NULL,
  `pref_agrupacion_str` varchar(100) DEFAULT 'finca,cultivo,fecha',
  `pref_agrupacion_gastos_str` varchar(100) DEFAULT 'almacen,finca,fecha',
  `pref_personal_vista_str` varchar(255) DEFAULT 'mes,trabajador',
  `pref_personal_agrupacion_str` varchar(255) DEFAULT 'dias'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

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
  `ktipoalbaran` varchar(36) NOT NULL,
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
  `ktipoalbaran` varchar(36) DEFAULT NULL,
  `fecha_dtm` datetime NOT NULL DEFAULT current_timestamp(),
  `eliminado_bit` bit(1) NOT NULL DEFAULT b'0',
  `fechaeliminacion_dtm` datetime DEFAULT NULL,
  `kagricultor` uuid NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

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
  `ktipoalbaran` varchar(36) NOT NULL,
  `fecha_dtm` datetime NOT NULL DEFAULT current_timestamp(),
  `eliminado_bit` bit(1) NOT NULL DEFAULT b'0',
  `fechaeliminacion_dtm` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tbltipoalbaran`
--

CREATE TABLE `tbltipoalbaran` (
  `ktipoalbaran` varchar(36) NOT NULL,
  `kagricultor` uuid NOT NULL,
  `id_int` int(11) NOT NULL,
  `descripcion_str` varchar(100) NOT NULL,
  `eliminado_bit` bit(1) NOT NULL DEFAULT b'0',
  `fechaeliminacion_dtm` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

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
  `fechaeliminacion_dtm` datetime DEFAULT NULL,
  `fechainicioultimocontrato_dtm` date NOT NULL DEFAULT current_timestamp(),
  `fechafinultimocontrato_dtm` date DEFAULT NULL,
  `fecha_dtm` datetime NOT NULL DEFAULT current_timestamp()
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
  ADD KEY `ktipoalbaran` (`ktipoalbaran`);

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
  ADD CONSTRAINT `fk_tblproductos_tbltipoalbaran` FOREIGN KEY (`ktipoalbaran`) REFERENCES `tbltipoalbaran` (`ktipoalbaran`);

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
-- Filtros para la tabla `tbltrabajador`
--
ALTER TABLE `tbltrabajador`
  ADD CONSTRAINT `tbltrabajador_ibfk_1` FOREIGN KEY (`kagricultor`) REFERENCES `tblAgricultores` (`kagricultor`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
