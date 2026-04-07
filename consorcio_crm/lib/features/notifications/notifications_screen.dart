import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';

import '../auth/profile_provider.dart';
import '../client_manage/funnel_screen.dart'; // Puxa o myClientsProvider

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0, centerTitle: true,
        title: const Text('Avisos e Acompanhamentos', style: TextStyle(color: Color(0xFF1E293B), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
        error: (err, _) => Center(child: Text('Erro: $err')),
        data: (profile) {
          if (profile == null) return const SizedBox.shrink();

          final clientsAsync = ref.watch(myClientsProvider(profile.id));

          return clientsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
            error: (err, _) => Center(child: Text('Erro: $err')),
            data: (allClients) {
              // Filtra APENAS os clientes em Modo Ajuda
              final noticeClients = allClients.where((c) => c['is_help_mode'] == true).toList();

              // Ordena pela data do cliente
              noticeClients.sort((a, b) => DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));

              if (noticeClients.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.check_circle_outline_rounded, size: 64, color: Color(0xFFCBD5E1)),
                      SizedBox(height: 16),
                      Text('Tudo tranquilo! Nenhum acompanhamento ativo.', style: TextStyle(color: Colors.black54, fontSize: 13)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: noticeClients.length,
                itemBuilder: (context, index) {
                  return FadeInUp(
                    duration: const Duration(milliseconds: 300),
                    child: _NoticeClientCard(client: noticeClients[index], currencyFormatter: currencyFormatter),
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

// --- CARD DO VENDEDOR (REPLICA DO FUNIL) ---
class _NoticeClientCard extends StatefulWidget {
  final Map<String, dynamic> client;
  final NumberFormat currencyFormatter;
  const _NoticeClientCard({required this.client, required this.currencyFormatter});

  @override
  State<_NoticeClientCard> createState() => _NoticeClientCardState();
}

class _NoticeClientCardState extends State<_NoticeClientCard> {
  bool _isExpanded = false;
  final TextEditingController _msgController = TextEditingController();

  @override
  void dispose() { _msgController.dispose(); super.dispose(); }

  Future<void> _executeAction(String actionType) async {
    final phone = widget.client['phone'].toString().replaceAll(RegExp(r'\D'), '');
    final finalPhone = (phone.length == 10 || phone.length == 11) ? '55$phone' : phone;
    Uri url = actionType == 'whatsapp' ? Uri.parse('https://wa.me/$finalPhone?text=Olá') : Uri.parse('tel:$phone');
    try { await launchUrl(url, mode: LaunchMode.externalApplication); } catch (e) {}
  }

  Future<void> _sendMessage({bool requestingHelp = false}) async {
    if (_msgController.text.trim().isEmpty && !requestingHelp) return;

    final String text = _msgController.text.trim();
    final List<dynamic> currentHistory = widget.client['chat_history'] != null ? List<dynamic>.from(widget.client['chat_history']) : [];

    if (text.isNotEmpty) {
      currentHistory.add({'sender': 'vendedor', 'text': text, 'timestamp': DateTime.now().toIso8601String(), 'is_alert': requestingHelp});
    }

    final bool isHelpMode = widget.client['is_help_mode'] == true;
    final Map<String, dynamic> updateData = {'chat_history': currentHistory};
    
    if (requestingHelp) {
      updateData['is_help_mode'] = true;
      updateData['phone_released'] = true; // Se ele pede ajuda, já libera o telefone!
    }
    
    if (requestingHelp || isHelpMode) {
      updateData['unread_supervisor'] = (widget.client['unread_supervisor'] ?? 0) + 1;
    }

    await Supabase.instance.client.from('clients').update(updateData).eq('id', widget.client['id']);
    if (mounted) { _msgController.clear(); FocusScope.of(context).unfocus(); }
  }

  // BOTÃO PARA ACEITAR AJUDA DO GESTOR
  Future<void> _acceptSupervisorHelp() async {
    await Supabase.instance.client.from('clients').update({
      'phone_released': true,
    }).eq('id', widget.client['id']);
    if (mounted) {
      showTopSnackBar(
        Overlay.of(context),
        const CustomSnackBar.success(message: 'Contato liberado para a gestão.'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final creditText = widget.client['credit_value']?.toString().isEmpty ?? true ? 'Valor não definido' : widget.client['credit_value'];
    final bool isHelpMode = widget.client['is_help_mode'] == true;
    final bool phoneReleased = widget.client['phone_released'] == true;
    final List<dynamic> chatHistory = widget.client['chat_history'] != null ? List<dynamic>.from(widget.client['chat_history']) : [];
    final int unread = widget.client['unread_vendedor'] ?? 0;

    return GestureDetector(
      onTap: () async {
        setState(() => _isExpanded = !_isExpanded);
        if (_isExpanded && unread > 0) {
          await Supabase.instance.client.from('clients').update({'unread_vendedor': 0}).eq('id', widget.client['id']);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut, margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.redAccent.withOpacity(0.5), width: 2.0), boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 8))]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(height: 48, width: 48, decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.support_agent_rounded, color: Colors.redAccent)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.client['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.3), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4), 
                          Text(widget.client['phone'], style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                          if (unread > 0)
                            Container(margin: const EdgeInsets.only(top: 6), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(6)), child: const Text('NOVA MENSAGEM DO GESTOR', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
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
                            Row(children: [ Expanded(child: _buildHighlight(Icons.monetization_on_rounded, creditText, const Color(0xFF10B981))), const SizedBox(width: 12), Expanded(child: _buildHighlight(Icons.category_rounded, widget.client['interest'] ?? 'Serviços', const Color(0xFF3B82F6))) ]),
                            const SizedBox(height: 20),
                            Row(children: [ Expanded(child: _buildActionButton(Icons.phone_rounded, 'Ligar', const Color(0xFF3B82F6), const Color(0xFFEFF6FF), () => _executeAction('ligacao'))), const SizedBox(width: 12), Expanded(child: _buildActionButton(Icons.chat_rounded, 'WhatsApp', const Color(0xFF10B981), const Color(0xFFECFDF5), () => _executeAction('whatsapp'))), ]),
                            const SizedBox(height: 24),
                            const Text('Histórico e Ações', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                            const SizedBox(height: 12),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 250), padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
                              child: chatHistory.isEmpty ? const Center(child: Text('Nenhuma anotação ainda.', style: TextStyle(fontSize: 12, color: Colors.black38))) : ListView.builder(shrinkWrap: true, itemCount: chatHistory.length, itemBuilder: (ctx, i) => _buildChatBubble(chatHistory[i], isMe: chatHistory[i]['sender'] == 'vendedor')),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: TextField(controller: _msgController, style: const TextStyle(fontSize: 13), decoration: InputDecoration(hintText: 'Adicionar anotação...', filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFE2E8F0))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFE2E8F0)))))),
                                const SizedBox(width: 8),
                                InkWell(onTap: () => _sendMessage(), borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Color(0xFF4F46E5), shape: BoxShape.circle), child: const Icon(Icons.send_rounded, color: Colors.white, size: 18)))
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            // BOTÕES DE ALERTA E ACEITE
                            if (!isHelpMode) ...[
                              InkWell(onTap: () => _sendMessage(requestingHelp: true), borderRadius: BorderRadius.circular(12), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.redAccent.withOpacity(0.3))), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.sos_rounded, color: Colors.redAccent, size: 16), SizedBox(width: 6), Text('Escalonar / Pedir Ajuda', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold))]))),
                            ] else if (isHelpMode && !phoneReleased) ...[
                              InkWell(onTap: _acceptSupervisorHelp, borderRadius: BorderRadius.circular(12), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3))), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.handshake_rounded, color: Color(0xFF10B981), size: 16), SizedBox(width: 6), Text('Aceitar Ajuda e Liberar Contato', style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold))]))),
                            ] else ...[
                              const Center(child: Text('Modo Ajuda Ativo - Acompanhamento da Gestão', style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold))),
                            ],
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

  Widget _buildChatBubble(Map<String, dynamic> msg, {required bool isMe}) {
    final date = DateTime.tryParse(msg['timestamp'] ?? '');
    final dateStr = date != null ? DateFormat('dd/MM HH:mm').format(date) : '';
    final bool isAlert = msg['is_alert'] == true;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), constraints: const BoxConstraints(maxWidth: 240),
        decoration: BoxDecoration(color: isAlert ? const Color(0xFFFEF2F2) : (isMe ? const Color(0xFFEEF2FF) : const Color(0xFFFFFBEB)), borderRadius: BorderRadius.only(topLeft: const Radius.circular(12), topRight: const Radius.circular(12), bottomLeft: Radius.circular(isMe ? 12 : 2), bottomRight: Radius.circular(isMe ? 2 : 12)), border: Border.all(color: isAlert ? Colors.red.withOpacity(0.3) : (isMe ? const Color(0xFFC7D2FE) : const Color(0xFFFDE68A)))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [Icon(isMe ? Icons.person_rounded : Icons.admin_panel_settings_rounded, size: 10, color: isAlert ? Colors.redAccent : (isMe ? const Color(0xFF4F46E5) : const Color(0xFFD97706))), const SizedBox(width: 4), Text(isAlert ? 'Pedido de Ajuda' : (isMe ? 'Eu (Vendedor)' : 'Gestão'), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isAlert ? Colors.redAccent : (isMe ? const Color(0xFF4F46E5) : const Color(0xFFD97706))))]),
          const SizedBox(height: 4), Text(msg['text'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))), const SizedBox(height: 4), Align(alignment: Alignment.bottomRight, child: Text(dateStr, style: const TextStyle(fontSize: 8, color: Colors.black38))),
        ]),
      ),
    );
  }

  Widget _buildHighlight(IconData icon, String text, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: color), const SizedBox(width: 6), Flexible(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis))]));
  }

  Widget _buildActionButton(IconData icon, String label, Color color, Color bgColor, VoidCallback onTap) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color, size: 16), const SizedBox(width: 6), Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold))])));
  }
}