import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/record_trabajador.dart';
import '../utils/app_palette.dart';
import '../services/api_service.dart';
import '../utils/ui_utils.dart';
import 'page_trabajador_add.dart';

class PageTrabajadorPerfil extends StatelessWidget {
  final Trabajador trabajador;
  final bool esActivo;

  const PageTrabajadorPerfil({Key? key, required this.trabajador, required this.esActivo}) : super(key: key);

  Widget _construirFilaInfo(IconData icono, String titulo, String? valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icono, color: AgriPalette.greenMain),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(valor != null && valor.isNotEmpty ? valor : '-', style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 1. FUNCIÓN PARA CAMBIAR CONTRASEÑA ---
  Future<void> _cambiarPasswordTrabajador(BuildContext context) async {
    final TextEditingController pass1Controller = TextEditingController();
    final TextEditingController pass2Controller = TextEditingController();
    final theme = Theme.of(context);

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Contraseña para ${trabajador.nombreStr}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pass1Controller,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nueva contraseña', isDense: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pass2Controller,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Repetir contraseña', isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor),
            onPressed: () async {
              if (pass1Controller.text.isEmpty || pass1Controller.text != pass2Controller.text) {
                mensajeEmergente(dialogContext, 'Las contraseñas no coinciden o están vacías', tipo: 'error');
                return;
              }

              try {
                final ApiService apiService = ApiService();
                await apiService.putGeneric('tbltrabajador', trabajador.ktrabajador, {
                  'password_str': pass1Controller.text.trim()
                });
                
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext); // Cierra el diálogo
                
                if (!context.mounted) return;
                mensajeEmergente(context, 'Contraseña guardada correctamente', tipo: 'success');
              } catch (e) {
                if (!dialogContext.mounted) return;
                mensajeEmergente(dialogContext, 'Error al guardar contraseña: $e', tipo: 'error');
              }
            },
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- 2. FUNCIÓN PARA ELIMINAR TRABAJADOR ---
  Future<void> _eliminarTrabajador(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar trabajador?'),
        content: Text('¿Seguro que deseas eliminar a ${trabajador.nombreStr} de forma permanente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false), 
            child: const Text('Cancelar')
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true), 
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        final ApiService apiService = ApiService();
        await apiService.deleteGeneric('tbltrabajador', trabajador.ktrabajador);
        
        if (!context.mounted) return;
        mensajeEmergente(context, 'Trabajador eliminado con éxito');
        
        // Cierra el perfil y devuelve 'true' para que page_trabajador actualice la lista
        Navigator.pop(context, true); 
      } catch (e) {
        if (!context.mounted) return;
        mensajeEmergente(context, 'Error al eliminar: $e', tipo: 'error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final strInicio = trabajador.fechainicioultimocontratoDtm != null ? dateFormat.format(trabajador.fechainicioultimocontratoDtm!) : '-';
    final strFin = trabajador.fechafinultimocontratoDtm != null ? dateFormat.format(trabajador.fechafinultimocontratoDtm!) : '-';

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil del Trabajador')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 50,
              backgroundColor: esActivo ? AgriPalette.greenMain : Colors.grey,
              child: const Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(trabajador.nombreStr, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Chip(
                  label: Text(esActivo ? 'Contrato Activo' : 'Inactivo / Baja', style: const TextStyle(color: Colors.white)),
                  backgroundColor: esActivo ? AgriPalette.greenMain : Colors.grey,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit, color: AgriPalette.greenMain),
                  tooltip: 'Editar Datos',
                  onPressed: () async {
                    final editado = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => PageTrabajadorForm(trabajador: trabajador)),
                    );
                    if (editado == true) {
                      if (!context.mounted) return;
                      Navigator.pop(context, true); 
                    }
                  },
                ),
                const SizedBox(width: 2),
                IconButton(
                  icon: const Icon(Icons.password, color: AgriPalette.greenMain),
                  tooltip: 'Cambiar Contraseña',
                  onPressed: () async {_cambiarPasswordTrabajador(context);},),
                  
                // _cambiarPasswordTrabajador(context),_eliminarTrabajador(context),
                const SizedBox(width: 2),
                IconButton(
                  icon: const Icon(Icons.delete, color: AgriPalette.greenMain),
                  tooltip: 'Eliminar Trabajador',
                  onPressed: () async {_eliminarTrabajador(context);},),
                  
              ],
            ),
            const SizedBox(height: 30),
            
            // TARJETA DE DATOS
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _construirFilaInfo(Icons.badge, 'DNI / NIE', trabajador.dniStr),
                    const Divider(),
                    _construirFilaInfo(Icons.phone, 'Teléfono', trabajador.telefonoStr),
                    const Divider(),
                    _construirFilaInfo(Icons.email, 'Correo Electrónico', trabajador.emailStr),
                    const Divider(),
                    _construirFilaInfo(Icons.calendar_today, 'Fecha Inicio Contrato', strInicio),
                    const Divider(),
                    _construirFilaInfo(Icons.event_busy, 'Fecha Fin Contrato', strFin),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // BOTONERA DE ACCIONES INFERIOR
            // ElevatedButton.icon(
            //   icon: const Icon(Icons.lock_reset, color: Colors.white),
            //   label: const Text('Definir Contraseña', style: TextStyle(color: Colors.white)),
            //   style: ElevatedButton.styleFrom(
            //     backgroundColor: AgriPalette.greenMain,
            //     minimumSize: const Size(double.infinity, 50),
            //   ),
            //   onPressed: () => _cambiarPasswordTrabajador(context), //_eliminarTrabajador(context),
            // ),
            // const SizedBox(height: 12),
            // OutlinedButton.icon(
            //   icon: const Icon(Icons.delete_forever, color: Colors.red),
            //   label: const Text('Eliminar Trabajador', style: TextStyle(color: Colors.red)),
            //   style: OutlinedButton.styleFrom(
            //     side: const BorderSide(color: Colors.red, width: 2),
            //     minimumSize: const Size(double.infinity, 50),
            //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            //   ),
            //   onPressed: () => _eliminarTrabajador(context),
            // ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}