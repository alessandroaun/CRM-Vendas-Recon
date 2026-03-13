import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';

final teamOverviewProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await Supabase.instance.client.from('clients').select('*, profiles(full_name), interaction_logs(id, action_type, created_at)').order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(response);
});

class TeamOverviewScreen extends ConsumerWidget {
  const TeamOverviewScreen({super.key});

  void _showSuggestionDialog(BuildContext context, WidgetRef ref, String clientId, String clientName) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sugerir Ação: ${clientName.split(' ').first}', style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        content: TextField(
          controller: noteCtrl, maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Digite sua orientação estratégica...',
            filled: true, fillColor: const Color(0xFFF1F5F9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.black54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (noteCtrl.text.trim().isEmpty) return;
              await Supabase.instance.client.from('clients').update({'supervisor_suggestion': noteCtrl.text}).eq('id', clientId);
              ref.refresh(teamOverviewProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Enviar Sugestão', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(teamOverviewProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Visão Geral da Equipe', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5)), backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, elevation: 0),
      body: overviewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFD97706))),
        error: (error, stack) => Center(child: Text('Erro: $error')),
        data: (clients) {
          if (clients.isEmpty) return const Center(child: Text('Nenhum cliente na base da filial.'));

          return ListView.builder(
            padding: const EdgeInsets.all(20.0),
            itemCount: clients.length,
            itemBuilder: (context, index) {
              final client = clients[index];
              final vendedorName = client['profiles']['full_name'] ?? 'Desconhecido';
              final logs = client['interaction_logs'] as List<dynamic>? ?? [];
              final whatsappCount = logs.where((log) => log['action_type'] == 'whatsapp').length;
              final callCount = logs.where((log) => log['action_type'] == 'ligacao').length;

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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(client['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)), child: Text(client['stage'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.person_pin_rounded, size: 18, color: Color(0xFFD97706)),
                            const SizedBox(width: 6),
                            Text('Executivo: $vendedorName', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                          ],
                        ),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 12.0), child: Divider(color: Color(0xFFF1F5F9), thickness: 1.5)),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildMiniInfo('Crédito', client['credit_value'] ?? 'N/A'),
                            _buildMiniInfo('Produto', client['interest']),
                            _buildMiniInfo('Plano', client['plan_type'] ?? 'Normal'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (client['additional_info'] != null && client['additional_info'].toString().isNotEmpty) ...[
                          Text('Anotações do Vendedor: ${client['additional_info']}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF64748B))),
                          const SizedBox(height: 12),
                        ],
                        
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                          child: Row(
                            children: [
                              const Text('Esforço:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                              const Spacer(),
                              _buildStatBadge(Icons.chat_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5), '$whatsappCount WHATS'),
                              const SizedBox(width: 8),
                              _buildStatBadge(Icons.phone_rounded, const Color(0xFF3B82F6), const Color(0xFFEFF6FF), '$callCount LIGAÇÕES'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showSuggestionDialog(context, ref, client['id'], client['name']),
                            icon: const Icon(Icons.lightbulb_outline, size: 18), label: const Text('Enviar Orientação Estratégica', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => ref.refresh(teamOverviewProvider), backgroundColor: const Color(0xFFD97706), child: const Icon(Icons.refresh_rounded, color: Colors.white)),
    );
  }

  Widget _buildMiniInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStatBadge(IconData icon, Color color, Color bgColor, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [Icon(icon, size: 12, color: color), const SizedBox(width: 4), Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold))]),
    );
  }
}