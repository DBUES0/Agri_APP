
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HomePage extends StatefulWidget {
  final String token;
  final int kagricultor;

  const HomePage({super.key, required this.token, required this.kagricultor});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic>? _agricultor;

  @override
  void initState() {
    super.initState();
    cargarAgricultor();
  }

  Future<void> cargarAgricultor() async {
    final response = await http.get(
      Uri.parse('https://api.bueso.duckdns.org/agricultores/\${widget.kagricultor}'),
      headers: {'Authorization': 'Bearer \${widget.token}'},
    );

    if (response.statusCode == 200) {
      setState(() {
        _agricultor = jsonDecode(response.body);
      });
    } else {
      // Manejo de error
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_agricultor == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Datos del agricultor')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _agricultor!.entries.map((entry) {
            return Text('\${entry.key}: \${entry.value}');
          }).toList(),
        ),
      ),
    );
  }
}
