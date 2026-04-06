# Hoja de Ruta - AgriAPP

Este documento detalla las próximas tareas de desarrollo para la aplicación.

## Tareas Pendientes (Orden de Prioridad Recomendado)

1.  **[ ] Persistencia y Caché Local (Auto-Login)**
    * Implementar base de datos local (SQLite o Hive) para guardar información y no depender siempre de la API al abrir la App.
    * Guardar token para evitar login repetido.

2.  **[ ] Motor de Agrupación Dinámico (AgriAPP-Cerebro)**
    * Desarrollar la lógica para que la visualización de albaranes/gastos acepte criterios de agrupación variables (fecha, nave, cultivo, producto).

3.  **[ ] Módulo de GASTOS**
    * Implementar la funcionalidad de Gastos reutilizando la lógica de Albaranes (herencia de una clase genérica `RegistroAgricola`).

4.  **[ ] Modo Offline / Sincronización**
    * Implementar "Cola de Pendientes" (Outbox) para guardar cambios localmente cuando no hay red y sincronizar automáticamente al recuperar conexión.

5.  **[ ] Signup / Bot de Telegram**
    * Crear pantalla de registro de nuevo usuario con validación por correo.
    * Desarrollar Bot de Telegram para 2FA y notificaciones críticas.