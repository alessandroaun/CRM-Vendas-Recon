import 'dart:ui'; // Necessário para o efeito de desfoque (Glassmorphism)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';

final categorizedClientsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, category) {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return const Stream.empty();
  final now = DateTime.now();

  return Supabase.instance.client
      .from('clients')
      .stream(primaryKey: ['id'])
      .eq('vendedor_id', userId)
      .order('created_at', ascending: false)
      .map((clients) {
        return clients.where((c) {
          final createdAt = DateTime.parse(c['created_at']);
          final isCurrentMonth = createdAt.year == now.year && createdAt.month == now.month;
          final isClosed = c['stage'] == 'Fechado';

          if (category == 'closed') return isClosed;
          if (category == 'current') return isCurrentMonth && !isClosed;
          if (category == 'negotiating') return !isCurrentMonth && !isClosed;
          return false;
        }).toList();
      });
});

class ClientListScreen extends ConsumerWidget {
  final String category;
  const ClientListScreen({super.key, required this.category});

  String get _screenTitle {
    if (category == 'closed') return 'Contratos Fechados';
    if (category == 'negotiating') return 'Pendências de Carteira';
    return 'Produção ${DateFormat('MMMM', 'pt_BR').format(DateTime.now())}';
  }

  Future<void> _updateStage(BuildContext context, String clientId, String newStage) async {
    try {
      await Supabase.instance.client.from('clients').update({'stage': newStage}).eq('id', clientId);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao atualizar estágio.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsStream = ref.watch(categorizedClientsProvider(category));
    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final stages = ['Novo Cliente', 'Em negociação', 'Cadastrado', 'Fechado'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_screenTitle, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.8)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: clientsStream.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFD97706))),
        error: (error, stack) => Center(child: Text('Erro: $error')),
        data: (clients) {
          double totalValue = 0;
          int imovel = 0, auto = 0, moto = 0, servicos = 0;

          for (var c in clients) {
            totalValue += _parseCurrency(c['credit_value'] ?? '');
            String interest = c['interest'] ?? 'Serviços';
            if (interest.contains('Imóvel')) imovel++;
            else if (interest.contains('Veículos') || interest.contains('Automóvel')) auto++;
            else if (interest.contains('Motocicleta')) moto++;
            else servicos++;
          }

          // Usamos um Stack para colocar o Ticket Flutuante por cima da lista
          return Stack(
            children: [
              // --- LISTA DE CLIENTES ---
              CustomScrollView(
                slivers: [
                  SliverPadding(
                    // O padding top garante que o primeiro card não fique escondido debaixo do ticket
                    padding: const EdgeInsets.only(top: 80, left: 20, right: 20, bottom: 40),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final client = clients[index];
                          
                          return FadeInUp(
                            duration: const Duration(milliseconds: 400),
                            delay: Duration(milliseconds: 50 * index),
                            child: _ClientCard(
                              client: client,
                              currencyFormatter: currencyFormatter,
                              stages: stages,
                              onStageChanged: (val) => _updateStage(context, client['id'], val),
                            ),
                          );
                        },
                        childCount: clients.length,
                      ),
                    ),
                  ),
                ],
              ),

              // --- TICKET FLUTUANTE (Canto Superior Direito) ---
              if (clients.isNotEmpty)
                Positioned(
                  top: 16,
                  right: 16,
                  child: FadeInDown(
                    duration: const Duration(milliseconds: 500),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                currencyFormatter.format(totalValue),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF10B981), letterSpacing: -0.5),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('🏠 $imovel  ', style: const TextStyle(fontSize: 12)),
                                  Text('🚗 $auto  ', style: const TextStyle(fontSize: 12)),
                                  Text('🏍️ $moto  ', style: const TextStyle(fontSize: 12)),
                                  Text('💎 $servicos', style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
              if (clients.isEmpty)
                const Center(child: Text('Nenhum prospect nesta categoria.', style: TextStyle(color: Colors.black54, fontSize: 16))),
            ],
          );
        },
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  final Map<String, dynamic> client;
  final NumberFormat currencyFormatter;
  final List<String> stages;
  final Function(String) onStageChanged;

  const _ClientCard({required this.client, required this.currencyFormatter, required this.stages, required this.onStageChanged});

  Future<void> _openWhatsApp(BuildContext context) async {
    final phone = client['phone'].toString().replaceAll(RegExp(r'\D'), '');
    final finalPhone = (phone.length == 10 || phone.length == 11) ? '55$phone' : phone;
    final text = 'Olá ${client['name']}, aqui é da Consórcio Recon. Vi que você tem interesse em consórcio de ${client['interest']}. Podemos conversar?';
    final url = Uri.parse('https://wa.me/$finalPhone?text=${Uri.encodeComponent(text)}');
    try {
      await Supabase.instance.client.from('interaction_logs').insert({'client_id': client['id'], 'vendedor_id': Supabase.instance.client.auth.currentUser!.id, 'action_type': 'whatsapp'});
      if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) { /* Silencioso no erro de launcher para manter o app fluido */ }
  }

  Future<void> _makePhoneCall(BuildContext context) async {
    final phone = client['phone'].toString().replaceAll(RegExp(r'\D'), '');
    final url = Uri.parse('tel:$phone');
    try {
      await Supabase.instance.client.from('interaction_logs').insert({'client_id': client['id'], 'vendedor_id': Supabase.instance.client.auth.currentUser!.id, 'action_type': 'ligacao'});
      if (await canLaunchUrl(url)) await launchUrl(url);
    } catch (e) {}
  }

  Future<void> _toggleHelp() async {
    final needsHelp = client['needs_supervisor_help'] ?? false;
    await Supabase.instance.client.from('clients').update({'needs_supervisor_help': !needsHelp}).eq('id', client['id']);
  }

  @override
  Widget build(BuildContext context) {
    final stage = client['stage'] ?? 'Novo Cliente';
    final isClosed = stage == 'Fechado';
    final needsHelp = client['needs_supervisor_help'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(client['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.phone_rounded, size: 12, color: Colors.black38),
                        const SizedBox(width: 4),
                        Text(client['phone'], style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              _buildStageButton(stage, isClosed),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12, runSpacing: 10,
            children: [
              _buildHighlight(Icons.monetization_on_rounded, client['credit_value'] ?? 'R\$ 0,00', const Color(0xFF10B981)),
              _buildHighlight(Icons.category_rounded, client['interest'], const Color(0xFF3B82F6)),
            ],
          ),
          if (client['additional_info'] != null && client['additional_info'].toString().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Anotações: ${client['additional_info']}', style: const TextStyle(fontSize: 13, color: Colors.black54, fontStyle: FontStyle.italic)),
          ],
          if (client['supervisor_suggestion'] != null && client['supervisor_suggestion'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12), width: double.infinity,
              decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFFEDD5))),
              child: Text('💡 Orientação: ${client['supervisor_suggestion']}', style: const TextStyle(fontSize: 13, color: Color(0xFF9A3412), fontWeight: FontWeight.w600)),
            ),
          ],
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Color(0xFFF1F5F9), thickness: 1.5)),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _toggleHelp,
                  icon: Icon(needsHelp ? Icons.support_agent_rounded : Icons.pan_tool_outlined, size: 18),
                  label: Text(needsHelp ? 'Aguardando' : 'Pedir Ajuda', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: needsHelp ? const Color(0xFFEF4444) : const Color(0xFFD97706),
                    side: BorderSide(color: needsHelp ? const Color(0xFFEF4444) : const Color(0xFFD97706), width: 1.5),
                    backgroundColor: needsHelp ? const Color(0xFFFEF2F2) : Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildActionButton(Icons.phone_rounded, const Color(0xFF3B82F6), const Color(0xFFEFF6FF), () => _makePhoneCall(context)),
              const SizedBox(width: 8),
              _buildActionButton(Icons.chat_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5), () => _openWhatsApp(context)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStageButton(String stage, bool isClosed) {
    Color baseColor = const Color(0xFF94A3B8);
    bool shouldPulse = false;

    if (stage == 'Novo Cliente') { baseColor = const Color(0xFF10B981); } // Verde
    else if (stage == 'Em negociação') { baseColor = const Color(0xFF0EA5E9); shouldPulse = true; } // Azul Claro
    else if (stage == 'Cadastrado') { baseColor = const Color(0xFFF59E0B); shouldPulse = true; } // Laranja

    Widget btn = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: isClosed ? const Color(0xFFF1F5F9) : baseColor, borderRadius: BorderRadius.circular(10)),
      child: Text(stage, style: TextStyle(color: isClosed ? Colors.black38 : Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );

    // Envolvemos o botão na pulsação customizada suave, se necessário
    if (shouldPulse && !isClosed) {
      btn = _SubtlePulse(child: btn);
    }

    // AGORA SIM: O botão de menu engloba a animação inteira, garantindo o clique!
    return PopupMenuButton<String>(
      onSelected: onStageChanged,
      itemBuilder: (ctx) => stages.map((s) => PopupMenuItem(value: s, child: Text(s, style: TextStyle(fontWeight: s == stage ? FontWeight.bold : FontWeight.normal)))).toList(),
      child: btn,
    );
  }

  Widget _buildHighlight(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: color), const SizedBox(width: 6), Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12))]),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, Color bgColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(12),
      child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
    );
  }
}

// --- ANIMAÇÃO DE PULSAÇÃO SUAVE ---
class _SubtlePulse extends StatefulWidget {
  final Widget child;
  const _SubtlePulse({required this.child});
  @override
  State<_SubtlePulse> createState() => _SubtlePulseState();
}

class _SubtlePulseState extends State<_SubtlePulse> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    // Aumenta o tamanho em apenas 3%, o que deixa extremamente elegante e nada agressivo
    _animation = Tween<double>(begin: 1.0, end: 1.03).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _animation, child: widget.child);
  }
}

double _parseCurrency(String value) {
  if (value.isEmpty) return 0.0;
  String clean = value.replaceAll(RegExp(r'[^0-9,\.]'), '');
  if (clean.isEmpty) return 0.0;
  if (clean.contains('.') && clean.contains(',')) { clean = clean.replaceAll('.', '').replaceAll(',', '.'); } 
  else if (clean.contains(',')) { clean = clean.replaceAll(',', '.'); } 
  else if (clean.contains('.') && clean.lastIndexOf('.') < clean.length - 3) { clean = clean.replaceAll('.', ''); }
  return double.tryParse(clean) ?? 0.0;
}