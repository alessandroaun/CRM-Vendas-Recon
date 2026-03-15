import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';

// Provedor que busca os clientes do vendedor que possuem uma "Sugestão do Supervisor"
final notificationsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return const Stream.empty();

  return Supabase.instance.client
      .from('clients')
      .stream(primaryKey: ['id'])
      .eq('vendedor_id', userId)
      .order('created_at', ascending: false) // CORREÇÃO: Usando created_at ao invés de updated_at
      .map((clients) {
        // Filtra apenas os clientes que têm alguma sugestão escrita pelo supervisor
        return clients.where((c) {
          final suggestion = c['supervisor_suggestion'];
          return suggestion != null && suggestion.toString().trim().isNotEmpty;
        }).toList();
      });
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _markAsRead(BuildContext context, String clientId) async {
    try {
      // Ao "marcar como lido", limpamos a sugestão para a notificação sumir da tela
      await Supabase.instance.client.from('clients').update({
        'supervisor_suggestion': null,
      }).eq('id', clientId);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notificação arquivada.'), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao arquivar notificação.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsStream = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0, 
        centerTitle: true,
        title: const Text('Avisos', style: TextStyle(color: Color(0xFF1E293B), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
      ),
      body: notificationsStream.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
        error: (err, stack) => Center(child: Text('Erro: $err')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: FadeInDown(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: const Color(0xFF4F46E5).withOpacity(0.05), shape: BoxShape.circle),
                      child: const Icon(Icons.notifications_active_outlined, size: 64, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 24),
                    const Text('Tudo tranquilo por aqui!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), letterSpacing: -0.5)),
                    const SizedBox(height: 8),
                    const Text('Você não tem novas orientações da supervisão.', style: TextStyle(color: Colors.black54, fontSize: 14)),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              // CORREÇÃO: Puxando apenas o created_at que temos certeza que existe
              final dateString = notif['created_at']; 
              final date = DateTime.parse(dateString);
              final formattedDate = DateFormat('dd/MM HH:mm').format(date);

              return FadeInUp(
                duration: const Duration(milliseconds: 300),
                delay: Duration(milliseconds: 50 * index),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3), width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(color: Color(0xFFFFFBEB), shape: BoxShape.circle),
                            child: const Icon(Icons.lightbulb_rounded, color: Color(0xFFF59E0B), size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Orientação Estratégica', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                                    Text(formattedDate, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('Cliente: ${notif['name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.3)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16)),
                        child: Text(
                          '"${notif['supervisor_suggestion']}"',
                          style: const TextStyle(fontSize: 14, color: Color(0xFF334155), fontStyle: FontStyle.italic, height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _markAsRead(context, notif['id']),
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                          label: const Text('Marcar como ciente', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFF4F46E5)),
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