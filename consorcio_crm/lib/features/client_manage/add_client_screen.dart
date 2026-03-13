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
  
  // Valores padrão para os Dropdowns
  String _selectedInterest = 'Imóvel';
  String _selectedStage = 'Prospecção';
  bool _isLoading = false;

  final List<String> _interests = [
    'Imóvel', 
    'Automóvel', 
    'Motocicleta', 
    'Veículos Pesados', 
    'Serviços'
  ];

  final List<String> _stages = [
    'Prospecção', 
    'Apresentação', 
    'Follow-up', 
    'Fechamento'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveClient() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // Pega o ID do vendedor que está logado no momento
        final userId = Supabase.instance.client.auth.currentUser!.id;

        // Insere o registro na tabela de clientes
        await Supabase.instance.client.from('clients').insert({
          'vendedor_id': userId,
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'interest': _selectedInterest,
          'stage': _selectedStage,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cliente cadastrado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          // Volta para o Dashboard após salvar
          context.pop(); 
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao cadastrar cliente. Tente novamente.'),
              backgroundColor: Colors.red,
            ),
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
                const Text(
                  'Dados do Prospect',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                ),
                const SizedBox(height: 24),

                // Campo de Nome
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Nome Completo',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Informe o nome' : null,
                ),
                const SizedBox(height: 16),

                // Campo de Telefone/WhatsApp
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'WhatsApp / Telefone',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Informe o telefone' : null,
                ),
                const SizedBox(height: 16),

                // Dropdown de Interesse (Produto)
                DropdownButtonFormField<String>(
                  value: _selectedInterest,
                  decoration: InputDecoration(
                    labelText: 'Interesse (Produto)',
                    prefixIcon: const Icon(Icons.maps_home_work_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: _interests.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() => _selectedInterest = newValue!);
                  },
                ),
                const SizedBox(height: 16),

                // Dropdown de Estágio do Funil
                DropdownButtonFormField<String>(
                  value: _selectedStage,
                  decoration: InputDecoration(
                    labelText: 'Estágio da Negociação',
                    prefixIcon: const Icon(Icons.trending_up_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: _stages.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() => _selectedStage = newValue!);
                  },
                ),
                const SizedBox(height: 32),

                // Botão de Salvar
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveClient,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Salvar Cliente',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}