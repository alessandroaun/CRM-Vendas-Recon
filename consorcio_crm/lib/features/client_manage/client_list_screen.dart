import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Provedor que escuta a tabela de clientes em tempo real (Stream)
final clientsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  
  if (userId == null) return const Stream.empty();

  return Supabase.instance.client
      .from('clients')
      .stream(primaryKey: ['id'])
      .eq('vendedor_id', userId)
      .order('created_at', ascending: false); // Mostra os mais recentes primeiro
});

class ClientListScreen extends ConsumerWidget {
  const ClientListScreen({super.key});

  // Função para alternar o pedido de ajuda ao supervisor
  Future<void> _toggleHelp(String clientId, bool currentStatus) async {
    await Supabase.instance.client
        .from('clients')
        .update({'needs_supervisor_help': !currentStatus})
        .eq('id', clientId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Escutando as mudanças do banco de dados em tempo real
    final clientsStream = ref.watch(clientsStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Minhas Negociações'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: clientsStream.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A))),
        error: (error, stack) => Center(
          child: Text('Erro ao carregar carteira: $error', style: const TextStyle(color: Colors.red)),
        ),
        data: (clients) {
          if (clients.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum cliente cadastrado ainda.\nComece a prospectar!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: clients.length,
            itemBuilder: (context, index) {
              final client = clients[index];
              final needsHelp = client['needs_supervisor_help'] ?? false;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cabeçalho do Card: Nome e Status
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
                              color: const Color(0xFF1E3A8A).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              client['stage'],
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Informações de Contato e Interesse
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 16, color: Colors.black54),
                          const SizedBox(width: 4),
                          Text(client['phone'], style: const TextStyle(color: Colors.black54)),
                          const SizedBox(width: 16),
                          const Icon(Icons.maps_home_work_outlined, size: 16, color: Colors.black54),
                          const SizedBox(width: 4),
                          Text(client['interest'], style: const TextStyle(color: Colors.black54)),
                        ],
                      ),
                      
                      // Mostra a nota do supervisor, se houver
                      if (client['supervisor_notes'] != null && client['supervisor_notes'].toString().isNotEmpty) ...[
                        const Divider(height: 24),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.yellow.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.yellow.shade600),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.comment_rounded, size: 16, color: Colors.yellow.shade800),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Nota da Supervisão: ${client['supervisor_notes']}',
                                  style: TextStyle(fontSize: 13, color: Colors.yellow.shade900),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      
                      // Botão para pedir ajuda ao supervisor
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _toggleHelp(client['id'], needsHelp),
                          icon: Icon(
                            needsHelp ? Icons.support_agent_rounded : Icons.pan_tool_outlined,
                            color: needsHelp ? Colors.red : Colors.orange,
                          ),
                          label: Text(
                            needsHelp ? 'Aguardando Supervisor' : 'Solicitar Ajuda no Fechamento',
                            style: TextStyle(color: needsHelp ? Colors.red : Colors.orange),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: needsHelp ? Colors.red : Colors.orange),
                            backgroundColor: needsHelp ? Colors.red.withOpacity(0.05) : Colors.transparent,
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