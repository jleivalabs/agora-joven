/// Configuración de compilación. Se cambia con --dart-define, sin tocar el código.
///
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8010
class AppConfig {
  AppConfig._();

  /// URL del backend propio. 10.0.2.2 es el equipo anfitrión visto desde el emulador Android.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8010',
  );

  static const Duration tiempoConexion = Duration(seconds: 8);
  static const Duration tiempoEnvio = Duration(seconds: 10);
  static const Duration tiempoRecepcion = Duration(seconds: 15);

  /// El backend espera hasta 25 s a Gemini; la app espera algo más para recibir su respuesta.
  static const Duration tiempoRecepcionAsistente = Duration(seconds: 40);
}
