import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:animate_do/animate_do.dart';

final clientsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return const Stream.empty();

  return Supabase.instance.client
      .from('clients')
      .stream(primaryKey: ['id'])
      .eq('vendedor_id', userId)
      .order('created_at', ascending: false);
});

class ClientListScreen extends ConsumerWidget {
  const ClientListScreen({super.key});

  Future<void> _toggleHelp(String clientId, bool currentStatus) async {
    await Supabase.instance.client.from('clients').update({'needs_supervisor_help': !currentStatus}).eq('id', clientId);
  }

  Future<void> _updateStage(BuildContext context, String clientId, String newStage) async {
    try {
      await Supabase.instance.client.from('clients').update({'stage': newStage}).eq('id', clientId);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao atualizar estágio.'), backgroundColor: Colors.red));
    }
  }

  void _showEditDialog(BuildContext context, Map<String, dynamic> client) {
    final nameCtrl = TextEditingController(text: client['name']);
    final phoneCtrl = TextEditingController(text: client['phone']);
    final creditCtrl = TextEditingController(text: client['credit_value'] ?? '');
    final infoCtrl = TextEditingController(text: client['additional_info'] ?? '');
    
    String interest = client['interest'] ?? 'Imóvel';
    String plan = client['plan_type'] ?? 'Normal';
    String capture = client['capture_type'] ?? 'Indicação';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Editar Negociação', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, letterSpacing: -0.5)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPremiumInput(nameCtrl, 'Nome Completo'),
                const SizedBox(height: 12),
                _buildPremiumInput(phoneCtrl, 'Telefone'),
                const SizedBox(height: 12),
                _buildPremiumInput(creditCtrl, 'Valor do Crédito'),
                const SizedBox(height: 12),
                _buildPremiumDropdown(interest, 'Produto', ['Imóvel', 'Automóvel', 'Motocicleta', 'Veículos Pesados', 'Serviços'], (v) => setState(() => interest = v!)),
                const SizedBox(height: 12),
                _buildPremiumDropdown(plan, 'Plano', ['Normal', 'Light', 'Superlight'], (v) => setState(() => plan = v!)),
                const SizedBox(height: 12),
                _buildPremiumDropdown(capture, 'Captação', ['Indicação', 'Visitas Externas', 'Leads da Empresa', 'Leads Próprios', 'Redes Sociais', 'P.A.P', 'Ação de Vendas'], (v) => setState(() => capture = v!)),
                const SizedBox(height: 12),
                _buildPremiumInput(infoCtrl, 'Anotações', maxLines: 2),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.black54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                await Supabase.instance.client.from('clients').update({
                  'name': nameCtrl.text, 'phone': phoneCtrl.text, 'credit_value': creditCtrl.text,
                  'interest': interest, 'plan_type': plan, 'capture_type': capture, 'additional_info': infoCtrl.text,
                }).eq('id', client['id']);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Salvar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumInput(TextEditingController ctrl, String label, {int maxLines = 1}) {
    return TextField(
      controller: ctrl, maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label, labelStyle: const TextStyle(color: Colors.black54, fontSize: 13),
        filled: true, fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildPremiumDropdown(String value, String label, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value, decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.black54, fontSize: 13), filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
      items: items.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 14)))).toList(), onChanged: onChanged,
    );
  }

  Future<void> _openWhatsApp(BuildContext context, String clientId, String phone, String clientName, String interest) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    String finalPhone = cleanPhone;
    if (cleanPhone.length == 10 || cleanPhone.length == 11) finalPhone = '55$cleanPhone';
    final text = 'Olá $clientName, aqui é da Consórcio Recon. Vi que você tem interesse em consórcio de $interest. Podemos conversar?';
    final url = Uri.parse('https://wa.me/$finalPhone?text=${Uri.encodeComponent(text)}');

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('interaction_logs').insert({'client_id': clientId, 'vendedor_id': userId, 'action_type': 'whatsapp'});
      if (await canLaunchUrl(url)) { await launchUrl(url, mode: LaunchMode.externalApplication); } else { throw Exception('Erro WhatsApp'); }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao processar ação.'), backgroundColor: Colors.red));
    }
  }

  Future<void> _makePhoneCall(BuildContext context, String clientId, String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final url = Uri.parse('tel:$cleanPhone');
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('interaction_logs').insert({'client_id': clientId, 'vendedor_id': userId, 'action_type': 'ligacao'});
      if (await canLaunchUrl(url)) { await launchUrl(url); } else { throw Exception('Erro Ligação'); }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao processar ação.'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsStream = ref.watch(clientsStreamProvider);
    final stages = ['Prospecção', 'Apresentação', 'Follow-up', 'Fechamento'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Minhas Negociações', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5)), backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, elevation: 0),
      body: clientsStream.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFD97706))),
        error: (error, stack) => Center(child: Text('Erro: $error', style: const TextStyle(color: Colors.red))),
        data: (clients) {
          if (clients.isEmpty) return const Center(child: Text('Nenhum prospect cadastrado.', style: TextStyle(color: Colors.black54, fontSize: 16)));

          return ListView.builder(
            padding: const EdgeInsets.all(20.0),
            itemCount: clients.length,
            itemBuilder: (context, index) {
              final client = clients[index];
              final needsHelp = client['needs_supervisor_help'] ?? false;
              
              // Efeito em cascata: cada card demora um pouquinho mais para aparecer
              return FadeInUp(
                duration: const Duration(milliseconds: 400),
                delay: Duration(milliseconds: 50 * index),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 20.0),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(client['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.5), overflow: TextOverflow.ellipsis)),
                            IconButton(icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF94A3B8)), onPressed: () => _showEditDialog(context, client)),
                            PopupMenuButton<String>(
                              initialValue: client['stage'], tooltip: 'Mudar estágio',
                              onSelected: (newStage) => _updateStage(context, client['id'], newStage),
                              itemBuilder: (ctx) => stages.map((c) => PopupMenuItem(value: c, child: Text(c, style: TextStyle(fontWeight: c == client['stage'] ? FontWeight.bold : FontWeight.w500)))).toList(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(10)),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [Text(client['stage'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(width: 4), const Icon(Icons.arrow_drop_down_rounded, size: 16, color: Colors.white)]),
                              ),
                            ),
                          ],
                        ),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Divider(color: Color(0xFFF1F5F9), thickness: 1.5)),
                        Wrap(
                          spacing: 12, runSpacing: 10,
                          children: [
                            _InfoBadge(icon: Icons.monetization_on_rounded, text: client['credit_value'] ?? 'N/A', color: const Color(0xFF10B981), bgColor: const Color(0xFFD1FAE5)),
                            _InfoBadge(icon: Icons.maps_home_work_rounded, text: client['interest'], color: const Color(0xFF3B82F6), bgColor: const Color(0xFFDBEAFE)),
                            _InfoBadge(icon: Icons.assignment_rounded, text: client['plan_type'] ?? 'Normal', color: const Color(0xFF6366F1), bgColor: const Color(0xFFE0E7FF)),
                            _InfoBadge(icon: Icons.radar_rounded, text: client['capture_type'] ?? 'Ind.', color: const Color(0xFF8B5CF6), bgColor: const Color(0xFFEDE9FE)),
                          ],
                        ),
                        if (client['additional_info'] != null && client['additional_info'].toString().isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text('Anotações: ${client['additional_info']}', style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Color(0xFF64748B))),
                        ],
                        if (client['supervisor_suggestion'] != null && client['supervisor_suggestion'].toString().isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12), width: double.infinity,
                            decoration: BoxDecoration(color: const Color(0xFFF0FDF4), border: Border.all(color: const Color(0xFFBBF7D0)), borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.lightbulb_circle_rounded, color: Color(0xFF16A34A), size: 20),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Sugestão Estratégica:\n${client['supervisor_suggestion']}', style: const TextStyle(fontSize: 13, color: Color(0xFF166534), fontWeight: FontWeight.w600, height: 1.4))),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _toggleHelp(client['id'], needsHelp),
                                icon: Icon(needsHelp ? Icons.support_agent_rounded : Icons.pan_tool_outlined, size: 18),
                                label: Text(needsHelp ? 'Aguardando' : 'Pedir Ajuda', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: needsHelp ? const Color(0xFFEF4444) : const Color(0xFFD97706),
                                  side: BorderSide(color: needsHelp ? const Color(0xFFEF4444) : const Color(0xFFD97706), width: 1.5),
                                  backgroundColor: needsHelp ? const Color(0xFFFEF2F2) : Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildActionButton(Icons.phone_rounded, const Color(0xFF3B82F6), const Color(0xFFEFF6FF), () => _makePhoneCall(context, client['id'], client['phone'])),
                            const SizedBox(width: 8),
                            _buildActionButton(Icons.chat_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5), () => _openWhatsApp(context, client['id'], client['phone'], client['name'], client['interest'])),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, Color bgColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon; final String text; final Color color; final Color bgColor;
  const _InfoBadge({required this.icon, required this.text, required this.color, required this.bgColor});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: color), const SizedBox(width: 4), Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600))]),
    );
  }
}