import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Por favor, completa todos los campos', isError: true);
      return;
    }

    final emailRegex = RegExp(r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+');
    if (!emailRegex.hasMatch(email)) {
      _showSnackBar('Ingresa un correo electrónico válido', isError: true);
      return;
    }

    if (password.length < 6) {
      _showSnackBar('La contraseña debe tener al menos 6 caracteres',
          isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    var didNavigate = false;
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;
      didNavigate = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (context) => const HomeScreen(),
        ),
      );
    } on FirebaseException catch (e) {
      debugPrint(
        '[signInWithEmailAndPassword] FirebaseException '
        'code=${e.code} message=${e.message}',
      );
      String message;
      if (e.code == 'user-not-found') {
        message = 'No se encontró un usuario con ese correo.';
      } else if (e.code == 'wrong-password') {
        message = 'La contraseña es incorrecta.';
      } else {
        message = 'Ocurrió un error. Inténtalo de nuevo.';
      }
      _showSnackBar(message, isError: true);
    } catch (e, stackTrace) {
      debugPrint('[signInWithEmailAndPassword] non-Firebase error: $e');
      debugPrint('$stackTrace');
      _showSnackBar('Ocurrió un error inesperado.', isError: true);
    } finally {
      if (mounted && !didNavigate) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 80),
              Image.asset(
                'assets/logo_motoboxes.png',
                width: 180,
                height: 180,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.motorcycle, size: 100, color: Colors.black),
              ),
              const SizedBox(height: 48),
              const Text(
                'Bienvenido a MotoLink Pro',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Inicia sesión para continuar',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE31B23),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Text(
                        'INGRESAR',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
