import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';

class AddClientScreen extends StatefulWidget {
  const AddClientScreen({super.key});

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _creditController = TextEditingController();
  final _infoController = TextEditingController();
  
  String _selectedInterest = 'Imóvel';
  String _selectedStage = 'Prospecção';
  String _selectedCapture = 'Indicação';
  String _selectedPlan = 'Normal';
  bool _isLoading = false;

  final List<String> _interests = ['Imóvel', 'Automóvel', 'Motocicleta', 'Veículos Pesados', 'Serviços'];
  final List<String> _stages = ['Prospecção', 'Apresentação', 'Follow-up', 'Fechamento'];
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

      try {
        final userId = Supabase.instance.client.auth.currentUser!.id;

        await Supabase.instance.client.from('clients').insert({
          'vendedor_id': userId,
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prospect cadastrado com sucesso!'), backgroundColor: Color(0xFF10B981)));
          context.pop(); 
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao cadastrar prospect.'), backgroundColor: Colors.red));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Cadastrar Prospect', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeInUp(
                  duration: const Duration(milliseconds: 500),
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
                  duration: const Duration(milliseconds: 600),
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
                  duration: const Duration(milliseconds: 700),
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
                  duration: const Duration(milliseconds: 800),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveClient,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                        : const Text('Salvar na Carteira', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFD97706), size: 24),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.5)),
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
      textCapitalization: isPhone ? TextCapitalization.none : TextCapitalization.words,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(
        labelText: label, labelStyle: const TextStyle(color: Colors.black54, fontSize: 14),
        filled: true, fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
      validator: isRequired ? (v) => v == null || v.isEmpty ? 'Campo obrigatório' : null : null,
    );
  }

  Widget _buildPremiumDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label, labelStyle: const TextStyle(color: Colors.black54, fontSize: 14),
        filled: true, fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
      items: items.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)))).toList(),
      onChanged: onChanged,
    );
  }
}