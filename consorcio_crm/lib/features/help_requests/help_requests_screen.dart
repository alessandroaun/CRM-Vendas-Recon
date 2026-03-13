import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';

final helpRequestsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return Supabase.instance.client
      .from('clients')
      .stream(primaryKey: ['id'])
      .eq('needs_supervisor_help', true)
      .order('created_at', ascending: false);
});

class HelpRequestsScreen extends ConsumerWidget {
  const HelpRequestsScreen({super.key});

  void _showHelpDialog(BuildContext context, String clientId, String clientName) {
    final noteController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text('Apoiar Venda: ${clientName.split(' ').first}', style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Envie uma orientação estratégica para destravar essa negociação.', style: TextStyle(color: Colors.black54, fontSize: 13)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: noteController, maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Ex: Ofereça o lance embutido...',
                      filled: true, fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: isSaving ? null : () => Navigator.pop(dialogContext), child: const Text('Cancelar', style: TextStyle(color: Colors.black54))),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (noteController.text.trim().isEmpty) return;
                    setState(() => isSaving = true);
                    try {
                      await Supabase.instance.client.from('clients').update({'supervisor_notes': noteController.text.trim(), 'needs_supervisor_help': false}).eq('id', clientId);
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Apoio enviado com sucesso!'), backgroundColor: Color(0xFF10B981)));
                      }
                    } catch (e) {
                      setState(() => isSaving = false);
                      if (dialogContext.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao enviar.'), backgroundColor: Colors.red));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: isSaving ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Enviar Ajuda', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final helpStream = ref.watch(helpRequestsStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Aguardando Suporte', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, elevation: 0,
      ),
      body: helpStream.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFD97706))),
        error: (error, stack) => Center(child: Text('Erro: $error', style: const TextStyle(color: Colors.red))),
        data: (clients) {
          if (clients.isEmpty) {
            return Center(
              child: FadeIn(
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 80, color: Color(0xFF10B981)),
                    SizedBox(height: 16),
                    Text('Mesa Limpa!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.5)),
                    Text('Nenhum vendedor precisando de apoio agora.', style: TextStyle(color: Colors.black54, fontSize: 16)),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20.0),
            itemCount: clients.length,
            itemBuilder: (context, index) {
              final client = clients[index];

              return FadeInUp(
                duration: const Duration(milliseconds: 400),
                delay: Duration(milliseconds: 50 * index),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 20.0),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFFCA5A5).withOpacity(0.5), width: 1.5),
                    boxShadow: [BoxShadow(color: const Color(0xFFEF4444).withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(client['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.5), overflow: TextOverflow.ellipsis)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                              child: Text(client['stage'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.maps_home_work_rounded, size: 16, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Text('Produto: ${client['interest']} | Ticket: ${client['credit_value'] ?? 'N/A'}', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                          ],
                        ),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Color(0xFFF1F5F9), thickness: 1.5)),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showHelpDialog(context, client['id'], client['name']),
                            icon: const Icon(Icons.support_agent_rounded, size: 20),
                            label: const Text('Prestar Suporte', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
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
}