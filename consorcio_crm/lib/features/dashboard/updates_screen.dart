import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';

class UpdatesScreen extends StatelessWidget {
  const UpdatesScreen({super.key});

  IconData _getIconForAction(String action) {
    switch (action) {
      case 'CREATE': return Icons.person_add_rounded;
      case 'EDIT': return Icons.edit_rounded;
      case 'STAGE': return Icons.swap_horiz_rounded;
      case 'COMMENT': return Icons.chat_bubble_rounded;
      case 'HELP': return Icons.sos_rounded;
      case 'WHATSAPP': return Icons.chat_rounded;
      case 'CALL': return Icons.phone_in_talk_rounded;
      default: return Icons.info_outline_rounded;
    }
  }

  Color _getColorForAction(String action) {
    switch (action) {
      case 'CREATE': return const Color(0xFF10B981); // Verde
      case 'EDIT': return const Color(0xFFF59E0B); // Laranja
      case 'STAGE': return const Color(0xFF3B82F6); // Azul
      case 'COMMENT': return const Color(0xFF8B5CF6); // Roxo
      case 'HELP': return Colors.redAccent; // Vermelho
      case 'WHATSAPP': return const Color(0xFF25D366); // Verde WhatsApp
      case 'CALL': return const Color(0xFF0EA5E9); // Azul Claro
      default: return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0, centerTitle: true,
        title: const Text('Atualizações Recentes', style: TextStyle(color: Color(0xFF1E293B), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client.from('activity_logs').stream(primaryKey: ['id']).order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)));
          }
          if (snapshot.hasError) return Center(child: Text('Erro ao carregar atualizações.', style: TextStyle(color: Colors.red[400])));
          
          final logs = snapshot.data;
          if (logs == null || logs.isEmpty) {
            return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history_rounded, size: 64, color: Color(0xFFCBD5E1)), SizedBox(height: 16), Text('Nenhuma atividade registrada ainda.', style: TextStyle(color: Colors.black54, fontSize: 15))]));
          }

          return ListView.builder(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 80),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final action = log['action_type'] ?? 'INFO';
              final color = _getColorForAction(action);
              final date = DateTime.tryParse(log['created_at'] ?? '')?.toLocal();
              final dateStr = date != null ? DateFormat("dd/MM 'às' HH:mm").format(date) : '';

              return FadeInUp(
                duration: const Duration(milliseconds: 300),
                delay: Duration(milliseconds: (index * 50).clamp(0, 500)),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(_getIconForAction(action), color: color, size: 20)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(log['client_nome'] ?? 'Cliente Desconhecido', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                Text(dateStr, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(log['description'] ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.badge_rounded, size: 12, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Text(log['vendedor_nome'] ?? 'Vendedor', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                              ],
                            )
                          ],
                        ),
                      )
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