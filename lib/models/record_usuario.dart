/// Modelo de datos que representa a un usuario del sistema.
class Usuario {
  final String kagricultor; // <--- 1. IDENTIFICADOR ÚNICO DE LA BASE DE DATOS
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
  final String prefAgrupacion; // Criterio dinámico de agrupación de movimientos (separado por comas)
  final String prefAgrupacionGastos; // Criterio dinámico de agrupación de gastos (separado por comas)

  Usuario({
    required this.kagricultor, // <--- 2. REQUERIDO EN EL CONSTRUCTOR
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
    required this.prefAgrupacion,
    required this.prefAgrupacionGastos
  });

  /// Crea una instancia de [Usuario] a partir de un mapa JSON.
  /// Maneja la conversión de nombres de columnas de BD (ej. `_str`, `_bit`) a propiedades Dart.
  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      // 3. CAPTURAMOS EL UUID QUE ENVÍA TU API AL HACER LOGIN
      kagricultor: json['kagricultor'] ?? '', 
      nombre: json['nombre_str'] ?? '',
      apellidos: json['apellidos_str'] ?? '',
      dni: json['dni_str'] ?? '',
      direccion: json['direccion_str'] ?? '',
      email: json['email_str'] ?? '',
      telefono: json['telefono_str'] ?? '',
      validado: json['validado_bit'] == 1,
      bloqueado: json['bloqueado_bit'] == 1,
      intentos: json['numintentos_int'] ?? 0,
      ultimoIntento: json['ultimointentologin_dtm'] ?? '',
      tipoUsuario: json['ktipodeusuario'] ?? '',
      prefAgrupacion: json['pref_agrupacion_str'] ?? '',
      prefAgrupacionGastos: json['pref_agrupacion_gastos_str'] ?? ''
    );
  }

  Map<String, dynamic> toJson() => {
        'kagricultor': kagricultor, // <--- 4. ADICIÓN EN EL CONTROLADOR JSON
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
        'pref_agrupacion_str': prefAgrupacion,
        'pref_agrupacion_gastos_str': prefAgrupacionGastos
      };
}