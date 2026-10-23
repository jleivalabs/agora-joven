import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/sesion_controller.dart';
import '../theme/app_theme.dart';
import '../utils/validadores.dart';
import '../widgets/marca.dart';

/// Registro de cuenta. Al terminar vuelve al acceso con un aviso; no inicia sesión.
class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _sesion = Get.find<SesionController>();
  bool _ocultarPassword = true;

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    FocusScope.of(context).unfocus();
    if (!_formulario.currentState!.validate()) return;
    final creada = await _sesion.registrar(
      nombre: _nombre.text,
      email: _email.text,
      password: _password.text,
    );
    if (creada && mounted) Get.back<void>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Form(
            key: _formulario,
            child: Obx(() {
              final enviando = _sesion.enviando.value;
              final error = _sesion.errorFormulario.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Marca(subtitulo: 'Crea tu cuenta para participar.'),
                  const SizedBox(height: AppSpacing.l),
                  if (error != null) ...[
                    Aviso(texto: error, esError: true),
                    const SizedBox(height: AppSpacing.m),
                  ],
                  TextFormField(
                    key: const Key('registro-nombre'),
                    controller: _nombre,
                    enabled: !enviando,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nombre visible',
                      helperText: 'Entre 2 y 60 caracteres.',
                      border: OutlineInputBorder(),
                    ),
                    validator: Validadores.nombre,
                  ),
                  const SizedBox(height: AppSpacing.m),
                  TextFormField(
                    key: const Key('registro-email'),
                    controller: _email,
                    enabled: !enviando,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      border: OutlineInputBorder(),
                    ),
                    validator: Validadores.correo,
                  ),
                  const SizedBox(height: AppSpacing.m),
                  TextFormField(
                    key: const Key('registro-password'),
                    controller: _password,
                    enabled: !enviando,
                    obscureText: _ocultarPassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _enviar(),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      helperText: 'Entre 8 y 128 caracteres.',
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
                    validator: Validadores.passwordNueva,
                  ),
                  const SizedBox(height: AppSpacing.l),
                  FilledButton(
                    key: const Key('registro-enviar'),
                    onPressed: enviando ? null : _enviar,
                    child: enviando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              semanticsLabel: 'Creando cuenta',
                            ),
                          )
                        : const Text('Crear cuenta'),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}
