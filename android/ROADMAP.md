# Hoja de Ruta - AgriAPP

Este documento detalla las tareas de desarrollo para la aplicación.

## Tareas Completadas ✅
* **Persistencia y Caché Local**: Implementación de base de datos local con SQLite.
* **Auto-Login**: Persistencia de token para evitar logins repetidos.
* **Modo Offline / Sincronización (Básico)**: Implementación de la "Cola de Pendientes" (Outbox) para registros de texto.

## Tareas Pendientes (Prioridad Actualizada)

1. **[ ] Gestión de Archivos Offline y en Segundo Plano**
    * Refactorizar subida para usar UUIDs generados en cliente.
    * Asegurar persistencia de archivos binarios en el dispositivo antes de la sincro.
2. **[ ] Módulo de GASTOS**
    * Implementar funcionalidad de Gastos en `tblFincaGastos`.
    * Reutilizar la lógica de sincronización de albaranes.
3. **[ ] Motor de Agrupación Dinámico (AgriAPP-Cerebro)**
    * Lógica para agrupar visualmente por fecha, finca o producto.
4. **[ ] Signup / Bot de Telegram**
    * Registro de nuevos usuarios en `tblAgricultores`.
    * Integración con Telegram para notificaciones.