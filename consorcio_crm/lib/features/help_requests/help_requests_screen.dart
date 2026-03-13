import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Provedor que busca apenas os clientes que precisam de ajuda em tempo real
final helpRequestsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return Supabase.instance.client
      .from('clients')
      .stream(primaryKey: ['id'])
      .eq('needs_supervisor_help', true) // O grande filtro acontece aqui
      .order('created_at', ascending: false);
});

class HelpRequestsScreen extends ConsumerWidget {
  const HelpRequestsScreen({super.key});

  // Função para exibir o modal de resposta do supervisor
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
              title: Text('Apoio: $clientName', style: const TextStyle(color: Color(0xFF1E3A8A))),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Digite a sua orientação para o vendedor fechar essa cota:'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Ex: Ofereça o plano com lance embutido...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (noteController.text.trim().isEmpty) return;

                          setState(() => isSaving = true);
                          try {
                            // Atualiza o banco: insere a nota e retira o status de "precisa de ajuda"
                            await Supabase.instance.client.from('clients').update({
                              'supervisor_notes': noteController.text.trim(),
                              'needs_supervisor_help': false,
                            }).eq('id', clientId);

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Orientação enviada com sucesso!'), backgroundColor: Colors.green),
                              );
                            }
                          } catch (e) {
                            setState(() => isSaving = false);
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Erro ao enviar. Tente novamente.'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSaving
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Enviar e Resolver', style: TextStyle(color: Colors.white)),
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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Pedidos de Ajuda'),
        backgroundColor: Colors.orange.shade800, // Cor de alerta para o supervisor
        foregroundColor: Colors.white,
      ),
      body: helpStream.when(
        loading: () => Center(child: CircularProgressIndicator(color: Colors.orange.shade800)),
        error: (error, stack) => Center(child: Text('Erro: $error', style: const TextStyle(color: Colors.red))),
        data: (clients) {
          if (clients.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('Tudo tranquilo por aqui!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('Nenhum vendedor precisando de apoio no momento.', style: TextStyle(color: Colors.black54)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: clients.length,
            itemBuilder: (context, index) {
              final client = clients[index];

              return Card(
                elevation: 3,
                shadowColor: Colors.orange.withOpacity(0.3),
                margin: const EdgeInsets.only(bottom: 16.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.orange.shade200, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              client['name'],
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              client['stage'],
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.maps_home_work_outlined, size: 16, color: Colors.black54),
                          const SizedBox(width: 4),
                          Text(client['interest'], style: const TextStyle(color: Colors.black54)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showHelpDialog(context, client['id'], client['name']),
                          icon: const Icon(Icons.chat_rounded, color: Colors.white),
                          label: const Text('Responder e Ajudar', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade800,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
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