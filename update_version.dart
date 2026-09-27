//update_version.dart
import 'dart:io';
import 'dart:convert';

void main() {
  final now = DateTime.now();
  final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  final nuevaVersion = '1.0.$timestamp';

  print('[INFO] Nueva version generada: $nuevaVersion');

  // 1. Actualizar pubspec.yaml
  final pubspecFile = File('pubspec.yaml');
  if (pubspecFile.existsSync()) {
    String pubspecContent = pubspecFile.readAsStringSync();
    if (pubspecContent.contains(RegExp(r'^version:.*', multiLine: true))) {
      pubspecContent = pubspecContent.replaceAll(RegExp(r'^version:.*', multiLine: true), 'version: $nuevaVersion+1');
    } else {
      pubspecContent = pubspecContent.replaceFirst(RegExp(r'^name:.*', multiLine: true), 'name: agriapp\nversion: $nuevaVersion+1');
    }
    pubspecFile.writeAsStringSync(pubspecContent);
  }

  // 2. Actualizar options.json de forma segura (Sin BOM y codificado bien)
  final jsonFileLocal = File('API/docs/options.json');
  if (jsonFileLocal.existsSync()) {
    // Leemos forzando que limpie cualquier BOM previo
    String content = jsonFileLocal.readAsStringSync();
    if (content.codeUnitAt(0) == 0xFEFF) {
      content = content.substring(1); 
    }
    final Map<String, dynamic> jsonMap = jsonDecode(content);
    jsonMap['version_ultima'] = nuevaVersion;
    
    final JsonEncoder encoder = const JsonEncoder.withIndent('  ');
    // Escribimos sin BOM
    jsonFileLocal.writeAsStringSync(encoder.convert(jsonMap));
    print('[INFO] options.json actualizado correctamente.');
  }
}