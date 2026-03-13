import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final teamOverviewProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await Supabase.instance.client
      .from('clients')
      .select('*, profiles(full_name), interaction_logs(id, action_type, created_at)')
      .order('created_at', ascending: false);
      
  return List<Map<String, dynamic>>.from(response);
});

class TeamOverviewScreen extends ConsumerWidget {
  const TeamOverviewScreen({super.key});

  // --- NOVA FUNÇÃO: Sugestão Estratégica ---
  void _showSuggestionDialog(BuildContext context, WidgetRef ref, String clientId, String clientName) {
    final noteCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sugerir alteração: $clientName', style: const TextStyle(fontSize: 16)),
        content: TextField(
          controller: noteCtrl, maxLines: 3,
          decoration: const InputDecoration(hintText: 'Ex: Foque no plano Superlight...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
            onPressed: () async {
              if (noteCtrl.text.trim().isEmpty) return;
              await Supabase.instance.client.from('clients').update({'supervisor_suggestion': noteCtrl.text}).eq('id', clientId);
              ref.refresh(teamOverviewProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Enviar Sugestão', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(teamOverviewProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('Visão Geral da Equipe'), backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
      body: overviewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A))),
        error: (error, stack) => Center(child: Text('Erro: $error')),
        data: (clients) {
          if (clients.isEmpty) return const Center(child: Text('Nenhum cliente na base da filial.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: clients.length,
            itemBuilder: (context, index) {
              final client = clients[index];
              final vendedorName = client['profiles']['full_name'] ?? 'Desconhecido';
              final logs = client['interaction_logs'] as List<dynamic>? ?? [];
              final whatsappCount = logs.where((log) => log['action_type'] == 'whatsapp').length;
              final callCount = logs.where((log) => log['action_type'] == 'ligacao').length;

              return Card(
                elevation: 2, margin: const EdgeInsets.only(bottom: 16.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(client['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)), child: Text(client['stage'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.person_pin_rounded, size: 16, color: Color(0xFF1E3A8A)),
                          const SizedBox(width: 4),
                          Text('Vendedor(a): $vendedorName', style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const Divider(),
                      
                      // --- NOVOS CAMPOS EXIBIDOS ---
                      Text('Crédito: ${client['credit_value'] ?? 'N/A'} | Plano: ${client['plan_type'] ?? 'N/A'}', style: const TextStyle(fontSize: 13)),
                      Text('Captação: ${client['capture_type'] ?? 'N/A'} | Produto: ${client['interest']}', style: const TextStyle(fontSize: 13)),
                      if (client['additional_info'] != null && client['additional_info'].toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Notas: ${client['additional_info']}', style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                      ],
                      const Divider(height: 24),

                      const Text('Métricas de Esforço:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildStatBadge(Icons.chat_rounded, Colors.green, '$whatsappCount WhatsApps'),
                          const SizedBox(width: 12),
                          _buildStatBadge(Icons.phone_rounded, const Color(0xFF1E3A8A), '$callCount Ligações'),
                          const Spacer(),
                          
                          // --- BOTÃO DE SUGESTÃO ---
                          TextButton.icon(
                            onPressed: () => _showSuggestionDialog(context, ref, client['id'], client['name']),
                            icon: const Icon(Icons.lightbulb_outline, size: 16), 
                            label: const Text('Sugerir Ação'),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => ref.refresh(teamOverviewProvider), backgroundColor: const Color(0xFF1E3A8A), child: const Icon(Icons.refresh_rounded, color: Colors.white)),
    );
  }

  Widget _buildStatBadge(IconData icon, Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(children: [Icon(icon, size: 14, color: color), const SizedBox(width: 4), Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold))]),
    );
  }
}