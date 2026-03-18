import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';

import '../auth/profile_provider.dart';

// Cole os dois provedores aqui:
final teamClientsProvider = StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, teamId) {
  return Supabase.instance.client.from('clients').stream(primaryKey: ['id']).eq('team_id', teamId).order('created_at', ascending: false);
});

final teamMembersProvider = StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, teamId) {
  return Supabase.instance.client.from('profiles').stream(primaryKey: ['id']).eq('team_id', teamId);
});

class TeamDemandsScreen extends ConsumerWidget {
  const TeamDemandsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0, centerTitle: true,
        title: const Text('Demandas e Orientações', style: TextStyle(color: Color(0xFF1E293B), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
        error: (err, stack) => Center(child: Text('Erro: $err')),
        data: (profile) {
          if (profile == null || profile.teamId == null) {
            return const Center(child: Text('Sem equipe vinculada.'));
          }

          final teamId = profile.teamId!;
          final clientsAsync = ref.watch(teamClientsProvider(teamId));
          final membersAsync = ref.watch(teamMembersProvider(teamId));

          return clientsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
            error: (err, stack) => Center(child: Text('Erro: $err')),
            data: (allClients) {
              // Mapeamento de Vendedores
              Map<String, String> sellerNames = {};
              membersAsync.whenData((members) {
                for (var m in members) sellerNames[m['id']] = m['full_name'] ?? 'Desconhecido';
              });

              // Vamos focar as demandas nos clientes que NÃO estão fechados nem excluídos
              final activeClients = allClients.where((c) {
                final stage = c['stage'] ?? 'Novo Cliente';
                return stage != 'Fechado' && stage != 'Desistente';
              }).toList();

              if (activeClients.isEmpty) {
                return Center(
                  child: FadeInDown(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.05), shape: BoxShape.circle), child: const Icon(Icons.check_circle_outline_rounded, size: 64, color: Color(0xFF94A3B8))),
                        const SizedBox(height: 24),
                        const Text('Nenhuma demanda pendente!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), letterSpacing: -0.5)),
                        const SizedBox(height: 8),
                        const Text('O funil da sua equipe está limpo.', style: TextStyle(color: Colors.black54, fontSize: 14)),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                itemCount: activeClients.length,
                itemBuilder: (context, index) {
                  final client = activeClients[index];
                  final sellerFullName = sellerNames[client['vendedor_id']] ?? 'Equipe';
                  final sellerFirstName = sellerFullName.split(' ').first;

                  return FadeInUp(
                    duration: const Duration(milliseconds: 300),
                    delay: Duration(milliseconds: 50 * index),
                    child: _GuidanceClientCard(
                      client: client,
                      currencyFormatter: currencyFormatter,
                      sellerFirstName: sellerFirstName,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------------
// COMPONENTE: CARD COM CAMPO PARA ENVIAR ORIENTAÇÃO
// ------------------------------------------------------------------------
class _GuidanceClientCard extends StatefulWidget {
  final Map<String, dynamic> client;
  final NumberFormat currencyFormatter;
  final String sellerFirstName;

  const _GuidanceClientCard({
    required this.client,
    required this.currencyFormatter,
    required this.sellerFirstName,
  });

  @override
  State<_GuidanceClientCard> createState() => _GuidanceClientCardState();
}

class _GuidanceClientCardState extends State<_GuidanceClientCard> {
  bool _isExpanded = false;
  bool _isSending = false;
  final TextEditingController _suggestionController = TextEditingController();

  @override
  void dispose() {
    _suggestionController.dispose();
    super.dispose();
  }

  Future<void> _sendSuggestion() async {
    final text = _suggestionController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      await Supabase.instance.client
          .from('clients')
          .update({'supervisor_suggestion': text})
          .eq('id', widget.client['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Orientação enviada com sucesso!'), backgroundColor: Color(0xFF10B981)));
        _suggestionController.clear();
        setState(() => _isExpanded = false); // Fecha o card após enviar
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao enviar orientação.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stage = widget.client['stage'] ?? 'Novo Cliente';
    final creditText = widget.client['credit_value']?.toString().isEmpty ?? true ? 'N/D' : widget.client['credit_value'];
    
    // Verifica se já existe uma sugestão pendente para não mandar outra por cima sem saber
    final hasPendingSuggestion = widget.client['supervisor_suggestion'] != null && widget.client['supervisor_suggestion'].toString().trim().isNotEmpty;

    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut, margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(24), 
          border: Border.all(color: _isExpanded ? const Color(0xFFF59E0B).withOpacity(0.4) : (hasPendingSuggestion ? const Color(0xFF10B981).withOpacity(0.3) : Colors.transparent), width: 1.5), 
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))]
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(height: 48, width: 48, decoration: BoxDecoration(color: hasPendingSuggestion ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB), shape: BoxShape.circle), child: Icon(hasPendingSuggestion ? Icons.mark_chat_read_rounded : Icons.support_agent_rounded, color: hasPendingSuggestion ? const Color(0xFF10B981) : const Color(0xFFF59E0B))),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.client['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.3), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4), 
                          Row(
                            children: [
                              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)), child: Row(children: [const Icon(Icons.badge_rounded, size: 10, color: Color(0xFF64748B)), const SizedBox(width: 4), Text(widget.sellerFirstName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))])),
                              const SizedBox(width: 8),
                              Text(stage, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                            ],
                          )
                        ],
                      ),
                    ),
                    Text(creditText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5))),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300), curve: Curves.easeInOut, alignment: Alignment.topCenter,
                child: _isExpanded
                    ? Container(
                        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(color: Color(0xFFF1F5F9), thickness: 1.5, height: 1),
                            const SizedBox(height: 16),
                            if (widget.client['additional_info'] != null && widget.client['additional_info'].toString().isNotEmpty) ...[
                              Text('Notas do vendedor: ${widget.client['additional_info']}', style: const TextStyle(fontSize: 12, color: Colors.black54, fontStyle: FontStyle.italic)),
                              const SizedBox(height: 16),
                            ],
                            if (hasPendingSuggestion) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2))),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Orientação já enviada (Aguardando leitura):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                                    const SizedBox(height: 4),
                                    Text('"${widget.client['supervisor_suggestion']}"', style: const TextStyle(fontSize: 13, color: Color(0xFF064E3B), fontStyle: FontStyle.italic)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            TextField(
                              controller: _suggestionController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText: hasPendingSuggestion ? 'Sobrescrever orientação atual...' : 'Escreva uma orientação tática...',
                                hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                onPressed: _isSending ? null : _sendSuggestion,
                                icon: _isSending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send_rounded, size: 16),
                                label: const Text('Enviar ao Vendedor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF59E0B),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            )
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}