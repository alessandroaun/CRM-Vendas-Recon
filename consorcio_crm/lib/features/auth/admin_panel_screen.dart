import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';

// --- PROVEDORES DE DADOS ---
final teamsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return Supabase.instance.client.from('teams').stream(primaryKey: ['id']).order('name');
});

final allProfilesProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return Supabase.instance.client.from('profiles').stream(primaryKey: ['id']).order('full_name');
});

final regionsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return Supabase.instance.client.from('regions').stream(primaryKey: ['id']).order('name');
});

class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});
  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  String _selectedRole = 'vendedor';
  bool _isLoading = false;
  
  // VARIÁVEIS DE CONTROLE DE ACESSO
  String? _currentUserRole;
  String? _currentUserRegion;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchCurrentUserRole();
  }

  // BUSCA CARGO E REGIÃO DO USUÁRIO LOGADO
  Future<void> _fetchCurrentUserRole() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      final res = await Supabase.instance.client.from('profiles').select('role, regiao').eq('id', userId).single();
      if (mounted) setState(() {
        _currentUserRole = res['role'] as String?;
        _currentUserRegion = res['regiao'] as String?;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<bool> _invokeAdminFunction(String action, Map<String, dynamic> bodyExtras, String successMessage) async {
    setState(() => _isLoading = true);
    try {
      final body = {'action': action, ...bodyExtras};
      await Supabase.instance.client.functions.invoke('admin-users', body: body);
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage), backgroundColor: const Color(0xFF10B981)));

      ref.invalidate(teamsProvider);
      ref.invalidate(allProfilesProvider);
      ref.invalidate(regionsProvider);

      return true;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
      return false;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =========================================================
  // ABA 1: NOVA CONTA 
  // =========================================================
  void _createUser() async {
    if (!_formKey.currentState!.validate()) return;
    await _invokeAdminFunction('create_user', {
      'fullName': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'password': _passwordController.text,
      'userRole': _selectedRole,
    }, 'Conta criada com sucesso! (Vá em "Gerenciar" para atribuir equipe/região)');
    
    if (!_isLoading) {
      _nameController.clear(); _emailController.clear(); _passwordController.clear();
      setState(() => _selectedRole = 'vendedor');
    }
  }

  // =========================================================
  // ABA 2: GERENCIAR CONTAS 
  // =========================================================
  
  void _assignRegionPrompt(String userId, String? currentRegion, List<String> uniqueRegions) {
    String? newRegion = currentRegion;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        title: const Text('Definir Região do Gerente', style: TextStyle(fontWeight: FontWeight.bold)),
        content: DropdownButton<String>(
          isExpanded: true, value: uniqueRegions.contains(newRegion) ? newRegion : null, hint: const Text('Selecione uma região existente'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Nenhuma / Limpar')),
            ...uniqueRegions.map((r) => DropdownMenuItem(value: r, child: Text(r)))
          ],
          onChanged: (val) => setStateDialog(() => newRegion = val),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
            onPressed: () { Navigator.pop(ctx); _invokeAdminFunction('assign_user_region', {'targetUserId': userId, 'regionName': newRegion}, 'Região definida!'); },
            child: const Text('Salvar', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    ));
  }

  void _assignTeamPrompt(String userId, String? currentTeamId, List<Map<String, dynamic>> teams) {
    String? newTeam = currentTeamId;
    
    // Se for gerente, mostra apenas as equipes da região dele
    final availableTeams = _currentUserRole == 'gerente' 
        ? teams.where((t) => t['regiao'] == _currentUserRegion).toList() 
        : teams;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        title: const Text('Definir Equipe', style: TextStyle(fontWeight: FontWeight.bold)),
        content: DropdownButton<String>(
          isExpanded: true, value: newTeam, hint: const Text('Selecione uma equipe'),
          items: [ const DropdownMenuItem(value: null, child: Text('Sem equipe')), ...availableTeams.map((t) => DropdownMenuItem(value: t['id'].toString(), child: Text('${t['name']} (${t['regiao'] ?? 'Sem região'})'))).toList() ],
          onChanged: (val) => setStateDialog(() => newTeam = val),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
            onPressed: () { Navigator.pop(ctx); _invokeAdminFunction('assign_user_team', {'targetUserId': userId, 'teamId': newTeam}, 'Equipe definida!'); },
            child: const Text('Salvar', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    ));
  }

  void _editUserPrompt(String userId, String currentName, String currentRole) {
    final nameCtrl = TextEditingController(text: currentName);
    final emailCtrl = TextEditingController();
    String selectedRole = currentRole;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        title: const Text('Editar Dados', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome Completo')), const SizedBox(height: 16),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Novo E-mail (Opcional)')), const SizedBox(height: 16),
              DropdownButton<String>(
                isExpanded: true, value: selectedRole,
                items: [ 
                  const DropdownMenuItem(value: 'vendedor', child: Text('Vendedor')), 
                  const DropdownMenuItem(value: 'supervisor', child: Text('Supervisor')), 
                  if (_currentUserRole != 'gerente' || selectedRole == 'gerente')
                    const DropdownMenuItem(value: 'gerente', child: Text('Gerente')), 
                  if ((_currentUserRole != 'gerente' && _currentUserRole != 'administrativo') || selectedRole == 'diretor' || selectedRole == 'administrativo') ...[
                    const DropdownMenuItem(value: 'diretor', child: Text('Diretor')), 
                    const DropdownMenuItem(value: 'administrativo', child: Text('Administrativo (Apenas Painel)')), 
                  ]
                ],
                onChanged: (val) => setStateDialog(() => selectedRole = val!),
              ),
            ],
          ),
        ),
        actions: [ TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)), onPressed: () { Navigator.pop(ctx); _invokeAdminFunction('update_user', { 'targetUserId': userId, 'fullName': nameCtrl.text.trim(), 'email': emailCtrl.text.trim(), 'userRole': selectedRole, }, 'Dados atualizados com sucesso!'); }, child: const Text('Salvar', style: TextStyle(color: Colors.white)),) ],
      ),
    ));
  }

  // =========================================================
  // ABA 3: GERENCIAR EQUIPES E REGIÕES 
  // =========================================================
  
  void _createRegionPrompt(List<dynamic> teams) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Nova Região', style: TextStyle(fontWeight: FontWeight.bold)),
      content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Nome da Região', border: OutlineInputBorder())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
          onPressed: () async {
            final name = ctrl.text.trim();
            if (name.isNotEmpty) {
              Navigator.pop(ctx); 
              await _invokeAdminFunction('create_region', {'regionName': name}, 'Região $name inicializada!');
              _selectRegionTeamsPrompt(name, teams);
            }
          },
          child: const Text('Avançar', style: TextStyle(color: Colors.white)),
        )
      ],
    ));
  }

  void _selectRegionTeamsPrompt(String regionName, List<dynamic> teams) {
    List<String> tempSelected = teams.where((t) => t['regiao'] == regionName).map((t) => t['id'].toString()).toList();
    
    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        title: Text('Equipes da Região: $regionName', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: teams.isEmpty 
          ? const Text('Nenhuma equipe cadastrada no sistema.') 
          : ListView.builder(
            shrinkWrap: true,
            itemCount: teams.length,
            itemBuilder: (ctx2, i) {
              final t = teams[i];
              final tId = t['id'].toString();
              final isOtherRegion = (t['regiao'] != null && t['regiao'] != regionName && t['regiao'].toString().trim().isNotEmpty);

              return CheckboxListTile(
                title: Text(t['name']),
                subtitle: isOtherRegion ? Text('Atualmente em: ${t['regiao']}', style: const TextStyle(color: Colors.orange, fontSize: 11)) : null,
                value: tempSelected.contains(tId),
                activeColor: const Color(0xFF4F46E5),
                onChanged: (val) {
                  setStateDialog(() {
                    if (val == true) tempSelected.add(tId); else tempSelected.remove(tId);
                  });
                }
              );
            }
          )
        ),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
            onPressed: () {
              Navigator.pop(ctx);
              _invokeAdminFunction('update_region_teams', {'regionName': regionName, 'managedTeams': tempSelected}, 'Equipes salvas com sucesso!');
            },
            child: const Text('Salvar', style: TextStyle(color: Colors.white))
          )
        ]
      )
    ));
  }

  void _manageTeamPrompt({String? teamId, String? currentName, String? currentRegion, required List<String> uniqueRegions}) {
    final nameCtrl = TextEditingController(text: currentName);
    
    // Se for gerente, a região dele já fica fixada e invisível
    String? selRegion = _currentUserRole == 'gerente' ? _currentUserRegion : currentRegion;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        title: Text(teamId == null ? 'Nova Equipe' : 'Editar Equipe', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome da Equipe', border: OutlineInputBorder())), 
              
              if (_currentUserRole != 'gerente') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: uniqueRegions.contains(selRegion) ? selRegion : null, decoration: const InputDecoration(labelText: 'Região (Opcional)', border: OutlineInputBorder()),
                  items: [ const DropdownMenuItem(value: null, child: Text('Nenhuma')), ...uniqueRegions.map((r) => DropdownMenuItem(value: r, child: Text(r))) ],
                  onChanged: (val) => setStateDialog(() => selRegion = val),
                ),
              ] else ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                  child: Text('Pertencente à região: ${_currentUserRegion ?? "Não definida"}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                )
              ]
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              if (teamId == null) {
                _invokeAdminFunction('create_team', {'teamName': nameCtrl.text.trim(), 'regionName': selRegion}, 'Equipe criada!');
              } else {
                _invokeAdminFunction('update_team_entity', {'targetTeamId': teamId, 'teamName': nameCtrl.text.trim(), 'regionName': selRegion}, 'Equipe atualizada!');
              }
            },
            child: const Text('Salvar', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    ));
  }

  void _manageRegionPrompt(String regionName, List<dynamic> teams) {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 16), Text('Gerenciar Região: $regionName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const Divider(),
        ListTile(leading: const Icon(Icons.checklist_rounded, color: Colors.green), title: const Text('Selecionar Equipes'), onTap: () { Navigator.pop(ctx); _selectRegionTeamsPrompt(regionName, teams); }),
        ListTile(leading: const Icon(Icons.edit, color: Colors.blue), title: const Text('Renomear Região'), onTap: () {
          Navigator.pop(ctx);
          final ctrl = TextEditingController(text: regionName);
          showDialog(context: context, builder: (ctx2) => AlertDialog(
            title: const Text('Renomear'), content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Novo Nome', border: OutlineInputBorder())),
            actions: [ TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Cancelar')), ElevatedButton(onPressed: () { Navigator.pop(ctx2); _invokeAdminFunction('rename_region', {'oldRegionName': regionName, 'newRegionName': ctrl.text.trim()}, 'Região renomeada!'); }, child: const Text('Salvar')) ],
          ));
        }),
        ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('Excluir Região', style: TextStyle(color: Colors.red)), onTap: () {
          Navigator.pop(ctx);
          showDialog(context: context, builder: (ctx2) => AlertDialog(
            title: const Text('Atenção'), content: const Text('Isso removerá esta região de todas as equipes e gerentes. Deseja continuar?'),
            actions: [ TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Cancelar')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () { Navigator.pop(ctx2); _invokeAdminFunction('delete_region', {'oldRegionName': regionName}, 'Região excluída!'); }, child: const Text('Excluir', style: TextStyle(color: Colors.white))) ],
          ));
        }),
        const SizedBox(height: 16),
      ]),
    ));
  }

  // =========================================================
  // INTERFACE PRINCIPAL
  // =========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, elevation: 0,
        title: const Text('Centro de Comando', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70), tooltip: 'Desconectar',
            onPressed: () {
              showDialog(context: context, builder: (ctx) => AlertDialog(
                title: const Text('Sair do Sistema', style: TextStyle(fontWeight: FontWeight.bold)),
                content: const Text('Deseja realmente desconectar da sua conta?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                  ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () async {
                    Navigator.pop(ctx); await Supabase.instance.client.auth.signOut();
                    if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                  }, child: const Text('Sair', style: TextStyle(color: Colors.white)))
                ],
              ));
            },
          )
        ],
        bottom: TabBar(
          controller: _tabController, isScrollable: true, indicatorColor: const Color(0xFFD97706), labelColor: const Color(0xFFD97706), unselectedLabelColor: Colors.white70,
          tabs: [
            const Tab(icon: Icon(Icons.person_add_rounded), text: 'Nova Conta'), 
            const Tab(icon: Icon(Icons.manage_accounts_rounded), text: 'Gerenciar Contas'), 
            // NOME DA TERCEIRA ABA DINÂMICO!
            Tab(icon: const Icon(Icons.business_rounded), text: _currentUserRole == 'gerente' ? 'Equipes' : 'Equipes/Regiões')
          ],
        ),
      ),
      body: TabBarView( controller: _tabController, children: [ _buildCreateTab(), _buildManageTab(), _buildTeamsTab() ], ),
    );
  }

  Widget _buildCreateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: FadeInUp(
        child: Container(
          padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))]),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dados Base', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))), const SizedBox(height: 16),
                _buildTextField(controller: _nameController, label: 'Nome Completo', icon: Icons.person_outline), const SizedBox(height: 16),
                _buildTextField(controller: _emailController, label: 'E-mail Corporativo', icon: Icons.email_outlined, isEmail: true), const SizedBox(height: 16),
                _buildTextField(controller: _passwordController, label: 'Senha Inicial', icon: Icons.lock_outline, isPassword: true), const SizedBox(height: 24),
                const Text('Nível de Acesso', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))), const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedRole, isExpanded: true, dropdownColor: Colors.white,
                      items: [ 
                        const DropdownMenuItem(value: 'vendedor', child: Text('Vendedor')), 
                        const DropdownMenuItem(value: 'supervisor', child: Text('Supervisor')), 
                        if (_currentUserRole != 'gerente')
                          const DropdownMenuItem(value: 'gerente', child: Text('Gerente')), 
                        if (_currentUserRole != 'gerente' && _currentUserRole != 'administrativo') ...[
                          const DropdownMenuItem(value: 'diretor', child: Text('Diretor')), 
                          const DropdownMenuItem(value: 'administrativo', child: Text('Administrativo (Apenas Painel)')), 
                        ]
                      ],
                      onChanged: (val) => setState(() => _selectedRole = val!),
                    ),
                  ),
                ), const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createUser,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Criar Conta Rápida', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManageTab() {
    final profilesAsync = ref.watch(allProfilesProvider);
    final teamsAsync = ref.watch(teamsProvider);
    final regionsAsync = ref.watch(regionsProvider);

    return profilesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Erro: $err')),
      data: (profiles) {
        final teams = teamsAsync.value ?? [];
        final uniqueRegions = regionsAsync.value?.map((r) => r['name'].toString()).toList() ?? [];

        // --- FILTRO DE ISOLAMENTO REGIONAL PARA GERENTES ---
        var displayProfiles = profiles;
        if (_currentUserRole == 'gerente') {
          displayProfiles = profiles.where((p) {
            final role = p['role'];
            
            // Oculta contas superiores da visão do gerente
            if (role == 'diretor' || role == 'administrador' || role == 'administrativo') return false;
            
            // Oculta contas de outros gerentes (para eles não se mexerem)
            if (role == 'gerente' && p['id'] != Supabase.instance.client.auth.currentUser?.id) return false;

            // Busca a região atrelada à equipe deste usuário (se houver)
            final teamId = p['team_id'];
            String? teamRegion;
            if (teamId != null) {
              final tm = teams.firstWhere((t) => t['id'] == teamId, orElse: () => {});
              teamRegion = tm['regiao']?.toString();
            }

            // Exibe apenas se for da região do gerente OU se a pessoa ainda não tem equipe/região (novatos órfãos)
            return p['regiao'] == _currentUserRegion || teamRegion == _currentUserRegion || (p['regiao'] == null && teamId == null);
          }).toList();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16), itemCount: displayProfiles.length,
          itemBuilder: (context, index) {
            final p = displayProfiles[index];
            final role = p['role'] ?? 'vendedor';
            
            String subInfo = 'Sem atribuição';
            if (role == 'gerente') { subInfo = 'Região: ${p['regiao'] ?? "Não definida"}'; } 
            else if (role == 'vendedor' || role == 'supervisor') {
              final teamName = teams.firstWhere((t) => t['id'] == p['team_id'], orElse: () => {'name': 'Sem Equipe'})['name'];
              subInfo = 'Equipe: $teamName';
            } else if (role == 'diretor') { subInfo = 'Acesso Global'; }

            return Card(
              margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0,
              child: ListTile(
                leading: CircleAvatar(backgroundColor: const Color(0xFF4F46E5).withOpacity(0.1), child: const Icon(Icons.person, color: Color(0xFF4F46E5))),
                title: Text(p['full_name'] ?? 'Usuário', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${role.toString().toUpperCase()} • $subInfo', style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.more_vert_rounded),
                onTap: () {
                  showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (ctx) => SafeArea(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const SizedBox(height: 16), Text('Gerenciar ${p['full_name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const Divider(),
                      ListTile(leading: const Icon(Icons.edit_note_rounded, color: Colors.green), title: const Text('Editar Dados'), onTap: () { Navigator.pop(ctx); _editUserPrompt(p['id'], p['full_name'] ?? '', role); }),
                      
                      // Gerente não pode redefinir a própria região, apenas de outros
                      if (role == 'gerente' && _currentUserRole != 'gerente') 
                        ListTile(leading: const Icon(Icons.map_rounded, color: Colors.blue), title: const Text('Definir Região'), onTap: () { Navigator.pop(ctx); _assignRegionPrompt(p['id'], p['regiao']?.toString(), uniqueRegions); }),
                      
                      if (role == 'vendedor' || role == 'supervisor') 
                        ListTile(leading: const Icon(Icons.business_rounded, color: Colors.blue), title: const Text('Definir Equipe'), onTap: () { Navigator.pop(ctx); _assignTeamPrompt(p['id'], p['team_id']?.toString(), teams); }),
                      
                      ListTile(leading: const Icon(Icons.lock_reset_rounded, color: Colors.orange), title: const Text('Resetar Senha'), onTap: () { Navigator.pop(ctx); _resetPasswordPrompt(p['id']); }),
                      
                      // Proteção: Ninguém exclui a si mesmo sem querer
                      if (p['id'] != Supabase.instance.client.auth.currentUser?.id)
                        ListTile(leading: const Icon(Icons.delete_forever_rounded, color: Colors.red), title: const Text('Excluir Conta', style: TextStyle(color: Colors.red)), onTap: () { Navigator.pop(ctx); showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Excluir Conta?'), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Cancelar')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: (){Navigator.pop(ctx); _invokeAdminFunction('delete_user', {'targetUserId': p['id']}, 'Excluída!');}, child: const Text('Excluir', style: TextStyle(color: Colors.white))) ])); }),
                      
                      const SizedBox(height: 16),
                    ]),
                  ));
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTeamsTab() {
    final teamsAsync = ref.watch(teamsProvider);
    final regionsAsync = ref.watch(regionsProvider);

    return teamsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Erro: $err')),
      data: (teams) {
        final uniqueRegions = regionsAsync.value?.map((r) => r['name'].toString()).toList() ?? [];

        // --- FILTRO DE EQUIPES DA REGIÃO DO GERENTE ---
        var displayTeams = teams;
        if (_currentUserRole == 'gerente') {
          displayTeams = teams.where((t) => t['regiao'] == _currentUserRegion).toList();
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            
            // SESSÃO DE REGIÕES (Oculta para o Gerente)
            if (_currentUserRole != 'gerente') ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ 
                const Text('Regiões Globais', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))), 
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white), 
                  onPressed: () => _createRegionPrompt(teams), 
                  icon: const Icon(Icons.add, size: 16), 
                  label: const Text('Nova Região')
                ) 
              ]),
              const SizedBox(height: 8),
              uniqueRegions.isEmpty ? const Padding(padding: EdgeInsets.all(8.0), child: Text('Nenhuma região cadastrada.', style: TextStyle(color: Colors.grey))) : Wrap(
                spacing: 8, runSpacing: 8,
                children: uniqueRegions.map((r) => ActionChip(
                  label: Text(r, style: const TextStyle(fontWeight: FontWeight.bold)),
                  backgroundColor: const Color(0xFFD97706).withOpacity(0.1), side: BorderSide.none,
                  avatar: const Icon(Icons.map, size: 16, color: Color(0xFFD97706)),
                  onPressed: () => _manageRegionPrompt(r, teams),
                )).toList(),
              ),
              const Divider(height: 48),
            ],
            
            // SESSÃO DE EQUIPES
            // SESSÃO DE EQUIPES
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [ 
                // O Expanded força o texto a respeitar o limite da tela e quebrar a linha se precisar
                Expanded(
                  child: Text(
                    _currentUserRole == 'gerente' ? 'Equipes da Minha Região' : 'Equipes Globais', 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))
                  ),
                ),
                const SizedBox(width: 8), // Um pequeno respiro entre o texto e o botão
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white), 
                  onPressed: () => _manageTeamPrompt(uniqueRegions: uniqueRegions), 
                  icon: const Icon(Icons.add, size: 16), 
                  label: const Text('Nova Equipe')
                ) 
              ]
            ),
            const SizedBox(height: 8),
            displayTeams.isEmpty ? const Padding(padding: EdgeInsets.all(8.0), child: Text('Nenhuma equipe encontrada.', style: TextStyle(color: Colors.grey))) : ListView.builder(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: displayTeams.length,
              itemBuilder: (ctx, i) {
                final t = displayTeams[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0,
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Color(0xFFF1F5F9), child: Icon(Icons.groups, color: Color(0xFF64748B))),
                    title: Text(t['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Região: ${t['regiao'] ?? "Sem região"}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _manageTeamPrompt(teamId: t['id'].toString(), currentName: t['name'], currentRegion: t['regiao']?.toString(), uniqueRegions: uniqueRegions)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () { showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Excluir Equipe?'), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Cancelar')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: (){Navigator.pop(ctx); _invokeAdminFunction('delete_team', {'targetTeamId': t['id'].toString()}, 'Equipe excluída!');}, child: const Text('Excluir', style: TextStyle(color: Colors.white))) ])); }),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, bool isPassword = false, bool isEmail = false}) {
    return TextFormField(
      controller: controller, obscureText: isPassword, keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20), filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
      validator: (val) { if (val == null || val.isEmpty) return 'Obrigatório'; if (isPassword && val.length < 6) return 'Mín. 6 caracteres'; return null; },
    );
  }
  
  void _resetPasswordPrompt(String userId) {
    final passCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Resetar Senha', style: TextStyle(fontWeight: FontWeight.bold)), content: TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Nova Senha', border: OutlineInputBorder())),
      actions: [ TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)), onPressed: () { if (passCtrl.text.length < 6) return; Navigator.pop(ctx); _invokeAdminFunction('reset_password', {'targetUserId': userId, 'password': passCtrl.text}, 'Senha atualizada!'); }, child: const Text('Salvar Senha', style: TextStyle(color: Colors.white)),) ],
    ));
  }
}