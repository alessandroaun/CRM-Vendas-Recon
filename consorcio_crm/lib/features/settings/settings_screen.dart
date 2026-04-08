import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
          // Adicione o campo avatarUrl no seu modelo de profile
          final avatarUrl = profile?.avatarUrl; 
          
          // --- CORREÇÃO 1: NOME DO CARGO CORRETO NA TELA ---
          String roleName = 'Vendedor';
          final dbRole = profile?.role;
          
          if (dbRole == 'diretor' || dbRole == 'administrador') {
            roleName = 'Diretoria';
          } else if (dbRole == 'gerente') {
            roleName = 'Gerente de Vendas';
          } else if (dbRole == 'supervisor') {
            roleName = 'Supervisor de Vendas';
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
                          decoration: BoxDecoration(
                            shape: BoxShape.circle, 
                            boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                            gradient: (avatarUrl == null || avatarUrl.isEmpty) ? const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]) : null,
                            image: (avatarUrl != null && avatarUrl.isNotEmpty)
                                ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                                : null,
                          ),
                          child: (avatarUrl == null || avatarUrl.isEmpty) 
                              ? Center(child: Text(initial, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)))
                              : null,
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
                    _buildSettingsItem(icon: Icons.person_outline_rounded, iconColor: const Color(0xFF0EA5E9), title: 'Editar Perfil', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfileScreen(currentName: fullName, currentAvatarUrl: avatarUrl)))),
                    _buildDivider(),
                    _buildSettingsItem(icon: Icons.notifications_none_rounded, iconColor: const Color(0xFFF59E0B), title: 'Notificações', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()))),
                    _buildDivider(),
                    _buildSettingsItem(icon: Icons.lock_outline_rounded, iconColor: const Color(0xFF10B981), title: 'Alterar Senha', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PasswordChangeScreen()))),
                    
                    // --- CORREÇÃO 2: LIBERAR O BOTÃO PARA DIRETOR E ADMINISTRADOR ---
                    if (dbRole == 'gerente' || dbRole == 'diretor' || dbRole == 'administrador') ...[
                      _buildDivider(),
                      _buildSettingsItem(
                        icon: Icons.admin_panel_settings_rounded, 
                        iconColor: const Color(0xFF4F46E5), 
                        title: 'Centro de Comando', 
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
                    _buildSettingsItem(icon: Icons.description_outlined, iconColor: const Color(0xFF64748B), title: 'Termos de Uso', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsOfUseScreen()))),
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

                // --- VERSÃO DO APP NO RODAPÉ ---
                FadeInUp(
                  duration: const Duration(milliseconds: 1000),
                  child: const Center(
                    child: Text(
                      'Vértice CRM - Versão 1.0.0',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
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
                final url = Uri.parse('https://wa.me/5585999999999?text=Olá, preciso de ajuda com o Vértice CRM.');
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

// 1. TELA DE EDITAR PERFIL (Atualizada com Consumer)
class EditProfileScreen extends ConsumerStatefulWidget {
  final String currentName;
  final String? currentAvatarUrl;
  
  const EditProfileScreen({super.key, required this.currentName, this.currentAvatarUrl});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nameController;
  bool _isLoading = false;
  Uint8List? _imageBytes;
  String? _imageExt;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageExt = pickedFile.name.split('.').last;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      String? newAvatarUrl = widget.currentAvatarUrl;

      // Se selecionou imagem, faz o upload no bucket "avatars"
      if (_imageBytes != null) {
        final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.$_imageExt';
        
        await Supabase.instance.client.storage
            .from('avatars')
            .uploadBinary(fileName, _imageBytes!);
            
        newAvatarUrl = Supabase.instance.client.storage
            .from('avatars')
            .getPublicUrl(fileName);
      }

      // Atualiza no banco de dados
      await Supabase.instance.client.from('profiles').update({
        'full_name': _nameController.text.trim(),
        if (newAvatarUrl != null) 'avatar_url': newAvatarUrl,
      }).eq('id', userId);

      if (mounted) {
        // A MÁGICA ACONTECE AQUI: Avisa o Riverpod para recarregar os dados do perfil!
        ref.invalidate(userProfileProvider);
        
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    height: 120, width: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                      image: _imageBytes != null 
                        ? DecorationImage(image: MemoryImage(_imageBytes!), fit: BoxFit.cover)
                        : (widget.currentAvatarUrl != null && widget.currentAvatarUrl!.isNotEmpty
                            ? DecorationImage(image: NetworkImage(widget.currentAvatarUrl!), fit: BoxFit.cover)
                            : null),
                    ),
                    child: (_imageBytes == null && (widget.currentAvatarUrl == null || widget.currentAvatarUrl!.isEmpty))
                        ? const Icon(Icons.person_rounded, size: 60, color: Color(0xFF94A3B8))
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
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

// 2. TELA DE NOTIFICAÇÕES (Funcional)
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _pushEnabled = true;
  bool _emailEnabled = false;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Busca as configurações salvas na memória do celular/navegador
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushEnabled = prefs.getBool('pushEnabled') ?? true;
      _emailEnabled = prefs.getBool('emailEnabled') ?? false;
      _soundEnabled = prefs.getBool('soundEnabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
    });
  }

  // Salva a configuração assim que o usuário clica no botão
  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: const Color(0xFF1E293B), title: const Text('Notificações', style: TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 8, bottom: 12),
              child: Text('Canais de Aviso', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
            ),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    activeColor: const Color(0xFF4F46E5),
                    title: const Text('Notificações no App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: const Text('Avisos do supervisor em tempo real.', style: TextStyle(fontSize: 13)),
                    value: _pushEnabled,
                    onChanged: (val) {
                      setState(() => _pushEnabled = val);
                      _saveSetting('pushEnabled', val);
                    },
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  SwitchListTile(
                    activeColor: const Color(0xFF4F46E5),
                    title: const Text('Resumo por E-mail', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: const Text('Receba um relatório semanal da carteira.', style: TextStyle(fontSize: 13)),
                    value: _emailEnabled,
                    onChanged: (val) {
                      setState(() => _emailEnabled = val);
                      _saveSetting('emailEnabled', val);
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // --- OPÇÕES SECUNDÁRIAS ---
            const Padding(
              padding: EdgeInsets.only(left: 8, bottom: 12),
              child: Text('Alertas do Dispositivo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
            ),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    activeColor: const Color(0xFF10B981),
                    title: const Text('Som de Notificação', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: const Text('Tocar som ao receber nova mensagem.', style: TextStyle(fontSize: 13)),
                    value: _soundEnabled,
                    // Desativa o som se as notificações principais estiverem desligadas
                    onChanged: _pushEnabled ? (val) {
                      setState(() => _soundEnabled = val);
                      _saveSetting('soundEnabled', val);
                    } : null, 
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  SwitchListTile(
                    activeColor: const Color(0xFF10B981),
                    title: const Text('Vibração', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: const Text('Vibrar o celular com novos alertas.', style: TextStyle(fontSize: 13)),
                    value: _vibrationEnabled,
                    // Desativa a vibração se as notificações principais estiverem desligadas
                    onChanged: _pushEnabled ? (val) {
                      setState(() => _vibrationEnabled = val);
                      _saveSetting('vibrationEnabled', val);
                    } : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 3. TELA DE ALTERAR SENHA (Atualizada com Validação e Reset)
class PasswordChangeScreen extends StatefulWidget {
  const PasswordChangeScreen({super.key});
  @override
  State<PasswordChangeScreen> createState() => _PasswordChangeScreenState();
}

class _PasswordChangeScreenState extends State<PasswordChangeScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _repeatPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isResetting = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _repeatPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final currentPass = _currentPasswordController.text;
    final newPass = _newPasswordController.text;
    final repeatPass = _repeatPasswordController.text;

    if (currentPass.isEmpty || newPass.isEmpty || repeatPass.isEmpty) {
      showTopSnackBar(Overlay.of(context), const CustomSnackBar.error(message: 'Preencha todos os campos.'));
      return;
    }

    if (newPass.length < 6) {
      showTopSnackBar(Overlay.of(context), const CustomSnackBar.error(message: 'A nova senha deve ter no mínimo 6 caracteres.'));
      return;
    }

    if (newPass != repeatPass) {
      showTopSnackBar(Overlay.of(context), const CustomSnackBar.error(message: 'As novas senhas não coincidem.'));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null || currentUser.email == null) throw Exception('Sessão inválida.');

      // 1. Tenta fazer login com a senha atual para garantir que está correta
      try {
        await Supabase.instance.client.auth.signInWithPassword(
          email: currentUser.email!,
          password: currentPass,
        );
      } on AuthException catch (_) {
        if (mounted) {
          showTopSnackBar(Overlay.of(context), const CustomSnackBar.error(message: 'A senha atual está incorreta.'));
          setState(() => _isLoading = false);
        }
        return; // Para a execução se a senha antiga estiver errada
      }

      // 2. Se passou, atualiza para a senha nova
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPass));
      
      if (mounted) {
        showTopSnackBar(Overlay.of(context), const CustomSnackBar.success(message: 'Senha atualizada com segurança!'));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(Overlay.of(context), const CustomSnackBar.error(message: 'Erro ao atualizar senha. Tente novamente.'));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendResetLink() async {
    setState(() => _isResetting = true);
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null || currentUser.email == null) throw Exception('Sessão inválida.');

      // Dispara o e-mail de recuperação do Supabase
      await Supabase.instance.client.auth.resetPasswordForEmail(currentUser.email!);
      
      if (mounted) {
        showTopSnackBar(Overlay.of(context), const CustomSnackBar.success(message: 'Link de recuperação enviado para o seu e-mail!'));
        // Limpa os campos por precaução
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _repeatPasswordController.clear();
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(Overlay.of(context), const CustomSnackBar.error(message: 'Erro ao solicitar link de recuperação.'));
      }
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: const Color(0xFF1E293B), title: const Text('Alterar Senha', style: TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Para atualizar sua credencial de acesso, confirme sua senha atual e digite a nova.', style: TextStyle(color: Colors.black54, fontSize: 14)),
            const SizedBox(height: 24),
            
            TextField(
              controller: _currentPasswordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Senha Atual', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Nova Senha', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _repeatPasswordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Repita a Nova Senha', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
            ),
            const SizedBox(height: 32),
            
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: _isLoading || _isResetting ? null : _updatePassword,
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : const Text('Atualizar Senha', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            const SizedBox(height: 24),
            
            const Divider(color: Color(0xFFE2E8F0), thickness: 1),
            const SizedBox(height: 16),
            
            // Botão para esqueci a senha
            TextButton.icon(
              onPressed: _isLoading || _isResetting ? null : _sendResetLink,
              icon: _isResetting 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Color(0xFF4F46E5), strokeWidth: 2))
                : const Icon(Icons.email_outlined, color: Color(0xFF4F46E5)),
              label: const Text('Esqueci minha senha (Enviar link por e-mail)', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
            )
          ],
        ),
      ),
    );
  }
}

// 4. TELA DE TERMOS DE USO
class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0, 
        foregroundColor: const Color(0xFF1E293B), 
        title: const Text('Termos de Uso', style: TextStyle(fontWeight: FontWeight.bold))
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'Termos de Uso e Privacidade\nVértice CRM',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), height: 1.3),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Última atualização: Abril de 2026\n', style: TextStyle(color: Colors.black54, fontSize: 13)),
              
              _buildSectionTitle('1. Aceitação dos Termos'),
              _buildSectionText('Ao acessar e utilizar o Vértice CRM, você concorda expressamente com as regras descritas nestes Termos de Uso. Este sistema é uma ferramenta de trabalho corporativa e seu uso deve ser estritamente profissional.'),
              
              _buildSectionTitle('2. Inserção de Contatos e Responsabilidade'),
              _buildSectionText('Você compreende e concorda que é o ÚNICO responsável por todos os dados de clientes e contatos (leads) inseridos na plataforma. Você garante que possui autorização e base legal adequada para cadastrar, contatar e gerenciar as informações de cada cliente no sistema, respeitando as normas vigentes de proteção de dados (LGPD).'),
              
              _buildSectionTitle('3. Segurança dos Dados'),
              _buildSectionText('Todas as informações inseridas no Vértice CRM estão seguras, criptografadas e hospedadas em servidores de alta proteção. A empresa se compromete a garantir a integridade do banco de dados e impedir acessos não autorizados. No entanto, você é inteiramente responsável por manter a confidencialidade da sua senha e não compartilhar seu acesso com terceiros.'),
              
              _buildSectionTitle('4. Uso Adequado da Ferramenta'),
              _buildSectionText('É terminantemente proibido utilizar o sistema para envio de spam, fraudes, ou registrar informações falsas de negociações. O Vértice CRM monitora ativamente atividades suspeitas para proteger a integridade comercial da empresa.'),
              
              _buildSectionTitle('5. Suspensão de Conta'),
              _buildSectionText('A gestão reserva-se o direito de suspender, bloquear ou cancelar o acesso de qualquer usuário que viole as regras de negócio, utilize o sistema de má-fé ou insira dados de forma negligente, sem aviso prévio.'),
              
              const SizedBox(height: 32),
              const Center(
                child: Text('© 2026 Vértice CRM. Todos os direitos reservados.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
    );
  }

  Widget _buildSectionText(String text) {
    return Text(text, style: const TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.6), textAlign: TextAlign.justify);
  }
}