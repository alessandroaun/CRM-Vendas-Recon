import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // NOVO: Para as máscaras
import 'package:intl/intl.dart'; // NOVO: Para formatar R$
import 'dart:math' as math; // NOVO: Para calcular o tamanho do texto
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';

import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';

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
  String? _selectedSellerId; 
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
        showTopSnackBar(
          Overlay.of(context),
          const CustomSnackBar.error(message: 'Você precisa selecionar um vendedor para este lead!'),
        );
        return;
      }

      FocusScope.of(context).unfocus();
      
      setState(() => _isLoading = true);

      try {
        // --- NOVO: Cria a mensagem automática inicial da gestão ---
        final initialHistory = [
          {
            'sender': 'supervisor',
            'text': 'Novo lead distribuído pela gestão. Por favor, inicie o atendimento!',
            'timestamp': DateTime.now().toIso8601String()
          }
        ];

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
          
          // --- NOVO: Gatilhos para notificar o vendedor ---
          'is_help_mode': true,      // Faz o lead aparecer na aba "Avisos" do vendedor
          'unread_vendedor': 1,      // Acende a bolinha vermelha de notificação
          'phone_released': true,    // Como a gestão criou, o telefone já vai liberado para ambos
          'chat_history': initialHistory, // Insere a mensagem inicial no chat do card
        });

        await Future.delayed(const Duration(milliseconds: 150));

        if (!context.mounted) return;

        showTopSnackBar(
          Overlay.of(context),
          const CustomSnackBar.success(message: 'Lead atribuído com sucesso!'),
        );
        Navigator.of(context).pop(); 
        
      } catch (e) {
        if (!context.mounted) return;
        showTopSnackBar(
          Overlay.of(context),
          const CustomSnackBar.error(message: 'Erro ao atribuir lead.'),
        );
        setState(() => _isLoading = false); 
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
                            isExpanded: true,
                            value: _selectedSellerId,
                            decoration: InputDecoration(labelText: 'Selecione o Vendedor', filled: true, fillColor: const Color(0xFFFFFBEB), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
                            items: sellers.map((s) => DropdownMenuItem(
                              value: s['id'].toString(), 
                              child: Text(
                                s['full_name'] ?? 'Sem Nome', 
                                overflow: TextOverflow.ellipsis, 
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
                      // AQUI ATIVAMOS A MÁSCARA DE TELEFONE
                      _buildPremiumInput(controller: _phoneController, label: 'WhatsApp / Telefone', isPhone: true, isRequired: true),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FadeInUp(
                  duration: const Duration(milliseconds: 500),
                  child: _buildSectionCard(
                    title: 'Interesse do Cliente',
                    icon: Icons.analytics_outlined,
                    children: [
                      // AQUI ATIVAMOS A MÁSCARA DE DINHEIRO
                      _buildPremiumInput(controller: _creditController, label: 'Valor do Crédito', isCurrency: true),
                      const SizedBox(height: 16),
                      _buildPremiumDropdown('Produto', _selectedInterest, _interests, (v) => setState(() => _selectedInterest = v!)),
                      const SizedBox(height: 16),
                      _buildPremiumDropdown('Possível Plano', _selectedPlan, _planTypes, (v) => setState(() => _selectedPlan = v!)),
                    ],
                  ),
                ),
                // --- NOVA SEÇÃO DE ESTRATÉGIA E FUNIL ADICIONADA ---
                const SizedBox(height: 24),
                FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  child: _buildSectionCard(
                    title: 'Prospecção e Anotações',
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
                // ----------------------------------------------------
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFF59E0B), size: 24), 
              const SizedBox(width: 8), 
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis)),
            ]
          ), 
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Color(0xFFF1F5F9), thickness: 1.5)), 
          ...children
        ]
      ),
    );
  }

  // ATUALIZADO PARA ACEITAR AS MÁSCARAS AUTOMÁTICAS
  Widget _buildPremiumInput({required TextEditingController controller, required String label, bool isRequired = false, bool isPhone = false, bool isCurrency = false, int maxLines = 1}) {
    List<TextInputFormatter> formatters = [];
    if (isPhone) formatters.add(PhoneInputFormatter());
    if (isCurrency) formatters.add(CurrencyInputFormatter());

    return TextFormField(
      controller: controller, maxLines: maxLines,
      textCapitalization: isPhone || isCurrency ? TextCapitalization.none : TextCapitalization.words, 
      keyboardType: isPhone || isCurrency ? TextInputType.number : TextInputType.text,
      inputFormatters: formatters,
      decoration: InputDecoration(labelText: label, filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)), 
      validator: isRequired ? (v) => v == null || v.isEmpty ? 'Campo obrigatório' : null : null
    );
  }

  Widget _buildPremiumDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: value, 
      decoration: InputDecoration(labelText: label, filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)), 
      items: items.map((v) => DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis))).toList(), 
      onChanged: onChanged
    );
  }
}

// --- CLASSES DE MÁSCARA (NATIVAS DO FLUTTER) ---

class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    String formatted = '';
    if (text.isNotEmpty) {
      formatted = '(' + text.substring(0, math.min(text.length, 2));
      if (text.length > 2) {
        formatted += ') ' + text.substring(2, math.min(text.length, 7));
        if (text.length > 7) {
          formatted += '-' + text.substring(7, math.min(text.length, 11));
        }
      }
    }
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.isEmpty) text = '0';
    double value = double.parse(text) / 100;
    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    String newText = formatter.format(value);
    return TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newText.length));
  }
}