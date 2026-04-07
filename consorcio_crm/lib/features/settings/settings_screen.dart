import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/router/app_router.dart';
import '../auth/profile_provider.dart';
import '../auth/admin_panel_screen.dart';

import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';

// ==========================================
// TELA PRINCIPAL DE AJUSTES
// ==========================================
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0, centerTitle: true,
        title: const Text('Ajustes', style: TextStyle(color: Color(0xFF1E293B), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
      ),
      body: profileAsync.when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
        error: (err, stack) => Center(child: Text('Erro ao carregar perfil: $err')),
        data: (profile) {
          final fullName = profile?.fullName ?? 'Usuário';
          
          // --- CORREÇÃO 1: NOME DO CARGO CORRETO NA TELA ---
          String roleName = 'Executivo de Vendas';
          final dbRole = profile?.role;
          
          if (dbRole == 'diretor' || dbRole == 'administrador') {
            roleName = 'Diretoria Global';
          } else if (dbRole == 'gerente') {
            roleName = 'Gerência Regional';
          } else if (dbRole == 'supervisor') {
            roleName = 'Supervisão Regional';
          } else if (dbRole == 'administrativo') {
            roleName = 'Acesso Administrativo';
          }

          final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U';

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeInDown(
                  duration: const Duration(milliseconds: 400),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))]),
                    child: Row(
                      children: [
                        Container(
                          height: 64, width: 64,
                          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]), shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]),
                          child: Center(child: Text(initial, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white))),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.5), overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFF4F7FE), borderRadius: BorderRadius.circular(8)), child: Text(roleName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                FadeInUp(duration: const Duration(milliseconds: 500), child: const Text('Preferências', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                const SizedBox(height: 12),
                FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  child: _buildSettingsGroup([
                    _buildSettingsItem(icon: Icons.person_outline_rounded, iconColor: const Color(0xFF0EA5E9), title: 'Editar Perfil', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfileScreen(currentName: fullName)))),
                    _buildDivider(),
                    _buildSettingsItem(icon: Icons.notifications_none_rounded, iconColor: const Color(0xFFF59E0B), title: 'Notificações', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()))),
                    _buildDivider(),
                    _buildSettingsItem(icon: Icons.lock_outline_rounded, iconColor: const Color(0xFF10B981), title: 'Privacidade e Senha', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PasswordChangeScreen()))),
                    
                    // --- CORREÇÃO 2: LIBERAR O BOTÃO PARA DIRETOR E ADMINISTRADOR ---
                    if (dbRole == 'gerente' || dbRole == 'diretor' || dbRole == 'administrador') ...[
                      _buildDivider(),
                      _buildSettingsItem(
                        icon: Icons.admin_panel_settings_rounded, 
                        iconColor: const Color(0xFF4F46E5), 
                        title: 'Centro de Comando', // Aproveitei e mudei o nome do botão para ficar o padrão
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen()))
                      ),
                    ],
                  ]),
                ),
                const SizedBox(height: 24),

                FadeInUp(duration: const Duration(milliseconds: 700), child: const Text('Suporte', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                const SizedBox(height: 12),
                FadeInUp(
                  duration: const Duration(milliseconds: 800),
                  child: _buildSettingsGroup([
                    _buildSettingsItem(icon: Icons.help_outline_rounded, iconColor: const Color(0xFF8B5CF6), title: 'Central de Ajuda', onTap: () => _showHelpCenter(context)),
                    _buildDivider(),
                    _buildSettingsItem(icon: Icons.description_outlined, iconColor: const Color(0xFF64748B), title: 'Termos de Uso', onTap: () {}),
                  ]),
                ),
                const SizedBox(height: 40),

                FadeInUp(
                  duration: const Duration(milliseconds: 900),
                  child: OutlinedButton.icon(
                    onPressed: () => _showLogoutConfirmation(context, ref),
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: const Text('Sair da Conta', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFEF4444), side: const BorderSide(color: Color(0xFFEF4444), width: 1.5), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))]), child: Column(children: children));
  }

  Widget _buildSettingsItem({required IconData icon, required Color iconColor, required String title, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 20)),
            const SizedBox(width: 16), Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))),
            const Icon(Icons.chevron_right_rounded, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() => const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)));

  void _showLogoutConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Sair do App', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        content: const Text('Tem certeza que deseja desconectar sua conta do CRM?', style: TextStyle(color: Colors.black54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), 
            onPressed: () { 
              Navigator.pop(ctx); 
              
              // 1. Apaga os dados do usuário atual da memória do Riverpod
              ref.invalidate(userProfileProvider);
              
              // 2. Chama a função de logout oficial da sua arquitetura
              ref.read(authStateProvider.notifier).logout(); 
            }, 
            child: const Text('Sim, Sair', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  void _showHelpCenter(BuildContext context) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 24),
            const Icon(Icons.support_agent_rounded, size: 56, color: Color(0xFF4F46E5)),
            const SizedBox(height: 16),
            const Text('Como podemos ajudar?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 8),
            const Text('Nossa equipe de suporte está pronta para tirar suas dúvidas sobre o CRM.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.chat_rounded, color: Color(0xFF10B981))),
              title: const Text('Falar no WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Atendimento rápido'),
              onTap: () async {
                final url = Uri.parse('https://wa.me/5585999999999?text=Olá, preciso de ajuda com o CRM Recon.');
                if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// SUB-TELAS DE CONFIGURAÇÃO
// ==========================================

// 1. TELA DE EDITAR PERFIL
class EditProfileScreen extends StatefulWidget {
  final String currentName;
  const EditProfileScreen({super.key, required this.currentName});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('profiles').update({'full_name': _nameController.text.trim()}).eq('id', userId);
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          const CustomSnackBar.success(message: 'Perfil atualizado com sucesso!'),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          const CustomSnackBar.error(message: 'Erro ao atualizar.'),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: const Color(0xFF1E293B), title: const Text('Editar Perfil', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Nome Completo', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: _isLoading ? null : _updateProfile,
                child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Text('Salvar Alterações', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// 2. TELA DE NOTIFICAÇÕES (Visual)
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _pushEnabled = true;
  bool _emailEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: const Color(0xFF1E293B), title: const Text('Notificações', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                activeColor: const Color(0xFF4F46E5),
                title: const Text('Notificações no App', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Avisos do supervisor em tempo real.'),
                value: _pushEnabled,
                onChanged: (val) => setState(() => _pushEnabled = val),
              ),
              const Divider(height: 1),
              SwitchListTile(
                activeColor: const Color(0xFF4F46E5),
                title: const Text('Resumo por E-mail', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Receba um relatório semanal da carteira.'),
                value: _emailEnabled,
                onChanged: (val) => setState(() => _emailEnabled = val),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 3. TELA DE PRIVACIDADE E SENHA
class PasswordChangeScreen extends StatefulWidget {
  const PasswordChangeScreen({super.key});
  @override
  State<PasswordChangeScreen> createState() => _PasswordChangeScreenState();
}

class _PasswordChangeScreenState extends State<PasswordChangeScreen> {
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _updatePassword() async {
    if (_passwordController.text.length < 6) {
      showTopSnackBar(
        Overlay.of(context),
        const CustomSnackBar.error(message: 'A senha deve ter no mínimo 6 caracteres.'),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: _passwordController.text));
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          const CustomSnackBar.success(message: 'Senha atualizada com segurança!'),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          const CustomSnackBar.error(message: 'Erro ao atualizar senha.'),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: const Color(0xFF1E293B), title: const Text('Segurança', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Nova Senha', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: _isLoading ? null : _updatePassword,
                child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Text('Atualizar Senha', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}