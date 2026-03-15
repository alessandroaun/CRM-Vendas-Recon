import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';

// Provedor Global
final allFunnelClientsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return const Stream.empty();

  return Supabase.instance.client
      .from('clients')
      .stream(primaryKey: ['id'])
      .eq('vendedor_id', userId)
      .order('created_at', ascending: false);
});

// ------------------------------------------------------------------------
// TELA 1: O HUB DO FUNIL
// ------------------------------------------------------------------------
class FunnelScreen extends ConsumerWidget {
  const FunnelScreen({super.key});

  double _parseCurrency(String value) {
    if (value.isEmpty) return 0.0;
    String clean = value.replaceAll(RegExp(r'[^0-9,\.]'), '');
    if (clean.isEmpty) return 0.0;
    if (clean.contains('.') && clean.contains(',')) clean = clean.replaceAll('.', '').replaceAll(',', '.');
    else if (clean.contains(',')) clean = clean.replaceAll(',', '.');
    return double.tryParse(clean) ?? 0.0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsStream = ref.watch(allFunnelClientsProvider);
    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final currentMonthName = DateFormat('MMMM', 'pt_BR').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0, centerTitle: true,
        title: const Text('Gestão do Funil', style: TextStyle(color: Color(0xFF1E293B), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
      ),
      body: clientsStream.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
        error: (err, stack) => Center(child: Text('Erro: $err')),
        data: (clients) {
          final now = DateTime.now();
          double totalProducao = 0, totalCarteira = 0, totalFechados = 0, totalDesistentes = 0;
          int countProducao = 0, countCarteira = 0, countFechados = 0, countDesistentes = 0;

          for (var c in clients) {
            final val = _parseCurrency(c['credit_value'] ?? '');
            final createdAt = DateTime.parse(c['created_at']);
            final isCurrentMonth = createdAt.year == now.year && createdAt.month == now.month;
            final stage = c['stage'] ?? 'Novo Cliente';

            if (stage == 'Fechado') { totalFechados += val; countFechados++; } 
            else if (stage == 'Desistente') { totalDesistentes += val; countDesistentes++; } 
            else if (isCurrentMonth) { totalProducao += val; countProducao++; } 
            else { totalCarteira += val; countCarteira++; }
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            children: [
              FadeInDown(child: const Text('Selecione a Carteira', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
              const SizedBox(height: 16),
              FadeInUp(delay: const Duration(milliseconds: 100), child: _buildHubCard(context, 'Produção de $currentMonthName', 'Prospecções do mês atual', totalProducao, countProducao, currencyFormatter, 'producao', const Color(0xFF4F46E5), Icons.calendar_month_rounded)),
              const SizedBox(height: 16),
              FadeInUp(delay: const Duration(milliseconds: 200), child: _buildHubCard(context, 'Carteira de Negociação', 'Pendências de meses anteriores', totalCarteira, countCarteira, currencyFormatter, 'carteira', const Color(0xFF0EA5E9), Icons.hourglass_top_rounded)),
              const SizedBox(height: 16),
              FadeInUp(delay: const Duration(milliseconds: 300), child: _buildHubCard(context, 'Contratos Fechados', 'Histórico de sucessos', totalFechados, countFechados, currencyFormatter, 'fechados', const Color(0xFF10B981), Icons.handshake_rounded)),
              const SizedBox(height: 16),
              FadeInUp(delay: const Duration(milliseconds: 400), child: _buildHubCard(context, 'Desistentes / Excluídos', 'Oportunidades perdidas', totalDesistentes, countDesistentes, currencyFormatter, 'desistentes', const Color(0xFFEF4444), Icons.delete_sweep_rounded)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHubCard(BuildContext context, String title, String subtitle, double total, int count, NumberFormat formatter, String category, Color color, IconData icon) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FunnelListScreen(category: category, title: title))),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))]),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 28)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.3)), Text('$count clientes • $subtitle', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))), const SizedBox(height: 8), Text(formatter.format(total), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5))])),
            const Icon(Icons.chevron_right_rounded, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------
// TELA 2: A LISTA COM KANBAN, PESQUISA NA APPBAR E FILTRO FLUTUANTE
// ------------------------------------------------------------------------
class FunnelListScreen extends ConsumerStatefulWidget {
  final String category;
  final String title;
  const FunnelListScreen({super.key, required this.category, required this.title});

  @override
  ConsumerState<FunnelListScreen> createState() => _FunnelListScreenState();
}

class _FunnelListScreenState extends ConsumerState<FunnelListScreen> {
  bool _isSearching = false;
  String _searchQuery = '';
  String? _selectedStage; // null significa que todos estão sendo exibidos
  String? _selectedSegment; // null significa todos

  final TextEditingController _searchController = TextEditingController();
  final List<String> _stages = ['Novo Cliente', 'Em negociação', 'Cadastrado'];
  final List<String> _segments = ['Imóvel', 'Automóvel', 'Motocicleta', 'Serviços'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSegmentFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filtrar por Segmento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 16),
            ..._segments.map((seg) => _buildSegmentOption(seg)).toList(),
            const Divider(height: 32),
            ListTile(
              onTap: () { setState(() => _selectedSegment = null); Navigator.pop(context); },
              leading: const Icon(Icons.clear_all_rounded, color: Colors.redAccent),
              title: const Text('Limpar Filtros', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentOption(String label) {
    String prefix = '';
    if (label == 'Imóvel') prefix = '🏠';
    if (label == 'Automóvel') prefix = '🚗';
    if (label == 'Motocicleta') prefix = '🏍️';
    if (label == 'Serviços') prefix = '💎';

    final isSelected = _selectedSegment == label;

    return ListTile(
      onTap: () { setState(() => _selectedSegment = label); Navigator.pop(context); },
      leading: Text(prefix, style: const TextStyle(fontSize: 20)),
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF1E293B))),
      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFF4F46E5)) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientsStream = ref.watch(allFunnelClientsProvider);
    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final bool isFilteredCategory = widget.category == 'producao' || widget.category == 'carteira';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A), 
        foregroundColor: Colors.white, 
        elevation: 0, 
        titleSpacing: _isSearching ? 0 : NavigationToolbar.kMiddleSpacing,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: const InputDecoration(
                  hintText: 'Buscar por nome...',
                  hintStyle: TextStyle(color: Colors.white54, fontSize: 15),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                ),
              )
            : Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSegmentFilters,
        backgroundColor: const Color(0xFF0F172A),
        elevation: 4,
        icon: const Icon(Icons.filter_alt_rounded, color: Colors.white, size: 18),
        label: Text(_selectedSegment ?? 'Segmentos', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
      body: clientsStream.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
        error: (err, stack) => Center(child: Text('Erro: $err')),
        data: (allClients) {
          final now = DateTime.now();
          
          final filteredClients = allClients.where((c) {
            final createdAt = DateTime.parse(c['created_at']);
            final isCurrentMonth = createdAt.year == now.year && createdAt.month == now.month;
            final stage = c['stage'] ?? 'Novo Cliente';
            final interest = c['interest'] ?? 'Serviços';
            final name = (c['name'] ?? '').toString().toLowerCase();

            // Categoria
            bool matchesCategory = false;
            if (widget.category == 'fechados') matchesCategory = stage == 'Fechado';
            else if (widget.category == 'desistentes') matchesCategory = stage == 'Desistente';
            else if (widget.category == 'producao') matchesCategory = isCurrentMonth && stage != 'Fechado' && stage != 'Desistente';
            else if (widget.category == 'carteira') matchesCategory = !isCurrentMonth && stage != 'Fechado' && stage != 'Desistente';

            if (!matchesCategory) return false;

            // Pesquisa
            if (_searchQuery.isNotEmpty && !name.contains(_searchQuery.toLowerCase())) return false;

            // Kanban Stage
            if (isFilteredCategory && _selectedStage != null && stage != _selectedStage) return false;

            // Segmento
            if (_selectedSegment != null) {
              String mappedInterest = interest;
              if (interest.contains('Veículos')) mappedInterest = 'Automóvel';
              if (mappedInterest != _selectedSegment) return false;
            }

            return true;
          }).toList();

          return Column(
            children: [
              // --- COLUNAS DO KANBAN INVISÍVEL ---
              if (isFilteredCategory)
                Container(
                  color: Colors.white,
                  child: Row(
                    children: _stages.map((stage) {
                      final isSelected = _selectedStage == stage;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              // Se já estiver selecionado, desseleciona (mostra todos)
                              _selectedStage = isSelected ? null : stage;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Text(
                              stage,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              
              // --- LISTA DE CLIENTES ---
              Expanded(
                child: filteredClients.isEmpty 
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inbox_rounded, size: 64, color: Color(0xFFCBD5E1)),
                          const SizedBox(height: 16),
                          Text(
                            _selectedStage != null ? 'Nenhum cliente em "$_selectedStage"' : 'Nenhum cliente encontrado.',
                            style: const TextStyle(color: Colors.black54, fontSize: 15),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 80), // bottom alto pro botão não tampar o último
                      itemCount: filteredClients.length,
                      itemBuilder: (context, index) {
                        return FadeInUp(
                          duration: const Duration(milliseconds: 300),
                          child: _ExpandableClientCard(client: filteredClients[index], currencyFormatter: currencyFormatter),
                        );
                      },
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------------
// COMPONENTE: O CARD EXPANSÍVEL (Inalterado, apenas replicado para não quebrar)
// ------------------------------------------------------------------------
class _ExpandableClientCard extends StatefulWidget {
  final Map<String, dynamic> client;
  final NumberFormat currencyFormatter;
  const _ExpandableClientCard({required this.client, required this.currencyFormatter});

  @override
  State<_ExpandableClientCard> createState() => _ExpandableClientCardState();
}

class _ExpandableClientCardState extends State<_ExpandableClientCard> {
  bool _isExpanded = false;
  final List<String> stages = ['Novo Cliente', 'Em negociação', 'Cadastrado', 'Fechado', 'Desistente'];

  Future<void> _updateStage(String newStage) async {
    if (newStage == 'Desistente') {
      _showExclusionDialog();
    } else {
      await _saveStageToDB(newStage, null);
    }
  }

  Future<void> _saveStageToDB(String stage, String? exclusionReason) async {
    try {
      Map<String, dynamic> updates = {'stage': stage};
      if (exclusionReason != null && exclusionReason.trim().isNotEmpty) {
        String currentInfo = widget.client['additional_info'] ?? '';
        updates['additional_info'] = '[MOTIVO EXCLUSÃO]: $exclusionReason\n$currentInfo';
      }
      await Supabase.instance.client.from('clients').update(updates).eq('id', widget.client['id']);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao atualizar.')));
    }
  }

  void _showExclusionDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Motivo da Desistência', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        content: TextField(
          controller: reasonController, maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Ex: Achou a parcela alta...',
            filled: true, fillColor: const Color(0xFFF1F5F9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.black54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              _saveStageToDB('Desistente', reasonController.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Confirmar Exclusão', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeAction(String actionType) async {
    final phone = widget.client['phone'].toString().replaceAll(RegExp(r'\D'), '');
    final finalPhone = (phone.length == 10 || phone.length == 11) ? '55$phone' : phone;
    Uri url = actionType == 'whatsapp' ? Uri.parse('https://wa.me/$finalPhone?text=Olá') : Uri.parse('tel:$phone');
    try {
      await Supabase.instance.client.from('interaction_logs').insert({'client_id': widget.client['id'], 'vendedor_id': Supabase.instance.client.auth.currentUser!.id, 'action_type': actionType});
      if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    final stage = widget.client['stage'] ?? 'Novo Cliente';
    final creditText = widget.client['credit_value']?.toString().isEmpty ?? true ? 'Valor não definido' : widget.client['credit_value'];

    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut, margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: _isExpanded ? const Color(0xFF4F46E5).withOpacity(0.3) : Colors.transparent, width: 1.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(height: 48, width: 48, decoration: const BoxDecoration(color: Color(0xFFF4F7FE), shape: BoxShape.circle), child: const Icon(Icons.person_outline_rounded, color: Color(0xFF4F46E5))),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.client['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.3), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4), Text(widget.client['phone'], style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    _buildStageBadge(stage),
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
                            Row(children: [_buildHighlight(Icons.monetization_on_rounded, creditText, const Color(0xFF10B981)), const SizedBox(width: 12), _buildHighlight(Icons.category_rounded, widget.client['interest'] ?? 'Serviços', const Color(0xFF3B82F6))]),
                            if (widget.client['additional_info'] != null && widget.client['additional_info'].toString().isNotEmpty) ...[
                              const SizedBox(height: 16), Text('Anotações: ${widget.client['additional_info']}', style: const TextStyle(fontSize: 13, color: Colors.black54, fontStyle: FontStyle.italic)),
                            ],
                            const SizedBox(height: 20),
                            Row(children: [
                              Expanded(child: _buildActionButton(Icons.phone_rounded, 'Ligar', const Color(0xFF3B82F6), const Color(0xFFEFF6FF), () => _executeAction('ligacao'))),
                              const SizedBox(width: 12), Expanded(child: _buildActionButton(Icons.chat_rounded, 'WhatsApp', const Color(0xFF10B981), const Color(0xFFECFDF5), () => _executeAction('whatsapp'))),
                            ]),
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

  Widget _buildStageBadge(String stage) {
    Color baseColor = const Color(0xFF94A3B8); bool shouldPulse = false;
    if (stage == 'Novo Cliente') baseColor = const Color(0xFF10B981);
    else if (stage == 'Em negociação') { baseColor = const Color(0xFF3B82F6); shouldPulse = true; }
    else if (stage == 'Cadastrado') { baseColor = const Color(0xFFF59E0B); shouldPulse = true; }
    else if (stage == 'Desistente') { baseColor = const Color(0xFFEF4444); }

    Widget btn = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: baseColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: baseColor.withOpacity(0.3))),
      child: Text(stage, style: TextStyle(color: baseColor, fontSize: 10, fontWeight: FontWeight.bold)),
    );

    if (shouldPulse) btn = _SubtlePulse(child: btn);

    return PopupMenuButton<String>(
      onSelected: _updateStage,
      itemBuilder: (ctx) => stages.map((s) => PopupMenuItem(value: s, child: Text(s, style: TextStyle(fontWeight: s == stage ? FontWeight.bold : FontWeight.normal, color: s == 'Desistente' ? Colors.red : Colors.black87)))).toList(),
      child: btn,
    );
  }

  Widget _buildHighlight(IconData icon, String text, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: color), const SizedBox(width: 6), Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12))]));
  }

  Widget _buildActionButton(IconData icon, String label, Color color, Color bgColor, VoidCallback onTap) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color, size: 16), const SizedBox(width: 6), Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold))])));
  }
}

class _SubtlePulse extends StatefulWidget { final Widget child; const _SubtlePulse({required this.child}); @override State<_SubtlePulse> createState() => _SubtlePulseState(); }
class _SubtlePulseState extends State<_SubtlePulse> with SingleTickerProviderStateMixin {
  late AnimationController _c; late Animation<double> _a;
  @override void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true); _a = Tween<double>(begin: 1.0, end: 1.03).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) { return ScaleTransition(scale: _a, child: widget.child); }
}