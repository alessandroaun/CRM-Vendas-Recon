import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';

// O provedor fica aqui solto, sem importar de outra tela
final teamMembersProvider = StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, teamId) {
  return Supabase.instance.client.from('profiles').stream(primaryKey: ['id']).eq('team_id', teamId);
});

class AddTeamClientScreen extends ConsumerStatefulWidget {
  final String teamId;
  const AddTeamClientScreen({super.key, required this.teamId});

  @override
  ConsumerState<AddTeamClientScreen> createState() => _AddTeamClientScreenState();
}

class _AddTeamClientScreenState extends ConsumerState<AddTeamClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _creditController = TextEditingController();
  final _infoController = TextEditingController();
  
  String _selectedInterest = 'Imóvel';
  String _selectedStage = 'Novo Cliente';
  String _selectedCapture = 'Indicação';
  String _selectedPlan = 'Normal';
  String? _selectedSellerId; // O ID do vendedor escolhido
  bool _isLoading = false;

  final List<String> _interests = ['Imóvel', 'Automóvel', 'Motocicleta', 'Serviços'];
  final List<String> _stages = ['Novo Cliente', 'Em negociação', 'Cadastrado', 'Fechado'];
  final List<String> _captureTypes = ['Indicação', 'Visitas Externas', 'Leads da Empresa', 'Leads Próprios', 'Redes Sociais', 'P.A.P', 'Ação de Vendas'];
  final List<String> _planTypes = ['Normal', 'Light', 'Superlight'];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _creditController.dispose();
    _infoController.dispose();
    super.dispose();
  }

  Future<void> _saveClient() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedSellerId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Você precisa selecionar um vendedor para este lead!')));
        return;
      }

      setState(() => _isLoading = true);

      try {
        await Supabase.instance.client.from('clients').insert({
          'team_id': widget.teamId,
          'vendedor_id': _selectedSellerId,
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'interest': _selectedInterest,
          'stage': _selectedStage,
          'credit_value': _creditController.text.trim(),
          'capture_type': _selectedCapture,
          'plan_type': _selectedPlan,
          'additional_info': _infoController.text.trim(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lead atribuído com sucesso!'), backgroundColor: Color(0xFF10B981)));
          Navigator.pop(context); // Volta pro funil
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao atribuir lead.'), backgroundColor: Colors.red));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(teamMembersProvider(widget.teamId));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: const Text('Distribuir Lead', style: TextStyle(color: Color(0xFF1E293B), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent, elevation: 0, centerTitle: true, foregroundColor: const Color(0xFF1E293B),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeInUp(
                  duration: const Duration(milliseconds: 300),
                  child: _buildSectionCard(
                    title: 'Atribuição',
                    icon: Icons.assignment_ind_rounded,
                    children: [
                      membersAsync.when(
                        loading: () => const CircularProgressIndicator(),
                        error: (err, stack) => const Text('Erro ao carregar equipe.'),
                        data: (members) {
                          final sellers = members.where((m) => m['role'] != 'supervisor').toList();
                          return DropdownButtonFormField<String>(
                            isExpanded: true, // <--- CORREÇÃO AQUI
                            value: _selectedSellerId,
                            decoration: InputDecoration(labelText: 'Selecione o Vendedor', filled: true, fillColor: const Color(0xFFFFFBEB), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
                            items: sellers.map((s) => DropdownMenuItem(
                              value: s['id'].toString(), 
                              child: Text(
                                s['full_name'] ?? 'Sem Nome', 
                                overflow: TextOverflow.ellipsis, // <--- PROTEÇÃO DE TEXTO GRANDE
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))
                              )
                            )).toList(),
                            onChanged: (val) => setState(() => _selectedSellerId = val),
                            validator: (val) => val == null ? 'Obrigatório selecionar um vendedor' : null,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FadeInUp(
                  duration: const Duration(milliseconds: 400),
                  child: _buildSectionCard(
                    title: 'Dados do Lead',
                    icon: Icons.person_outline_rounded,
                    children: [
                      _buildPremiumInput(controller: _nameController, label: 'Nome Completo', isRequired: true),
                      const SizedBox(height: 16),
                      _buildPremiumInput(controller: _phoneController, label: 'WhatsApp / Telefone', isPhone: true, isRequired: true),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FadeInUp(
                  duration: const Duration(milliseconds: 500),
                  child: _buildSectionCard(
                    title: 'Qualificação',
                    icon: Icons.analytics_outlined,
                    children: [
                      _buildPremiumInput(controller: _creditController, label: 'Valor do Crédito (Ex: R\$ 150.000)'),
                      const SizedBox(height: 16),
                      _buildPremiumDropdown('Produto', _selectedInterest, _interests, (v) => setState(() => _selectedInterest = v!)),
                      const SizedBox(height: 16),
                      _buildPremiumDropdown('Possível Plano', _selectedPlan, _planTypes, (v) => setState(() => _selectedPlan = v!)),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                FadeInUp(
                  duration: const Duration(milliseconds: 700),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveClient,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: _isLoading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white)) : const Text('Atribuir ao Vendedor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 8))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: const Color(0xFFF59E0B), size: 24), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))]), const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Color(0xFFF1F5F9), thickness: 1.5)), ...children]),
    );
  }

  Widget _buildPremiumInput({required TextEditingController controller, required String label, bool isRequired = false, bool isPhone = false}) {
    return TextFormField(controller: controller, textCapitalization: isPhone ? TextCapitalization.none : TextCapitalization.words, keyboardType: isPhone ? TextInputType.phone : TextInputType.text, decoration: InputDecoration(labelText: label, filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)), validator: isRequired ? (v) => v == null || v.isEmpty ? 'Campo obrigatório' : null : null);
  }

  Widget _buildPremiumDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      isExpanded: true, // <--- CORREÇÃO AQUI
      value: value, 
      decoration: InputDecoration(labelText: label, filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)), 
      items: items.map((v) => DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis))).toList(), // <--- PROTEÇÃO DE TEXTO
      onChanged: onChanged
    );
  }
}