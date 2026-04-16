/// Modelo de datos que representa a un usuario del sistema.
class Usuario {
  final String nombre;
  final String apellidos;
  final String dni;
  final String direccion;
  final String email;
  final String telefono;
  final bool validado;      // Indica si el usuario ha verificado su cuenta
  final bool bloqueado;     // Indica si el acceso está restringido
  final int intentos;       // Contador de intentos de login fallidos
  final String ultimoIntento; // Fecha del último intento (formato String)
  final String tipoUsuario; // Identificador del rol o tipo de usuario

  Usuario({
    required this.nombre,
    required this.apellidos,
    required this.dni,
    required this.direccion,
    required this.email,
    required this.telefono,
    required this.validado,
    required this.bloqueado,
    required this.intentos,
    required this.ultimoIntento,
    required this.tipoUsuario,
  });

  /// Crea una instancia de [Usuario] a partir de un mapa JSON.
  /// Maneja la conversión de nombres de columnas de BD (ej. `_str`, `_bit`) a propiedades Dart.
  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      // Uso de ?? '' para evitar nulos si el campo no viene en el JSON
      nombre: json['nombre_str'] ?? '',
      apellidos: json['apellidos_str'] ?? '',
      dni: json['dni_str'] ?? '',
      direccion: json['direccion_str'] ?? '',
      email: json['email_str'] ?? '',
      telefono: json['telefono_str'] ?? '',
      // Conversión de entero (bit) a booleano: 1 es true, cualquier otra cosa es false
      validado: json['validado_bit'] == 1,
      bloqueado: json['bloqueado_bit'] == 1,
      intentos: json['numintentos_int'] ?? 0,
      // Nota: Se mantiene como String, considerar DateTime.parse() si se requiere operar con fechas
      ultimoIntento: json['ultimointentologin_dtm'] ?? '',
      tipoUsuario: json['ktipodeusuario'] ?? '',
    );
  }
  Map<String, dynamic> toJson() => {
        'nombre_str': nombre,
        'apellidos_str': apellidos,
        'dni_str': dni,
        'direccion_str': direccion,
        'email_str': email,
        'telefono_str': telefono,
        'validado_bit': validado ? 1 : 0,
        'bloqueado_bit': bloqueado ? 1 : 0,
        'numintentos_int': intentos,
        'ultimointentologin_dtm': ultimoIntento,
        'ktipodeusuario': tipoUsuario,
      };
}
