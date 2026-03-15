import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';

import '../auth/profile_provider.dart';

// --- MÁSCARA DE DATA (Reaproveitada para manter o padrão de usabilidade) ---
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

// --- PROVEDORES DE DADOS DA EQUIPE ---
// 1. Puxa todos os clientes que pertencem à equipe do supervisor
final teamClientsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, teamId) {
  return Supabase.instance.client
      .from('clients')
      .stream(primaryKey: ['id'])
      .eq('team_id', teamId)
      .order('created_at', ascending: false);
});

// 2. Puxa todos os perfis (vendedores) que pertencem a essa mesma equipe
final teamMembersProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, teamId) {
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

                // Inicializa o status do vendedor se não existir
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

              // Conversão e Top Segmento da Equipe
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

                    // --- GRID DE MÉTRICAS GERAIS (Igual a Home, mas para a equipe inteira) ---
                    GridView.count(
                      crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.15, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                      children: [
                        FadeInUp(delay: const Duration(milliseconds: 100), child: _buildMetricCard(title: 'Créditos Vendidos', value: currencyFormatter.format(teamCreditsSold), subtitle: 'Equipe no período', icon: Icons.verified_rounded, gradientColors: [const Color(0xFF34D399), const Color(0xFF10B981)])),
                        FadeInUp(delay: const Duration(milliseconds: 200), child: _buildMetricCard(title: 'Em Negociação', value: currencyFormatter.format(teamNegotiation), subtitle: 'Pipeline da equipe', icon: Icons.monetization_on_rounded, gradientColors: [const Color(0xFFA78BFA), const Color(0xFF8B5CF6)])),
                        FadeInUp(delay: const Duration(milliseconds: 300), child: _buildMetricCard(title: 'Conversão', value: '${teamConversion.toStringAsFixed(1)}%', subtitle: '$teamClosedCount de $totalClients clientes', icon: Icons.pie_chart_rounded, gradientColors: [const Color(0xFFFBBF24), const Color(0xFFF59E0B)])),
                        FadeInUp(delay: const Duration(milliseconds: 400), child: _buildMetricCard(title: 'Top Segmento', value: teamTopSegment, subtitle: 'Mais procurado', icon: Icons.star_rounded, gradientColors: [const Color(0xFFF472B6), const Color(0xFFEC4899)])),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // --- RANKING / DESEMPENHO POR VENDEDOR ---
                    FadeInUp(
                      delay: const Duration(milliseconds: 500),
                      child: const Text('Desempenho por Vendedor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), letterSpacing: -0.5)),
                    ),
                    const SizedBox(height: 16),

                    membersAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => const Text('Erro ao carregar equipe.'),
                      data: (members) {
                        // Filtra para mostrar apenas vendedores que têm algum dado no período, ou todos
                        final sellers = members.where((m) => m['role'] != 'supervisor').toList();
                        
                        if (sellers.isEmpty) {
                          return const Center(child: Text('Nenhum vendedor encontrado na equipe.', style: TextStyle(color: Colors.black54)));
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

                            // Top segmento do vendedor
                            String sTopSeg = 'N/A';
                            int sMax = 0;
                            (stats['segments'] as Map<String, int>).forEach((k, v) { if (v > sMax) { sMax = v; sTopSeg = k; } });

                            return FadeInUp(
                              delay: Duration(milliseconds: 600 + (index * 100)),
                              child: _buildSellerCard(
                                name: s['full_name'] ?? 'Vendedor',
                                totalClients: stats['total_clients'],
                                closedCount: stats['closed_count'],
                                salesVal: stats['sales_val'],
                                negCount: stats['negotiation_count'],
                                negVal: stats['negotiation_val'],
                                topSegment: sTopSeg,
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

  // --- CARD EXCLUSIVO PARA O RAIO-X DO VENDEDOR ---
  Widget _buildSellerCard({required String name, required int totalClients, required int closedCount, required double salesVal, required int negCount, required double negVal, required String topSegment, required NumberFormat formatter}) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'V';
    return Container(
      margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))]),
      child: Column(
        children: [
          // Cabeçalho: Foto, Nome e Status
          Row(
            children: [
              Container(height: 48, width: 48, decoration: const BoxDecoration(color: Color(0xFFF4F7FE), shape: BoxShape.circle), child: Center(child: Text(initial, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))))),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.3), overflow: TextOverflow.ellipsis),
                    Text('$totalClients leads cadastrados', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text('$closedCount fechados', style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold))),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1.5)),
          // Linha de Métricas Financeiras
          Row(
            children: [
              Expanded(child: _buildMiniMetric(icon: Icons.verified_rounded, label: 'Vendas (R\$)', value: formatter.format(salesVal), color: const Color(0xFF10B981))),
              Container(width: 1, height: 40, color: const Color(0xFFF1F5F9)),
              Expanded(child: _buildMiniMetric(icon: Icons.hourglass_top_rounded, label: 'Negociando ($negCount)', value: formatter.format(negVal), color: const Color(0xFF3B82F6))),
            ],
          ),
          const SizedBox(height: 12),
          // Linha de Segmento
          Row(
            children: [
              Icon(Icons.category_rounded, size: 14, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text('Forte em: ', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              Text(topSegment, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ],
          )
        ],
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