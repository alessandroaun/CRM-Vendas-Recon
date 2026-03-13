import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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

  // --- NOVA FUNÇÃO: Tela de Edição Completa ---
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
          title: const Text('Editar Negociação', style: TextStyle(color: Color(0xFF1E3A8A))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome')),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Telefone')),
                TextField(controller: creditCtrl, decoration: const InputDecoration(labelText: 'Valor do Crédito')),
                DropdownButtonFormField<String>(
                  value: interest, decoration: const InputDecoration(labelText: 'Produto'),
                  items: ['Imóvel', 'Automóvel', 'Motocicleta', 'Veículos Pesados', 'Serviços'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setState(() => interest = v!),
                ),
                DropdownButtonFormField<String>(
                  value: plan, decoration: const InputDecoration(labelText: 'Plano'),
                  items: ['Normal', 'Light', 'Superlight'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setState(() => plan = v!),
                ),
                DropdownButtonFormField<String>(
                  value: capture, decoration: const InputDecoration(labelText: 'Captação'),
                  items: ['Indicação', 'Visitas Externas', 'Leads da Empresa', 'Leads Próprios', 'Redes Sociais', 'P.A.P', 'Ação de Vendas'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setState(() => capture = v!),
                ),
                TextField(controller: infoCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Anotações')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
              onPressed: () async {
                await Supabase.instance.client.from('clients').update({
                  'name': nameCtrl.text, 'phone': phoneCtrl.text, 'credit_value': creditCtrl.text,
                  'interest': interest, 'plan_type': plan, 'capture_type': capture, 'additional_info': infoCtrl.text,
                }).eq('id', client['id']);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Salvar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('Minhas Negociações'), backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
      body: clientsStream.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A))),
        error: (error, stack) => Center(child: Text('Erro: $error', style: const TextStyle(color: Colors.red))),
        data: (clients) {
          if (clients.isEmpty) return const Center(child: Text('Nenhum cliente cadastrado.', style: TextStyle(color: Colors.black54)));

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: clients.length,
            itemBuilder: (context, index) {
              final client = clients[index];
              final needsHelp = client['needs_supervisor_help'] ?? false;
              final credit = client['credit_value'] ?? 'N/A';
              final plan = client['plan_type'] ?? 'Normal';
              final capture = client['capture_type'] ?? 'Indicação';
              final addInfo = client['additional_info'] ?? '';
              final supSuggestion = client['supervisor_suggestion'] ?? '';

              return Card(
                elevation: 2, margin: const EdgeInsets.only(bottom: 16.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(client['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                          IconButton(icon: const Icon(Icons.edit_note_rounded, color: Colors.blueGrey), onPressed: () => _showEditDialog(context, client)),
                          PopupMenuButton<String>(
                            initialValue: client['stage'], tooltip: 'Mudar estágio',
                            onSelected: (newStage) => _updateStage(context, client['id'], newStage),
                            itemBuilder: (ctx) => stages.map((c) => PopupMenuItem(value: c, child: Text(c, style: TextStyle(fontWeight: c == client['stage'] ? FontWeight.bold : FontWeight.normal)))).toList(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(color: const Color(0xFF1E3A8A).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [Text(client['stage'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))), const SizedBox(width: 4), const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Color(0xFF1E3A8A))]),
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      Wrap(
                        spacing: 16, runSpacing: 8,
                        children: [
                          _InfoBadge(icon: Icons.monetization_on, text: credit, color: Colors.green.shade700),
                          _InfoBadge(icon: Icons.maps_home_work, text: client['interest'], color: Colors.black54),
                          _InfoBadge(icon: Icons.assignment, text: plan, color: Colors.black54),
                          _InfoBadge(icon: Icons.radar, text: capture, color: Colors.purple.shade700),
                        ],
                      ),
                      if (addInfo.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('Notas: $addInfo', style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.black54)),
                      ],
                      if (supSuggestion.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8), width: double.infinity,
                          decoration: BoxDecoration(color: Colors.blue.shade50, border: Border.all(color: Colors.blue.shade200), borderRadius: BorderRadius.circular(8)),
                          child: Text('💡 Sugestão da Supervisão: $supSuggestion', style: TextStyle(fontSize: 13, color: Colors.blue.shade900, fontWeight: FontWeight.w600)),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Spacer(),
                          IconButton(onPressed: () => _makePhoneCall(context, client['id'], client['phone']), icon: const Icon(Icons.phone_rounded), color: const Color(0xFF1E3A8A), style: IconButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A).withOpacity(0.1))),
                          const SizedBox(width: 8),
                          IconButton(onPressed: () => _openWhatsApp(context, client['id'], client['phone'], client['name'], client['interest']), icon: const Icon(Icons.chat_rounded), color: Colors.green.shade600, style: IconButton.styleFrom(backgroundColor: Colors.green.shade50)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _toggleHelp(client['id'], needsHelp),
                          icon: Icon(needsHelp ? Icons.support_agent_rounded : Icons.pan_tool_outlined, color: needsHelp ? Colors.red : Colors.orange),
                          label: Text(needsHelp ? 'Aguardando Supervisor' : 'Solicitar Ajuda no Fechamento', style: TextStyle(color: needsHelp ? Colors.red : Colors.orange)),
                          style: OutlinedButton.styleFrom(side: BorderSide(color: needsHelp ? Colors.red : Colors.orange), backgroundColor: needsHelp ? Colors.red.withOpacity(0.05) : Colors.transparent),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Widget auxiliar para manter o layout limpo
class _InfoBadge extends StatelessWidget {
  final IconData icon; final String text; final Color color;
  const _InfoBadge({required this.icon, required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: color), const SizedBox(width: 4), Text(text, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500))]);
  }
}