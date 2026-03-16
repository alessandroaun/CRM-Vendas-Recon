import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/profile_provider.dart'; // Importante para pegarmos o teamId do vendedor

class AddClientScreen extends ConsumerStatefulWidget {
  const AddClientScreen({super.key});

  @override
  ConsumerState<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends ConsumerState<AddClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _creditController = TextEditingController();
  final _infoController = TextEditingController();
  
  String _selectedInterest = 'Imóvel';
  String _selectedStage = 'Novo Cliente'; // Atualizado
  String _selectedCapture = 'Indicação';
  String _selectedPlan = 'Normal';
  bool _isLoading = false;

  // Sem Pesados
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
      setState(() => _isLoading = true);

      // --- CÓDIGO NOVO: PEGANDO A EQUIPE DO VENDEDOR ---
      final profile = ref.read(userProfileProvider).value; 
      final userTeamId = profile?.teamId;
      // ------------------------------------------------

      try {
        await Supabase.instance.client.from('clients').insert({
          'vendedor_id': Supabase.instance.client.auth.currentUser!.id,
          'team_id': userTeamId, // <--- CÓDIGO NOVO: SALVANDO A EQUIPE NO BANCO
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cliente cadastrado com sucesso!'), backgroundColor: Color(0xFF10B981)));
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao salvar cliente.'), backgroundColor: Colors.red));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: const Text('Cadastrar Novo', style: TextStyle(color: Color(0xFF1E293B), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent, elevation: 0, centerTitle: true,
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
                  duration: const Duration(milliseconds: 400),
                  child: _buildSectionCard(
                    title: 'Dados Pessoais',
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
                    title: 'Qualificação da Cota',
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
                const SizedBox(height: 24),
                FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  child: _buildSectionCard(
                    title: 'Estratégia e Funil',
                    icon: Icons.flag_outlined,
                    children: [
                      _buildPremiumDropdown('Tipo de Captação', _selectedCapture, _captureTypes, (v) => setState(() => _selectedCapture = v!)),
                      const SizedBox(height: 16),
                      _buildPremiumDropdown('Estágio Inicial', _selectedStage, _stages, (v) => setState(() => _selectedStage = v!)),
                      const SizedBox(height: 16),
                      _buildPremiumInput(controller: _infoController, label: 'Anotações Iniciais', maxLines: 3),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                FadeInUp(
                  duration: const Duration(milliseconds: 700),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveClient,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5), // Indigo premium
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      shadowColor: const Color(0xFF4F46E5).withOpacity(0.4),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                        : const Text('Salvar no Funil', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF4F46E5), size: 24),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.5)),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Color(0xFFF1F5F9), thickness: 1.5)),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPremiumInput({required TextEditingController controller, required String label, bool isRequired = false, bool isPhone = false, int maxLines = 1}) {
    return TextFormField(
      controller: controller, maxLines: maxLines,
      textCapitalization: isPhone ? TextCapitalization.none : TextCapitalization.words, keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.black54, fontSize: 13), filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
      validator: isRequired ? (v) => v == null || v.isEmpty ? 'Campo obrigatório' : null : null,
    );
  }

  Widget _buildPremiumDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value, decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.black54, fontSize: 13), filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
      items: items.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)))).toList(), onChanged: onChanged,
    );
  }
}