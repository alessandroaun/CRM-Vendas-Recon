import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';

import '../auth/profile_provider.dart';
import 'team_funnel_screen.dart'; // <--- IMPORT DA NAVEGAÇÃO

// --- MÁSCARA DE DATA ---
class DateTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 8) text = text.substring(0, 8);
    String newText = '';
    for (int i = 0; i < text.length; i++) {
      if (i == 2 || i == 4) newText += '/';
      newText += text[i];
    }
    return TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newText.length));
  }
}

// --- PROVEDORES ---
final teamClientsProvider = StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, teamId) {
  return Supabase.instance.client
      .from('clients')
      .stream(primaryKey: ['id'])
      .eq('team_id', teamId)
      .order('created_at', ascending: false);
});

final teamMembersProvider = StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, teamId) {
  return Supabase.instance.client
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('team_id', teamId);
});

class TeamOverviewScreen extends ConsumerStatefulWidget {
  const TeamOverviewScreen({super.key});

  @override
  ConsumerState<TeamOverviewScreen> createState() => _TeamOverviewScreenState();
}

class _TeamOverviewScreenState extends ConsumerState<TeamOverviewScreen> {
  int _selectedFilterIndex = 0; 
  final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  double _parseCurrency(String value) {
    if (value.isEmpty) return 0.0;
    String clean = value.replaceAll(RegExp(r'[^0-9,\.]'), '');
    if (clean.isEmpty) return 0.0;
    if (clean.contains('.') && clean.contains(',')) clean = clean.replaceAll('.', '').replaceAll(',', '.');
    else if (clean.contains(',')) clean = clean.replaceAll(',', '.');
    return double.tryParse(clean) ?? 0.0;
  }

  void _showCustomDateDialog(BuildContext context) {
    final startCtrl = TextEditingController(text: _customStartDate != null ? DateFormat('dd/MM/yyyy').format(_customStartDate!) : '');
    final endCtrl = TextEditingController(text: _customEndDate != null ? DateFormat('dd/MM/yyyy').format(_customEndDate!) : '');

    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Período Personalizado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A), letterSpacing: -0.5)),
        content: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filtre a produção da sua equipe:', style: TextStyle(color: Colors.black54, fontSize: 13)),
            const SizedBox(height: 20),
            TextField(controller: startCtrl, keyboardType: TextInputType.number, inputFormatters: [DateTextFormatter()], decoration: InputDecoration(labelText: 'Data Inicial', hintText: 'DD/MM/AAAA', filled: true, fillColor: const Color(0xFFF4F7FE), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF4F46E5)))),
            const SizedBox(height: 12),
            TextField(controller: endCtrl, keyboardType: TextInputType.number, inputFormatters: [DateTextFormatter()], decoration: InputDecoration(labelText: 'Data Final', hintText: 'DD/MM/AAAA', filled: true, fillColor: const Color(0xFFF4F7FE), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), prefixIcon: const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF4F46E5)))),
          ],
        ),
        actions: [
          TextButton(onPressed: () { Navigator.pop(ctx); if (_customStartDate == null) setState(() => _selectedFilterIndex = 0); }, child: const Text('Cancelar', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              try {
                final start = DateFormat('dd/MM/yyyy').parseStrict(startCtrl.text);
                final end = DateFormat('dd/MM/yyyy').parseStrict(endCtrl.text).add(const Duration(hours: 23, minutes: 59, seconds: 59));
                if (start.isAfter(end)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A data inicial não pode ser maior que a final.'))); return; }
                setState(() { _customStartDate = start; _customEndDate = end; _selectedFilterIndex = 2; });
                Navigator.pop(ctx);
              } catch (e) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, digite datas válidas.'))); }
            },
            child: const Text('Aplicar Filtro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      )
    );
  }

  List<Map<String, dynamic>> _filterClients(List<Map<String, dynamic>> allClients) {
    final now = DateTime.now();
    return allClients.where((c) {
      if (_selectedFilterIndex == 1) return true; 
      final createdAt = DateTime.parse(c['created_at']);
      if (_selectedFilterIndex == 0) return createdAt.year == now.year && createdAt.month == now.month;
      if (_selectedFilterIndex == 2 && _customStartDate != null && _customEndDate != null) {
        return createdAt.isAfter(_customStartDate!.subtract(const Duration(seconds: 1))) && createdAt.isBefore(_customEndDate!.add(const Duration(seconds: 1)));
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0, centerTitle: true,
        title: const Text('Gestão de Equipe', style: TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: profileAsync.when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
        error: (err, stack) => Center(child: Text('Erro: $err')),
        data: (profile) {
          if (profile == null || profile.teamId == null) {
            return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('Sua conta não está vinculada a nenhuma equipe. Contate o administrador.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.black54))));
          }

          final teamId = profile.teamId!;
          final clientsAsync = ref.watch(teamClientsProvider(teamId));
          final membersAsync = ref.watch(teamMembersProvider(teamId));

          return clientsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
            error: (err, stack) => Center(child: Text('Erro: $err')),
            data: (allClients) {
              final filteredClients = _filterClients(allClients);

              // 1. MÉTRICAS GERAIS DA EQUIPE
              final totalClients = filteredClients.length;
              double teamCreditsSold = 0.0;
              double teamNegotiation = 0.0;
              int teamClosedCount = 0;
              Map<String, int> teamSegments = {'Imóvel': 0, 'Automóvel': 0, 'Motocicleta': 0, 'Serviços': 0};

              // 2. AGRUPAMENTO POR VENDEDOR
              Map<String, Map<String, dynamic>> sellerStats = {};

              for (var c in filteredClients) {
                String interest = c['interest'] ?? 'Serviços';
                if (interest == 'Veículos Pesados') interest = 'Automóvel';
                double val = _parseCurrency(c['credit_value'] ?? '');
                String stage = c['stage'] ?? 'Novo Cliente';
                String vid = c['vendedor_id'] ?? 'desconhecido';

                if (!sellerStats.containsKey(vid)) {
                  sellerStats[vid] = {'total_clients': 0, 'closed_count': 0, 'negotiation_count': 0, 'sales_val': 0.0, 'negotiation_val': 0.0, 'segments': <String, int>{}};
                }

                sellerStats[vid]!['total_clients'] += 1;
                Map<String, int> sSegs = sellerStats[vid]!['segments'];
                sSegs[interest] = (sSegs[interest] ?? 0) + 1;

                if (stage == 'Fechado') {
                  teamCreditsSold += val;
                  teamClosedCount++;
                  sellerStats[vid]!['closed_count'] += 1;
                  sellerStats[vid]!['sales_val'] += val;
                } else if (stage == 'Em negociação') {
                  teamNegotiation += val;
                  teamSegments[interest] = (teamSegments[interest] ?? 0) + 1;
                  sellerStats[vid]!['negotiation_count'] += 1;
                  sellerStats[vid]!['negotiation_val'] += val;
                }
              }

              final teamConversion = totalClients == 0 ? 0.0 : (teamClosedCount / totalClients) * 100;
              String teamTopSegment = 'Nenhum';
              int maxSeg = 0;
              teamSegments.forEach((k, v) { if (v > maxSeg) { maxSeg = v; teamTopSegment = k; } });

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeInDown(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Olá ${profile.fullName.split(' ').first},', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5)),
                          const SizedBox(height: 4),
                          const Text('Visão geral da sua equipe...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    FadeIn(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('Mês Atual', 0), const SizedBox(width: 12),
                            _buildFilterChip('Todo o Período', 1), const SizedBox(width: 12),
                            _buildFilterChip('Personalizado', 2),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    GridView.count(
                      crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.90, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                      children: [
                        FadeInUp(delay: const Duration(milliseconds: 100), child: _buildMetricCard(title: 'Créditos Vendidos', value: currencyFormatter.format(teamCreditsSold), subtitle: 'Equipe no período', icon: Icons.verified_rounded, gradientColors: [const Color(0xFF34D399), const Color(0xFF10B981)])),
                        FadeInUp(delay: const Duration(milliseconds: 200), child: _buildMetricCard(title: 'Em Negociação', value: currencyFormatter.format(teamNegotiation), subtitle: 'Pipeline da equipe', icon: Icons.monetization_on_rounded, gradientColors: [const Color(0xFFA78BFA), const Color(0xFF8B5CF6)])),
                        FadeInUp(delay: const Duration(milliseconds: 300), child: _buildMetricCard(title: 'Conversão', value: '${teamConversion.toStringAsFixed(1)}%', subtitle: '$teamClosedCount de $totalClients clientes', icon: Icons.pie_chart_rounded, gradientColors: [const Color(0xFFFBBF24), const Color(0xFFF59E0B)])),
                        FadeInUp(delay: const Duration(milliseconds: 400), child: _buildMetricCard(title: 'Top Segmento', value: teamTopSegment, subtitle: 'Mais procurado', icon: Icons.star_rounded, gradientColors: [const Color(0xFFF472B6), const Color(0xFFEC4899)])),
                      ],
                    ),
                    const SizedBox(height: 40),

                    FadeInUp(
                      delay: const Duration(milliseconds: 500),
                      child: const Text('Desempenho por Vendedor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), letterSpacing: -0.5)),
                    ),
                    const SizedBox(height: 16),

                    membersAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => const Text('Erro ao carregar equipe.'),
                      data: (members) {
                        final sellers = members.where((m) => m['role'] != 'supervisor').toList();
                        
                        if (sellers.isEmpty) {
                          return const Center(child: Text('Nenhum vendedor encontrado na equipe.', style: TextStyle(color: Colors.black54)));
                        }

                        // --- FUNÇÃO PARA FORMATAR O NOME ---
                        String formatSellerName(String fullName) {
                          if (fullName.isEmpty) return 'Vendedor';
                          final parts = fullName.trim().split(RegExp(r'\s+'));
                          if (parts.length == 1) return parts[0];
                          
                          String first = parts[0];
                          String second = parts[1];
                          final connectors = ['da', 'de', 'do', 'das', 'dos'];
                          
                          if (connectors.contains(second.toLowerCase()) && parts.length > 2) {
                            return '$first $second ${parts[2]}';
                          }
                          return '$first $second';
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: sellers.length,
                          itemBuilder: (ctx, index) {
                            final s = sellers[index];
                            final stats = sellerStats[s['id']] ?? {
                              'total_clients': 0, 'closed_count': 0, 'negotiation_count': 0, 'sales_val': 0.0, 'negotiation_val': 0.0, 'segments': <String, int>{}
                            };

                            String sTopSeg = 'Nenhum';
                            int sMax = 0;
                            (stats['segments'] as Map<String, int>).forEach((k, v) { if (v > sMax) { sMax = v; sTopSeg = k; } });

                            double sConversion = stats['total_clients'] == 0 ? 0.0 : (stats['closed_count'] / stats['total_clients']) * 100;

                            return FadeInUp(
                              delay: Duration(milliseconds: 600 + (index * 100)),
                              child: _ExpandableSellerCard(
                                teamId: teamId,
                                sellerId: s['id'],
                                name: formatSellerName(s['full_name'] ?? ''),
                                totalClients: stats['total_clients'],
                                closedCount: stats['closed_count'],
                                salesVal: stats['sales_val'],
                                negCount: stats['negotiation_count'],
                                negVal: stats['negotiation_val'],
                                topSegment: sTopSeg,
                                conversion: sConversion,
                                formatter: currencyFormatter,
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _selectedFilterIndex == index;
    String displayLabel = label;
    if (index == 2 && isSelected && _customStartDate != null && _customEndDate != null) {
      displayLabel = '${DateFormat('dd/MM/yy').format(_customStartDate!)} a ${DateFormat('dd/MM/yy').format(_customEndDate!)}';
    }
    return GestureDetector(
      onTap: () { if (index == 2) { _showCustomDateDialog(context); } else { setState(() => _selectedFilterIndex = index); } },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? const Color(0xFF0F172A) : Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [], border: isSelected ? null : Border.all(color: const Color(0xFFE2E8F0))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (index == 2 && !isSelected) ...[const Icon(Icons.edit_calendar_rounded, size: 14, color: Color(0xFF64748B)), const SizedBox(width: 6)],
            Text(displayLabel, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({required String title, required String value, required String subtitle, required IconData icon, required List<Color> gradientColors}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 5))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: Colors.white, size: 16)),
              const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5))),
          const SizedBox(height: 2), Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// --- COMPONENTE: CARD EXPANSÍVEL DE DESEMPENHO DO VENDEDOR ---
class _ExpandableSellerCard extends StatefulWidget {
  final String teamId;
  final String sellerId;
  final String name;
  final int totalClients;
  final int closedCount;
  final double salesVal;
  final int negCount;
  final double negVal;
  final String topSegment;
  final double conversion;
  final NumberFormat formatter;

  const _ExpandableSellerCard({
    required this.teamId, required this.sellerId, required this.name, 
    required this.totalClients, required this.closedCount, required this.salesVal, 
    required this.negCount, required this.negVal, required this.topSegment, 
    required this.conversion, required this.formatter
  });

  @override
  State<_ExpandableSellerCard> createState() => _ExpandableSellerCardState();
}

class _ExpandableSellerCardState extends State<_ExpandableSellerCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final initial = widget.name.isNotEmpty ? widget.name[0].toUpperCase() : 'V';
    
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut, margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: _isExpanded ? const Color(0xFFF59E0B).withOpacity(0.3) : Colors.transparent, width: 1.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              // --- VERSÃO RESUMIDA ---
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(height: 48, width: 48, decoration: const BoxDecoration(color: Color(0xFFF4F7FE), shape: BoxShape.circle), child: Center(child: Text(initial, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))))),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.3), overflow: TextOverflow.ellipsis),
                          Text('${widget.totalClients} leads no período', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text('${widget.closedCount} fechados', style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
              // --- VERSÃO EXPANDIDA ---
              AnimatedSize(
                duration: const Duration(milliseconds: 300), curve: Curves.easeInOut, alignment: Alignment.topCenter,
                child: _isExpanded
                  ? Container(
                      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1.5),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildMiniMetric(icon: Icons.verified_rounded, label: 'Vendas (R\$)', value: widget.formatter.format(widget.salesVal), color: const Color(0xFF10B981))),
                              Container(width: 1, height: 40, color: const Color(0xFFF1F5F9)),
                              Expanded(child: _buildMiniMetric(icon: Icons.hourglass_top_rounded, label: 'Negociando (${widget.negCount})', value: widget.formatter.format(widget.negVal), color: const Color(0xFF3B82F6))),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(children: [
                                const Icon(Icons.category_rounded, size: 14, color: Color(0xFF94A3B8)), const SizedBox(width: 6),
                                const Text('Forte em: ', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                                Text(widget.topSegment, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              ]),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(8)),
                                child: Row(children: [
                                  const Icon(Icons.pie_chart_rounded, size: 14, color: Color(0xFFF59E0B)), const SizedBox(width: 6),
                                  const Text('Conversão: ', style: TextStyle(fontSize: 11, color: Color(0xFFF59E0B), fontWeight: FontWeight.w600)),
                                  Text('${widget.conversion.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                                ]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => TeamFunnelListScreen(
                                  teamId: widget.teamId, 
                                  category: 'producao', 
                                  title: 'Produção de ${widget.name.split(' ').first}',
                                  initialSellerId: widget.sellerId, 
                                )));
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF8FAFC), 
                                foregroundColor: const Color(0xFF4F46E5), 
                                elevation: 0, 
                                padding: const EdgeInsets.symmetric(vertical: 12), 
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12), 
                                  side: const BorderSide(color: Color(0xFFE2E8F0)), // <--- CORREÇÃO AQUI
                                ),
                              ),
                              icon: const Icon(Icons.folder_shared_rounded, size: 18),
                              label: const Text('Ver Produção do Mês Atual', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          )
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniMetric({required IconData icon, required String label, required String value, required Color color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 12, color: color), const SizedBox(width: 4), Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600))]),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5))),
        ],
      ),
    );
  }
}