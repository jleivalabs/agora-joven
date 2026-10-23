import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/sesion_controller.dart';
import '../theme/app_theme.dart';
import '../utils/validadores.dart';
import '../widgets/marca.dart';
import 'registro_screen.dart';

/// Inicio de sesión. El estado local (campos, mostrar contraseña) vive aquí; el de sesión,
/// en [SesionController].
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formulario = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _sesion = Get.find<SesionController>();
  bool _ocultarPassword = true;

  @override
  void initState() {
    super.initState();
    _email.text = _sesion.emailSugerido.value ?? '';
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _enviar() {
    FocusScope.of(context).unfocus();
    if (!_formulario.currentState!.validate()) return;
    _sesion.iniciarSesion(_email.text, _password.text);
  }

  Future<void> _irARegistro() async {
    _sesion.limpiarMensajesFormulario();
    await Get.to<void>(() => const RegistroScreen());
    if (!mounted) return;
    final sugerido = _sesion.emailSugerido.value;
    if (sugerido != null) {
      _email.text = sugerido;
      _password.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Form(
              key: _formulario,
              child: Obx(() {
                final enviando = _sesion.enviando.value;
                final aviso = _sesion.aviso.value;
                final error = _sesion.errorFormulario.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Marca(
                      subtitulo:
                          'Comprende temas públicos y consulta debates '
                          'ciudadanos.',
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Iniciar sesión',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    if (aviso != null) ...[
                      Aviso(texto: aviso),
                      const SizedBox(height: AppSpacing.m),
                    ],
                    if (error != null) ...[
                      Aviso(texto: error, esError: true),
                      const SizedBox(height: AppSpacing.m),
                    ],
                    TextFormField(
                      key: const Key('login-email'),
                      controller: _email,
                      enabled: !enviando,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Correo',
                        border: OutlineInputBorder(),
                      ),
                      validator: Validadores.correo,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    TextFormField(
                      key: const Key('login-password'),
                      controller: _password,
                      enabled: !enviando,
                      obscureText: _ocultarPassword,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _enviar(),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _ocultarPassword
                              ? 'Mostrar contraseña'
                              : 'Ocultar contraseña',
                          icon: Icon(
                            _ocultarPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(
                            () => _ocultarPassword = !_ocultarPassword,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          Validadores.requerido(v, 'Escribe tu contraseña.'),
                    ),
                    const SizedBox(height: AppSpacing.l),
                    FilledButton(
                      key: const Key('login-enviar'),
                      onPressed: enviando ? null : _enviar,
                      child: enviando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                semanticsLabel: 'Iniciando sesión',
                              ),
                            )
                          : const Text('Entrar'),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    TextButton(
                      onPressed: enviando ? null : _irARegistro,
                      child: const Text('¿No tienes cuenta? Crear una cuenta'),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
