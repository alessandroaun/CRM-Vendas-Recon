import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddClientScreen extends StatefulWidget {
  const AddClientScreen({super.key});

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _creditController = TextEditingController(); // Novo: Valor de Crédito
  final _infoController = TextEditingController(); // Novo: Informações Adicionais
  
  // Valores padrão para os Dropdowns
  String _selectedInterest = 'Imóvel';
  String _selectedStage = 'Prospecção';
  String _selectedCapture = 'Indicação'; // Novo
  String _selectedPlan = 'Normal'; // Novo
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cliente cadastrado com sucesso!'), backgroundColor: Colors.green),
          );
          context.pop(); 
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao cadastrar cliente. Tente novamente.'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Novo Cliente'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Dados Básicos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: 'Nome Completo', prefixIcon: const Icon(Icons.person_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
                  validator: (value) => value == null || value.isEmpty ? 'Informe o nome' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: 'WhatsApp / Telefone', prefixIcon: const Icon(Icons.phone_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
                  validator: (value) => value == null || value.isEmpty ? 'Informe o telefone' : null,
                ),
                const SizedBox(height: 32),

                const Text('Detalhes da Negociação', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _creditController,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(labelText: 'Valor do Crédito (Ex: R\$ 150.000)', prefixIcon: const Icon(Icons.monetization_on_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedInterest,
                  decoration: InputDecoration(labelText: 'Interesse (Produto)', prefixIcon: const Icon(Icons.maps_home_work_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
                  items: _interests.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setState(() => _selectedInterest = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedPlan,
                  decoration: InputDecoration(labelText: 'Possível Plano', prefixIcon: const Icon(Icons.assignment_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
                  items: _planTypes.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setState(() => _selectedPlan = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedCapture,
                  decoration: InputDecoration(labelText: 'Tipo de Captação', prefixIcon: const Icon(Icons.radar_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
                  items: _captureTypes.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setState(() => _selectedCapture = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedStage,
                  decoration: InputDecoration(labelText: 'Estágio da Negociação', prefixIcon: const Icon(Icons.trending_up_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
                  items: _stages.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setState(() => _selectedStage = v!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _infoController,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: 'Informações Adicionais', prefixIcon: const Icon(Icons.notes_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
                ),
                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _isLoading ? null : _saveClient,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Salvar Cliente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}