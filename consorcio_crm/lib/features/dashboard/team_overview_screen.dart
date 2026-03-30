import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';

import '../auth/profile_provider.dart';
import 'team_funnel_screen.dart'; 

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

// --- PROVEDORES GLOBAIS COM FILTRO EM MEMÓRIA ---
final allTeamsProvider = StreamProvider.autoDispose((ref) => Supabase.instance.client.from('teams').stream(primaryKey: ['id']));
final allProfilesProvider = StreamProvider.autoDispose((ref) => Supabase.instance.client.from('profiles').stream(primaryKey: ['id']));
final allClientsProvider = StreamProvider.autoDispose((ref) => Supabase.instance.client.from('clients').stream(primaryKey: ['id']).order('created_at', ascending: false));

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
            const Text('Filtre a produção:', style: TextStyle(color: Colors.black54, fontSize: 13)),
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

  List<Map<String, dynamic>> _filterClientsByDate(List<Map<String, dynamic>> allClients) {
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

  // FORMATAÇÃO INTELIGENTE DE NOME
  String _formatName(String fullName) {
    if (fullName.isEmpty) return 'Usuário';
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0];
    String first = parts[0]; String second = parts[1];
    final connectors = ['da', 'de', 'do', 'das', 'dos'];
    if (connectors.contains(second.toLowerCase()) && parts.length > 2) return '$first $second ${parts[2]}';
    return '$first $second';
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final teamsAsync = ref.watch(allTeamsProvider);
    final profilesListAsync = ref.watch(allProfilesProvider);
    final clientsAsync = ref.watch(allClientsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, centerTitle: true, title: const Text('Gestão de Equipe', style: TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.bold))),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
        error: (err, stack) => Center(child: Text('Erro: $err')),
        data: (profile) {
          if (profile == null) return const Center(child: Text('Perfil não encontrado.'));

          final role = profile.role ?? 'vendedor';
          
          // Travas de segurança para evitar telas vazias sem necessidade
          if (role == 'supervisor' && profile.teamId == null) return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('Sua conta não está vinculada a nenhuma equipe.', textAlign: TextAlign.center)));
          if (role == 'gerente' && profile.regiao == null) return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('Sua conta não está vinculada a nenhuma região.', textAlign: TextAlign.center)));

          return teamsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
            error: (err, stack) => Center(child: Text('Erro nas equipes: $err')),
            data: (allTeams) {
              
              // 1. FILTRANDO AS EQUIPES VISÍVEIS BASEADO NO CARGO (BLINDADO)
              List<Map<String, dynamic>> validTeams = [];
              if (role == 'diretor' || role == 'administrador') {
                validTeams = allTeams;
              } else if (role == 'gerente') {
                // Remove espaços e transforma tudo em minúsculo para não ter erro de digitação
                final profRegion = profile.regiao?.trim().toLowerCase();
                validTeams = allTeams.where((t) {
                  final teamRegion = t['regiao']?.toString().trim().toLowerCase();
                  return teamRegion != null && profRegion != null && teamRegion == profRegion;
                }).toList();
                
                // Salva-vidas: Se o gerente também tiver uma equipe direta atrelada a ele, inclui ela
                if (profile.teamId != null) {
                  final extraTeams = allTeams.where((t) => t['id'].toString() == profile.teamId.toString());
                  for (var et in extraTeams) {
                    if (!validTeams.any((vt) => vt['id'] == et['id'])) validTeams.add(et);
                  }
                }
              } else {
                // Força a conversão para String para evitar erro de (Int == String)
                validTeams = allTeams.where((t) => t['id'].toString() == profile.teamId.toString()).toList();
              }
              
              final validTeamIds = validTeams.map((t) => t['id'].toString().trim()).toList();

              return profilesListAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
                error: (err, stack) => Center(child: Text('Erro nos perfis: $err')),
                data: (allProfiles) {
                  final validMembers = allProfiles.where((m) {
                  final tId = m['team_id']?.toString().trim();
                  return tId != null && validTeamIds.contains(tId);
                    }).toList();

                  return clientsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
                    error: (err, stack) => Center(child: Text('Erro nos clientes: $err')),
                    data: (allClients) {
                      
                      // FILTRO INTELIGENTE: Pega pela equipe anotada OU pelo vendedor
                      final validSellerIds = validMembers.map((m) => m['id'].toString().trim()).toSet();

                      final validClients = allClients.where((c) {
                      final cTeam = c['team_id']?.toString().trim();
                      final cVend = c['vendedor_id']?.toString().trim();
                  return validTeamIds.contains(cTeam) || validSellerIds.contains(cVend);
                    }).toList();
                      final filteredClients = _filterClientsByDate(validClients);

                      // --- CÁLCULO DAS MÉTRICAS GERAIS ---
                      final totalClients = filteredClients.length;
                      double totalCreditsSold = 0.0;
                      double totalNegotiation = 0.0;
                      int totalClosedCount = 0;
                      Map<String, int> globalSegments = {'Imóvel': 0, 'Automóvel': 0, 'Motocicleta': 0, 'Serviços': 0};

                      // --- DICIONÁRIOS DE ESTATÍSTICAS ---
                      Map<String, Map<String, dynamic>> sellerStats = {};
                      Map<String, Map<String, dynamic>> teamStats = {};

                      // Inicia o dicionário de equipes
                      for (var t in validTeams) {
                        teamStats[t['id'].toString()] = {'name': t['name'], 'regiao': t['regiao'] ?? 'Sem Região', 'total_clients': 0, 'closed_count': 0, 'negotiation_count': 0, 'sales_val': 0.0, 'negotiation_val': 0.0, 'segments': <String, int>{}};
                      }

                      for (var c in filteredClients) {
                        String interest = c['interest'] ?? 'Serviços';
                        if (interest == 'Veículos Pesados') interest = 'Automóvel';
                        double val = _parseCurrency(c['credit_value'] ?? '');
                        String stage = c['stage'] ?? 'Novo Cliente';
                        String vid = c['vendedor_id']?.toString().trim() ?? 'desconhecido';

                        String tid = c['team_id']?.toString().trim() ?? '';
                        if (tid.isEmpty || tid == 'null') {
                        final seller = allProfiles.firstWhere((p) => p['id'].toString().trim() == vid, orElse: () => {});
                        tid = seller['team_id']?.toString().trim() ?? 'desconhecido';
                        }

                        // Estatísticas do Vendedor
                        if (!sellerStats.containsKey(vid)) sellerStats[vid] = {'total_clients': 0, 'closed_count': 0, 'negotiation_count': 0, 'sales_val': 0.0, 'negotiation_val': 0.0, 'segments': <String, int>{}};
                        sellerStats[vid]!['total_clients'] += 1;
                        Map<String, int> sSegs = sellerStats[vid]!['segments'];
                        sSegs[interest] = (sSegs[interest] ?? 0) + 1;

                        // Estatísticas da Equipe
                        if (teamStats.containsKey(tid)) {
                          teamStats[tid]!['total_clients'] += 1;
                          Map<String, int> tSegs = teamStats[tid]!['segments'];
                          tSegs[interest] = (tSegs[interest] ?? 0) + 1;
                        }

                        if (stage == 'Fechado') {
                          totalCreditsSold += val;
                          totalClosedCount++;
                          sellerStats[vid]!['closed_count'] += 1;
                          sellerStats[vid]!['sales_val'] += val;
                          if (teamStats.containsKey(tid)) {
                            teamStats[tid]!['closed_count'] += 1;
                            teamStats[tid]!['sales_val'] += val;
                          }
                        } else if (stage == 'Em negociação') {
                          totalNegotiation += val;
                          globalSegments[interest] = (globalSegments[interest] ?? 0) + 1;
                          sellerStats[vid]!['negotiation_count'] += 1;
                          sellerStats[vid]!['negotiation_val'] += val;
                          if (teamStats.containsKey(tid)) {
                            teamStats[tid]!['negotiation_count'] += 1;
                            teamStats[tid]!['negotiation_val'] += val;
                          }
                        }
                      }

                      final globalConversion = totalClients == 0 ? 0.0 : (totalClosedCount / totalClients) * 100;
                      String topSegment = 'Nenhum'; int maxSeg = 0;
                      globalSegments.forEach((k, v) { if (v > maxSeg) { maxSeg = v; topSegment = k; } });

                      // MENSAGEM DINÂMICA DO CARGO
                      String greetingSub = 'Visão geral da sua equipe...';
                      if (role == 'gerente') greetingSub = 'Essa é a visão geral da sua região (${profile.regiao})...';
                      if (role == 'diretor' || role == 'administrador') greetingSub = 'Visão geral de todas as equipes da empresa...';

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
                                  Text(greetingSub, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Color(0xFF64748B))),
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
                              crossAxisCount: 2, 
                              crossAxisSpacing: 12, 
                              mainAxisSpacing: 12, 
                              childAspectRatio: 1.45, // <--- A proporção compacta aqui
                              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                              children: [
                                FadeInUp(delay: const Duration(milliseconds: 100), child: _buildMetricCard(title: 'Vendidos', value: currencyFormatter.format(totalCreditsSold), subtitle: 'Total no período', icon: Icons.verified_rounded, gradientColors: [const Color(0xFF34D399), const Color(0xFF10B981)])),
                                FadeInUp(delay: const Duration(milliseconds: 200), child: _buildMetricCard(title: 'Negociando', value: currencyFormatter.format(totalNegotiation), subtitle: 'Pipeline atual', icon: Icons.monetization_on_rounded, gradientColors: [const Color(0xFFA78BFA), const Color(0xFF8B5CF6)])),
                                FadeInUp(delay: const Duration(milliseconds: 300), child: _buildMetricCard(title: 'Conversão', value: '${globalConversion.toStringAsFixed(1)}%', subtitle: '$totalClosedCount de $totalClients leads', icon: Icons.pie_chart_rounded, gradientColors: [const Color(0xFFFBBF24), const Color(0xFFF59E0B)])),
                                FadeInUp(delay: const Duration(milliseconds: 400), child: _buildMetricCard(title: 'Destaque', value: topSegment, subtitle: 'Mais procurado', icon: Icons.star_rounded, gradientColors: [const Color(0xFFF472B6), const Color(0xFFEC4899)])),
                              ],
                            ),
                            const SizedBox(height: 40),

                            // --- SEÇÃO: DESEMPENHO POR EQUIPE (Apenas Gerentes e Diretores) ---
                            if (role == 'gerente' || role == 'diretor' || role == 'administrador') ...[
                              FadeInUp(delay: const Duration(milliseconds: 450), child: const Text('Desempenho por Equipe', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), letterSpacing: -0.5))),
                              const SizedBox(height: 16),
                              if (validTeams.isEmpty) const Text('Nenhuma equipe encontrada.', style: TextStyle(color: Colors.black54))
                              else ListView.builder(
                                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: validTeams.length,
                                itemBuilder: (ctx, index) {
                                  final tid = validTeams[index]['id'].toString();
                                  final stats = teamStats[tid]!;
                                  String sTopSeg = 'Nenhum'; int sMax = 0;
                                  (stats['segments'] as Map<String, int>).forEach((k, v) { if (v > sMax) { sMax = v; sTopSeg = k; } });
                                  double sConv = stats['total_clients'] == 0 ? 0.0 : (stats['closed_count'] / stats['total_clients']) * 100;

                                  return FadeInUp(
                                    delay: Duration(milliseconds: 500 + (index * 100)),
                                    child: _ExpandableEntityCard(
                                      id: tid, isTeam: true,
                                      title: stats['name'], subtitle: role == 'diretor' ? 'Região: ${stats['regiao']}' : 'Sua região',
                                      totalClients: stats['total_clients'], closedCount: stats['closed_count'], salesVal: stats['sales_val'], negCount: stats['negotiation_count'], negVal: stats['negotiation_val'], topSegment: sTopSeg, conversion: sConv, formatter: currencyFormatter,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 40),
                            ],

                            // --- SEÇÃO: DESEMPENHO POR VENDEDOR ---
                            FadeInUp(delay: const Duration(milliseconds: 500), child: const Text('Desempenho por Vendedor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), letterSpacing: -0.5))),
                            const SizedBox(height: 16),
                            Builder(
                              builder: (context) {
                                final sellers = validMembers.where((m) => m['role'] != 'supervisor' && m['role'] != 'gerente' && m['role'] != 'diretor').toList();
                                if (sellers.isEmpty) return const Text('Nenhum vendedor encontrado.', style: TextStyle(color: Colors.black54));

                                return ListView.builder(
                                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: sellers.length,
                                  itemBuilder: (ctx, index) {
                                    final s = sellers[index];
                                    final stats = sellerStats[s['id']] ?? {'total_clients': 0, 'closed_count': 0, 'negotiation_count': 0, 'sales_val': 0.0, 'negotiation_val': 0.0, 'segments': <String, int>{}};
                                    
                                    // Puxa o nome da equipe do vendedor para mostrar no subtítulo
                                    final sTeam = validTeams.firstWhere((t) => t['id'].toString() == s['team_id']?.toString(), orElse: () => {'name': 'Sem equipe'});

                                    String sTopSeg = 'Nenhum'; int sMax = 0;
                                    (stats['segments'] as Map<String, int>).forEach((k, v) { if (v > sMax) { sMax = v; sTopSeg = k; } });
                                    double sConv = stats['total_clients'] == 0 ? 0.0 : (stats['closed_count'] / stats['total_clients']) * 100;

                                    return FadeInUp(
                                      delay: Duration(milliseconds: 600 + (index * 100)),
                                      child: _ExpandableEntityCard(
                                        id: s['id'], isTeam: false,
                                        title: _formatName(s['full_name'] ?? ''), subtitle: 'Equipe: ${sTeam['name']}',
                                        totalClients: stats['total_clients'], closedCount: stats['closed_count'], salesVal: stats['sales_val'], negCount: stats['negotiation_count'], negVal: stats['negotiation_val'], topSegment: sTopSeg, conversion: sConv, formatter: currencyFormatter,
                                      ),
                                    );
                                  },
                                );
                              }
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      );
                    }
                  );
                }
              );
            }
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 5))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: Colors.white, size: 14)),
              const SizedBox(width: 8), 
              Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B))))),
            ],
          ),
          const Spacer(),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5))),
          const SizedBox(height: 2), 
          Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// --- COMPONENTE HÍBRIDO: CARD DE DESEMPENHO (EQUIPE E VENDEDOR) ---
class _ExpandableEntityCard extends StatefulWidget {
  final String id;
  final bool isTeam;
  final String title;
  final String subtitle;
  final int totalClients;
  final int closedCount;
  final double salesVal;
  final int negCount;
  final double negVal;
  final String topSegment;
  final double conversion;
  final NumberFormat formatter;

  const _ExpandableEntityCard({required this.id, required this.isTeam, required this.title, required this.subtitle, required this.totalClients, required this.closedCount, required this.salesVal, required this.negCount, required this.negVal, required this.topSegment, required this.conversion, required this.formatter});

  @override
  State<_ExpandableEntityCard> createState() => _ExpandableEntityCardState();
}

class _ExpandableEntityCardState extends State<_ExpandableEntityCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final initial = widget.title.isNotEmpty ? widget.title[0].toUpperCase() : 'E';
    final cardColor = widget.isTeam ? const Color(0xFF0EA5E9) : const Color(0xFF4F46E5);
    
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut, margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: _isExpanded ? cardColor.withOpacity(0.3) : Colors.transparent, width: 1.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(height: 48, width: 48, decoration: BoxDecoration(color: cardColor.withOpacity(0.1), shape: BoxShape.circle), child: Center(child: widget.isTeam ? Icon(Icons.groups_rounded, color: cardColor) : Text(initial, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cardColor)))),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.3), overflow: TextOverflow.ellipsis),
                          Text('${widget.totalClients} leads • ${widget.subtitle}', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text('${widget.closedCount} fechados', style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold))),
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
                                // Envia para o funil filtrando por vendedor ou equipe
                                Navigator.push(context, MaterialPageRoute(builder: (_) => TeamFunnelListScreen(
                                  category: 'producao', 
                                  title: 'Produção: ${widget.title.split(' ').first}',
                                  initialTeamId: widget.isTeam ? widget.id : null,
                                  initialSellerId: !widget.isTeam ? widget.id : null, 
                                )));
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF8FAFC), foregroundColor: cardColor, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0)))),
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