# AgriAPP 🌿

**AgriAPP** es una aplicación diseñada para la gestión integral de explotaciones agrícolas, específicamente optimizada para el trabajo en invernaderos.

## 📱 Características
- **Gestión de Albaranes**: Registro detallado de entradas y salidas en `tblalbaran` y `tblalbarandetalle`.
- **Control de Gastos**: Seguimiento de costes operativos en `tblFincaGastos`.
- **Gestión de Fincas**: Organización por sectores y cálculo de rendimientos[cite: 2].
- **Modo Offline-First**: Permite trabajar sin conexión y sincronizar los datos automáticamente al recuperar internet.
- **Multimedia**: Asociación de imágenes y documentos a registros mediante `tblArchivos`[cite: 2].

## 🏗️ Arquitectura Técnica
- **Frontend**: Flutter (Dart).
- **Base de Datos Local**: SQLite para almacenamiento offline.
- **Backend**: API REST en PHP 8.2 con Slim Framework[cite: 2].
- **Base de Datos Remota**: MariaDB / MySQL[cite: 2].

## 🛠️ Configuración
1. Clonar el repositorio.
2. Ejecutar `flutter pub get`.
3. Configurar el endpoint de la API en `lib/services/api_service.dart`.
4. Ejecutar el proyecto: `flutter run`.