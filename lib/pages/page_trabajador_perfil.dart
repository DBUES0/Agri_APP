import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/record_trabajador.dart';
import '../utils/app_palette.dart';
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(valor != null && valor.isNotEmpty ? valor : '-', style: const TextStyle(fontSize: 16)),
            ],
          ),
        ],
      ),
    );
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
            // Sustituye el Chip solitario por este Row:
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
                  onPressed: () async {
                    final editado = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => PageTrabajadorForm(trabajador: trabajador)),
                    );
                    // Si el formulario guardó cambios, cerramos la pantalla de perfil 
                    // devolviendo 'true' para que la lista principal se actualice automáticamente.
                    if (editado == true) {
                      if (!context.mounted) return;
                      Navigator.pop(context, true); 
                    }
                  },
                ),
              ],
            ),
            // Chip(
            //   label: Text(esActivo ? 'Contrato Activo' : 'Inactivo / Baja', style: const TextStyle(color: Colors.white)),
            //   backgroundColor: esActivo ? AgriPalette.greenMain : Colors.grey,
            // ),
            const SizedBox(height: 30),
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
            )
          ],
        ),
      ),
    );
  }
}