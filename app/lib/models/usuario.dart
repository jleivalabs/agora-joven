class Usuario {
  const Usuario({
    required this.id,
    required this.nombre,
    required this.email,
    this.rol = 'usuario',
  });

  final int id;
  final String nombre;
  final String email;

  /// Rol según el servidor al iniciar o restaurar la sesión. Solo decide qué se muestra:
  /// el backend vuelve a comprobar el rol en cada acción administrativa.
  final String rol;

  bool get esAdministrador => rol == 'administrador';

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
    id: json['id'] as int,
    nombre: json['nombre'] as String,
    email: json['email'] as String,
    rol: (json['rol'] as String?) ?? 'usuario',
  );
}
