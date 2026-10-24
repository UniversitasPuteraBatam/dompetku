import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/field_label.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;
  bool _isLoggingIn = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoggingIn || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoggingIn = true);
    try {
      final user = await (widget.authService ?? AuthService()).login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
        (route) => false,
        arguments: user,
      );
    } on AuthApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat terhubung ke server. Periksa koneksi.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoggingIn = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppLogo(compact: true),
                  const SizedBox(height: 42),
                  Text(
                    'Selamat Datang',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.palette.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Masuk ke akun DompetKu kamu',
                    style: TextStyle(color: context.palette.secondaryText),
                  ),
                  const SizedBox(height: 30),
                  const FieldLabel('Email'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      hintText: 'nama@email.com',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) return 'Email wajib diisi';
                      if (!RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      ).hasMatch(email)) {
                        return 'Masukkan alamat email yang valid';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  const FieldLabel('Password'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _hidePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      hintText: 'Masukkan password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: _hidePassword
                            ? 'Tampilkan password'
                            : 'Sembunyikan password',
                        onPressed: () =>
                            setState(() => _hidePassword = !_hidePassword),
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) => value == null || value.length < 6
                        ? 'Password minimal 6 karakter'
                        : null,
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: _isLoggingIn ? null : _login,
                    child: const Text('Login'),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          'Belum punya akun? ',
                          style: TextStyle(
                            color: context.palette.secondaryText,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/register'),
                        child: const Text('Daftar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
