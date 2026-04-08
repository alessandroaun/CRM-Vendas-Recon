import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart'; // Animações de entrada
import '../auth/profile_provider.dart';

import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';

import '../../core/router/app_router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await ref.read(authStateProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        // --- A MÁGICA ACONTECE AQUI ---
        // Força o Riverpod a apagar o cache antigo e buscar o ID do novo usuário logado!
        ref.invalidate(userProfileProvider);
        // ------------------------------

      } on AuthException catch (e) {
        _showError('Erro no acesso: ${e.message}');
      } catch (e) {
        _showError('Ocorreu um erro inesperado.');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // --- FUNÇÃO DE ESQUECI A SENHA ---
  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text);
    bool isResetting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Recuperar Senha', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Digite seu e-mail corporativo. Enviaremos um link para você redefinir sua senha.',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'E-mail',
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isResetting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: isResetting
                    ? null
                    : () async {
                        final email = resetEmailController.text.trim();
                        if (email.isEmpty || !email.contains('@')) {
                          showTopSnackBar(Overlay.of(context), const CustomSnackBar.error(message: 'Digite um e-mail válido.'));
                          return;
                        }

                        setStateDialog(() => isResetting = true);
                        try {
                          await Supabase.instance.client.auth.resetPasswordForEmail(email);
                          if (mounted) {
                            showTopSnackBar(Overlay.of(context), const CustomSnackBar.success(message: 'Se o e-mail existir, um link foi enviado!'));
                            Navigator.pop(ctx);
                          }
                        } catch (e) {
                          if (mounted) {
                            showTopSnackBar(Overlay.of(context), const CustomSnackBar.error(message: 'Erro ao solicitar recuperação.'));
                          }
                        } finally {
                          if (mounted) setStateDialog(() => isResetting = false);
                        }
                      },
                child: isResetting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Enviar Link', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showError(String message) {
    showTopSnackBar(
      Overlay.of(context),
      CustomSnackBar.error(
        message: message,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fundo escuro com gradiente premium
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: FadeInUp(
                      duration: const Duration(milliseconds: 800),
                      child: Container(
                        padding: const EdgeInsets.all(32.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // --- LOGO VÉRTICE CRM STANDALONE ---
                              Center(
                                child: Image.network(
                                  'https://kygnotvsbigxitgoisds.supabase.co/storage/v1/object/public/logo/vertice_logo.png',
                                  height: 200, // <-- AUMENTE AQUI PRA DEIXAR MAIOR (tente 180, 200...)
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(Icons.business_rounded, size: 80, color: Color(0xFF4F46E5));
                                  },
                                ),
                              ),
                              
                              // <-- REDUZI O ESPAÇO PRA 8 PRA FICAR BEM COLADINHO (se precisar, mude pra 0)
                              const SizedBox(height: 0),
                              
                              // Campos de Texto Estilizados
                              _buildTextField(
                                controller: _emailController,
                                label: 'E-mail Corporativo',
                                icon: Icons.email_outlined,
                                isEmail: true,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _passwordController,
                                label: 'Senha de Acesso',
                                icon: Icons.lock_outline,
                                isPassword: true,
                              ),
                              
                              // --- BOTÃO DE ESQUECI A SENHA ---
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _isLoading ? null : _showForgotPasswordDialog,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Esqueci a senha', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                              ),
                              const SizedBox(height: 24),
                              
                              // Botão Premium
                              ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Color(0xFF4F46E5), strokeWidth: 3))
                                    : const Text('Entrar no Sistema', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              // --- RODAPÉ COM A VERSÃO ---
              FadeInUp(
                duration: const Duration(milliseconds: 1000),
                child: const Padding(
                  padding: EdgeInsets.only(bottom: 24.0, top: 16.0),
                  child: Text(
                    'Vértice CRM - Versão 1.0.0',
                    style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, bool isPassword = false, bool isEmail = false}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      style: const TextStyle(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54),
        prefixIcon: Icon(icon, color: const Color(0xFF0F172A)),
        filled: true,
        fillColor: const Color(0xFFF1F5F9), // Fundo acinzentado super claro
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Campo obrigatório';
        if (isEmail && !value.contains('@')) return 'E-mail inválido';
        if (isPassword && value.length < 6) return 'Mínimo de 6 caracteres';
        return null;
      },
    );
  }
}