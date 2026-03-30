import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;

import '../auth/profile_provider.dart';
import '../client_manage/add_team_client_screen.dart';
// Importa os provedores globais do arquivo anterior para usarmos a mesma base de dados em memória
import 'team_overview_screen.dart' show allTeamsProvider, allProfilesProvider, allClientsProvider;

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

// ------------------------------------------------------------------------
// TELA 1: O HUB DO FUNIL GERAL
// ------------------------------------------------------------------------
class TeamFunnelScreen extends ConsumerStatefulWidget {
  const TeamFunnelScreen({super.key});
  @override
  ConsumerState<TeamFunnelScreen> createState() => _TeamFunnelScreenState();
}

class _TeamFunnelScreenState extends ConsumerState<TeamFunnelScreen> {
  int _selectedFilterIndex = 0; 
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
            const Text('Filtre o funil:', style: TextStyle(color: Colors.black54, fontSize: 13)),
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

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final teamsAsync = ref.watch(allTeamsProvider);
    final clientsAsync = ref.watch(allClientsProvider);
    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    
    String currentMonthName = DateFormat('MMMM', 'pt_BR').format(DateTime.now());
    currentMonthName = currentMonthName[0].toUpperCase() + currentMonthName.substring(1);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0, centerTitle: true,
        title: const Text('Funil Geral', style: TextStyle(color: Color(0xFF1E293B), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
      ),
      floatingActionButton: profileAsync.whenData((p) {
        // Oculta o FAB se for Gerente/Diretor (que não têm equipe vinculada diretamente)
        if (p?.teamId != null && p?.role == 'supervisor') {
          return FloatingActionButton.extended(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddTeamClientScreen(teamId: p!.teamId!))),
            backgroundColor: const Color(0xFFF59E0B), elevation: 4,
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            label: const Text('Novo Cliente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          );
        }
        return const SizedBox.shrink();
      }).value ?? const SizedBox.shrink(),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
        error: (err, stack) => Center(child: Text('Erro: $err')),
        data: (profile) {
          if (profile == null) return const Center(child: Text('Perfil não encontrado.'));
          final role = profile.role ?? 'vendedor';

          return teamsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
            error: (err, stack) => Center(child: Text('Erro: $err')),
            data: (allTeams) {
              
              List<Map<String, dynamic>> validTeams = [];
              if (role == 'diretor' || role == 'administrador') {
                validTeams = allTeams;
              } else if (role == 'gerente') {
                final profRegion = profile.regiao?.trim().toLowerCase();
                validTeams = allTeams.where((t) {
                  final teamRegion = t['regiao']?.toString().trim().toLowerCase();
                  return teamRegion != null && profRegion != null && teamRegion == profRegion;
                }).toList();
                
                if (profile.teamId != null) {
                  final extraTeams = allTeams.where((t) => t['id'].toString() == profile.teamId.toString());
                  for (var et in extraTeams) {
                    if (!validTeams.any((vt) => vt['id'] == et['id'])) validTeams.add(et);
                  }
                }
              } else {
                validTeams = allTeams.where((t) => t['id'].toString() == profile.teamId.toString()).toList();
              }
              
              // --- ESSA FOI A LINHA QUE EU TINHA ESQUECIDO DE TE PASSAR! ---
              final validTeamIds = validTeams.map((t) => t['id'].toString()).toList();
              // -------------------------------------------------------------

              // ADICIONAMOS A LEITURA DE PERFIS AQUI PARA DESCOBRIR A EQUIPE DO VENDEDOR
              final profilesListAsync = ref.watch(allProfilesProvider);
              
              return profilesListAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
                error: (err, stack) => Center(child: Text('Erro: $err')),
                data: (allProfiles) {
                  final validSellerIds = allProfiles
                      .where((m) => validTeamIds.contains(m['team_id']?.toString()))
                      .map((m) => m['id'].toString())
                      .toSet();

                  return clientsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
                    error: (err, stack) => Center(child: Text('Erro: $err')),
                    data: (allClients) {
                      final now = DateTime.now();
                      double totalProducao = 0, totalCarteira = 0, totalFechados = 0, totalDesistentes = 0;
                      int countProducao = 0, countCarteira = 0, countFechados = 0, countDesistentes = 0;

                      // FILTRO INTELIGENTE APLICADO!
                      final validClients = allClients.where((c) {
                        final cTeam = c['team_id']?.toString();
                        final cVend = c['vendedor_id']?.toString();
                        return validTeamIds.contains(cTeam) || validSellerIds.contains(cVend);
                      }).toList();

                      for (var c in validClients) {
                        final createdAt = DateTime.parse(c['created_at']);
                        final isCurrentMonth = createdAt.year == now.year && createdAt.month == now.month;
                        final val = _parseCurrency(c['credit_value'] ?? '');
                        final stage = c['stage'] ?? 'Novo Cliente';

                        if (isCurrentMonth && stage != 'Fechado' && stage != 'Desistente') {
                          totalProducao += val; countProducao++;
                        }

                        bool passesDateFilter = false;
                        if (_selectedFilterIndex == 1) passesDateFilter = true; 
                        else if (_selectedFilterIndex == 0) passesDateFilter = isCurrentMonth; 
                        else if (_selectedFilterIndex == 2 && _customStartDate != null && _customEndDate != null) {
                          passesDateFilter = createdAt.isAfter(_customStartDate!.subtract(const Duration(seconds: 1))) && createdAt.isBefore(_customEndDate!.add(const Duration(seconds: 1)));
                        }

                        if (!passesDateFilter) continue; 

                        if (stage == 'Fechado') { totalFechados += val; countFechados++; } 
                        else if (stage == 'Desistente') { totalDesistentes += val; countDesistentes++; } 
                        else if (!isCurrentMonth && stage != 'Fechado' && stage != 'Desistente') { totalCarteira += val; countCarteira++; }
                      }

                      return ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                        children: [
                          FadeInDown(child: const Text('Selecione a Gaveta', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                          const SizedBox(height: 16),
                          FadeIn(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [ _buildFilterChip('Mês Atual', 0), const SizedBox(width: 12), _buildFilterChip('Todo o Período', 1), const SizedBox(width: 12), _buildFilterChip('Personalizado', 2) ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FadeInUp(delay: const Duration(milliseconds: 100), child: _buildHubCard(context, 'Produção de $currentMonthName', 'Prospecções do mês', totalProducao, countProducao, currencyFormatter, 'producao', const Color(0xFFF59E0B), Icons.calendar_month_rounded)),
                          const SizedBox(height: 16),
                          FadeInUp(delay: const Duration(milliseconds: 200), child: _buildHubCard(context, 'Carteira de Negociação', 'Pendências de meses anteriores', totalCarteira, countCarteira, currencyFormatter, 'carteira', const Color(0xFF0EA5E9), Icons.hourglass_top_rounded)),
                          const SizedBox(height: 16),
                          FadeInUp(delay: const Duration(milliseconds: 300), child: _buildHubCard(context, 'Contratos Fechados', 'Histórico de sucessos', totalFechados, countFechados, currencyFormatter, 'fechados', const Color(0xFF10B981), Icons.handshake_rounded)),
                          const SizedBox(height: 16),
                          FadeInUp(delay: const Duration(milliseconds: 400), child: _buildHubCard(context, 'Desistentes / Excluídos', 'Oportunidades perdidas', totalDesistentes, countDesistentes, currencyFormatter, 'desistentes', const Color(0xFFEF4444), Icons.delete_sweep_rounded)),
                        ],
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

  Widget _buildHubCard(BuildContext context, String title, String subtitle, double total, int count, NumberFormat formatter, String category, Color color, IconData icon) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TeamFunnelListScreen(category: category, title: title))),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))]),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 28)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.3)), Text('$count clientes ativos', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))), const SizedBox(height: 8), Text(formatter.format(total), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5))])),
            const Icon(Icons.chevron_right_rounded, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------
// TELA 2: LISTA DE CLIENTES COM FILTROS DE DIRETOR/GERENTE
// ------------------------------------------------------------------------
class TeamFunnelListScreen extends ConsumerStatefulWidget {
  final String category;
  final String title;
  final String? initialTeamId; 
  final String? initialSellerId; 

  const TeamFunnelListScreen({super.key, required this.category, required this.title, this.initialTeamId, this.initialSellerId});

  @override
  ConsumerState<TeamFunnelListScreen> createState() => _TeamFunnelListScreenState();
}

class _TeamFunnelListScreenState extends ConsumerState<TeamFunnelListScreen> {
  bool _isSearching = false;
  String _searchQuery = '';
  
  int _dateFilterIndex = 1; 
  DateTime? _startDate;
  DateTime? _endDate;

  String? _selectedStage; 
  String? _selectedSegment; 
  
  // Novos Filtros
  String? _selectedRegionFilter; 
  String? _selectedTeamFilter;
  String? _selectedSellerFilter; 

  final TextEditingController _searchController = TextEditingController();
  final List<String> _stages = ['Novo Cliente', 'Em negociação', 'Cadastrado'];
  final List<String> _segments = ['Imóvel', 'Automóvel', 'Motocicleta', 'Serviços'];

  @override
  void initState() {
    super.initState();
    _selectedTeamFilter = widget.initialTeamId;
    _selectedSellerFilter = widget.initialSellerId; 
  }

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  void _showCustomDateDialog() {
    final startCtrl = TextEditingController(text: _startDate != null ? DateFormat('dd/MM/yyyy').format(_startDate!) : '');
    final endCtrl = TextEditingController(text: _endDate != null ? DateFormat('dd/MM/yyyy').format(_endDate!) : '');

    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Período Personalizado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A), letterSpacing: -0.5)),
        content: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: startCtrl, keyboardType: TextInputType.number, inputFormatters: [DateTextFormatter()], decoration: InputDecoration(labelText: 'Data Inicial', hintText: 'DD/MM/AAAA', filled: true, fillColor: const Color(0xFFF4F7FE), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF4F46E5)))),
            const SizedBox(height: 12),
            TextField(controller: endCtrl, keyboardType: TextInputType.number, inputFormatters: [DateTextFormatter()], decoration: InputDecoration(labelText: 'Data Final', hintText: 'DD/MM/AAAA', filled: true, fillColor: const Color(0xFFF4F7FE), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), prefixIcon: const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF4F46E5)))),
          ],
        ),
        actions: [
          TextButton(onPressed: () { Navigator.pop(ctx); if (_startDate == null) setState(() => _dateFilterIndex = 1); }, child: const Text('Cancelar', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              try {
                final start = DateFormat('dd/MM/yyyy').parseStrict(startCtrl.text);
                final end = DateFormat('dd/MM/yyyy').parseStrict(endCtrl.text).add(const Duration(hours: 23, minutes: 59, seconds: 59));
                if (start.isAfter(end)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data inicial maior que a final.'))); return; }
                setState(() { _startDate = start; _endDate = end; _dateFilterIndex = 2; });
                Navigator.pop(ctx);
              } catch (e) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datas inválidas.'))); }
            },
            child: const Text('Aplicar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      )
    );
  }

  void _showAdvancedFilters(String userRole, List<Map<String, dynamic>> validTeams, List<Map<String, dynamic>> validSellers) {
    // Extrair regiões únicas se for Diretor
    List<String> uniqueRegions = [];
    if (userRole == 'diretor' || userRole == 'administrador') {
      uniqueRegions = validTeams.map((t) => t['regiao'].toString()).toSet().where((r) => r != 'null').toList();
    }

    // Filtrar Equipes baseado na Região selecionada (Cascata)
    List<Map<String, dynamic>> dropdownTeams = validTeams;
    if (_selectedRegionFilter != null) dropdownTeams = validTeams.where((t) => t['regiao'] == _selectedRegionFilter).toList();

    // Filtrar Vendedores baseado na Equipe selecionada (Cascata)
    List<Map<String, dynamic>> dropdownSellers = validSellers;
    if (_selectedTeamFilter != null) dropdownSellers = validSellers.where((s) => s['team_id']?.toString() == _selectedTeamFilter).toList();

    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.category != 'producao') ...[
                const Text('Filtrar por Período', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [ _buildDateFilterChip('Mês Atual', 0, ctx), const SizedBox(width: 8), _buildDateFilterChip('Todo o Período', 1, ctx), const SizedBox(width: 8), _buildDateFilterChip('Personalizado', 2, ctx) ],
                  ),
                ),
                const Divider(height: 32),
              ],

              // Filtro de Região (Apenas Diretor)
              if (userRole == 'diretor' || userRole == 'administrador') ...[
                const Text('Filtrar por Região', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: uniqueRegions.map((r) => ChoiceChip(
                    label: Text(r, style: TextStyle(color: _selectedRegionFilter == r ? Colors.white : Colors.black87)),
                    selected: _selectedRegionFilter == r, selectedColor: const Color(0xFF0EA5E9),
                    onSelected: (val) { setState(() { _selectedRegionFilter = val ? r : null; _selectedTeamFilter = null; _selectedSellerFilter = null; }); Navigator.pop(ctx); _showAdvancedFilters(userRole, validTeams, validSellers); },
                  )).toList(),
                ),
                const Divider(height: 32),
              ],

              // Filtro de Equipe (Gerente e Diretor)
              if (userRole != 'supervisor') ...[
                const Text('Filtrar por Equipe', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: dropdownTeams.map((t) => ChoiceChip(
                    label: Text(t['name'], style: TextStyle(color: _selectedTeamFilter == t['id'].toString() ? Colors.white : Colors.black87)),
                    selected: _selectedTeamFilter == t['id'].toString(), selectedColor: const Color(0xFF8B5CF6),
                    onSelected: (val) { setState(() { _selectedTeamFilter = val ? t['id'].toString() : null; _selectedSellerFilter = null; }); Navigator.pop(ctx); _showAdvancedFilters(userRole, validTeams, validSellers); },
                  )).toList(),
                ),
                const Divider(height: 32),
              ],

              const Text('Filtrar por Vendedor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: dropdownSellers.map((s) => ChoiceChip(
                  label: Text(s['full_name'].split(' ').first, style: TextStyle(color: _selectedSellerFilter == s['id'] ? Colors.white : Colors.black87)),
                  selected: _selectedSellerFilter == s['id'], selectedColor: const Color(0xFFF59E0B),
                  onSelected: (val) { setState(() { _selectedSellerFilter = val ? s['id'] : null; }); Navigator.pop(ctx); },
                )).toList(),
              ),
              const Divider(height: 32),
              
              const Text('Filtrar por Segmento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 12),
              ..._segments.map((seg) => _buildSegmentOption(seg)).toList(),
              const Divider(height: 32),
              
              ListTile(
                onTap: () { setState(() { _selectedSegment = null; _selectedRegionFilter = null; _selectedTeamFilter = null; _selectedSellerFilter = null; _dateFilterIndex = 1; }); Navigator.pop(context); },
                leading: const Icon(Icons.clear_all_rounded, color: Colors.redAccent),
                title: const Text('Limpar Todos os Filtros', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateFilterChip(String label, int index, BuildContext ctx) {
    final isSelected = _dateFilterIndex == index;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
      selected: isSelected, selectedColor: const Color(0xFFF59E0B), backgroundColor: const Color(0xFFF1F5F9),
      onSelected: (val) { Navigator.pop(ctx); if (index == 2) { _showCustomDateDialog(); } else { setState(() => _dateFilterIndex = index); } },
    );
  }

  Widget _buildSegmentOption(String label) {
    String prefix = '';
    if (label == 'Imóvel') prefix = '🏠'; if (label == 'Automóvel') prefix = '🚗'; if (label == 'Motocicleta') prefix = '🏍️'; if (label == 'Serviços') prefix = '💎';
    final isSelected = _selectedSegment == label;
    return ListTile(
      onTap: () { setState(() => _selectedSegment = label); Navigator.pop(context); },
      leading: Text(prefix, style: const TextStyle(fontSize: 20)),
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF1E293B))),
      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFFF59E0B)) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final teamsAsync = ref.watch(allTeamsProvider);
    final profilesListAsync = ref.watch(allProfilesProvider);
    final clientsAsync = ref.watch(allClientsProvider);

    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final bool isFilteredCategory = widget.category == 'producao' || widget.category == 'carteira';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, elevation: 0, 
        titleSpacing: _isSearching ? 0 : NavigationToolbar.kMiddleSpacing,
        title: _isSearching
            ? TextField(
                controller: _searchController, autofocus: true, style: const TextStyle(color: Colors.white),
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: const InputDecoration(hintText: 'Buscar por lead...', hintStyle: TextStyle(color: Colors.white54, fontSize: 15), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16)),
              )
            : Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        actions: [
          IconButton(icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded), onPressed: () { setState(() { _isSearching = !_isSearching; if (!_isSearching) { _searchQuery = ''; _searchController.clear(); } }); }),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
        error: (err, stack) => Center(child: Text('Erro: $err')),
        data: (profile) {
          if (profile == null) return const SizedBox.shrink();
          final role = profile.role ?? 'vendedor';

          return teamsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
            error: (err, stack) => Center(child: Text('Erro: $err')),
            data: (allTeams) {
              List<Map<String, dynamic>> validTeams = [];
              if (role == 'diretor' || role == 'administrador') {
                validTeams = allTeams;
              } else if (role == 'gerente') {
                final profRegion = profile.regiao?.trim().toLowerCase();
                validTeams = allTeams.where((t) {
                  final teamRegion = t['regiao']?.toString().trim().toLowerCase();
                  return teamRegion != null && profRegion != null && teamRegion == profRegion;
                }).toList();
                
                if (profile.teamId != null) {
                  final extraTeams = allTeams.where((t) => t['id'].toString() == profile.teamId.toString());
                  for (var et in extraTeams) {
                    if (!validTeams.any((vt) => vt['id'] == et['id'])) validTeams.add(et);
                  }
                }
              } else {
                validTeams = allTeams.where((t) => t['id'].toString() == profile.teamId.toString()).toList();
              }
              
              // --- ESSA FOI A LINHA QUE EU TINHA ESQUECIDO DE TE PASSAR! ---
              final validTeamIds = validTeams.map((t) => t['id'].toString()).toList();
              // -------------------------------------------------------------

              return profilesListAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
                error: (err, stack) => Center(child: Text('Erro: $err')),
                data: (allProfiles) {
                  final validSellers = allProfiles.where((m) => validTeamIds.contains(m['team_id']?.toString()) && m['role'] != 'supervisor' && m['role'] != 'gerente').toList();
                  
                  // Botão de Filtro Flutuante com nome dinâmico
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      String btnLabel = 'Filtros';
                      if (_selectedSellerFilter != null) btnLabel = '1 Vendedor';
                      else if (_selectedTeamFilter != null) btnLabel = '1 Equipe';
                      else if (_selectedRegionFilter != null) btnLabel = '1 Região';
                      else if (_selectedSegment != null) btnLabel = _selectedSegment!;

                      // Injeta o FAB dinamicamente após construir a árvore
                      ScaffoldMessenger.of(context).hideCurrentSnackBar(); 
                    }
                  });

                  return Scaffold(
                    backgroundColor: Colors.transparent,
                    floatingActionButton: FloatingActionButton.extended(
                      onPressed: () => _showAdvancedFilters(role, validTeams, validSellers),
                      backgroundColor: const Color(0xFF0F172A), elevation: 4,
                      icon: const Icon(Icons.filter_alt_rounded, color: Colors.white, size: 18),
                      label: const Text('Filtros', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)), // Texto estático no FAB interno
                    ),
                    body: clientsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
                      error: (err, stack) => Center(child: Text('Erro: $err')),
                      data: (allClients) {
                        final now = DateTime.now();
                        Map<String, String> sellerNames = {};
                        for (var m in allProfiles) sellerNames[m['id']] = m['full_name'] ?? 'Desconhecido';

                        // FILTRO INTELIGENTE APLICADO NA TELA DE LISTAGEM!
                        final validSellerIds = validSellers.map((m) => m['id'].toString()).toSet();
                        final validClients = allClients.where((c) {
                          final cTeam = c['team_id']?.toString();
                          final cVend = c['vendedor_id']?.toString();
                          return validTeamIds.contains(cTeam) || validSellerIds.contains(cVend);
                        }).toList();

                        final filteredClients = validClients.where((c) {
                          final createdAt = DateTime.parse(c['created_at']);
                          final isCurrentMonth = createdAt.year == now.year && createdAt.month == now.month;
                          final stage = c['stage'] ?? 'Novo Cliente';
                          final interest = c['interest'] ?? 'Serviços';
                          final name = (c['name'] ?? '').toString().toLowerCase();
                          final vid = c['vendedor_id'];
                          String? tid = c['team_id']?.toString();
                          if (tid == null || tid == 'null' || tid.isEmpty) {
                            final seller = allProfiles.firstWhere((p) => p['id'].toString() == vid, orElse: () => {});
                            tid = seller['team_id']?.toString();
                          }
                          
                          // Descobre a região da equipe desse cliente
                          final cTeam = validTeams.firstWhere((t) => t['id'].toString() == tid, orElse: () => {});
                          final cRegion = cTeam['regiao']?.toString();

                          // 1. FILTRO DE DATA
                          bool matchesDate = false;
                          if (widget.category == 'producao') matchesDate = true; 
                          else {
                            if (_dateFilterIndex == 1) matchesDate = true;
                            else if (_dateFilterIndex == 0) matchesDate = isCurrentMonth;
                            else if (_dateFilterIndex == 2 && _startDate != null && _endDate != null) {
                              matchesDate = createdAt.isAfter(_startDate!.subtract(const Duration(seconds: 1))) && createdAt.isBefore(_endDate!.add(const Duration(seconds: 1)));
                            }
                          }
                          if (!matchesDate) return false;

                          // 2. FILTRO DE GAVETA (Categoria)
                          bool matchesCategory = false;
                          if (widget.category == 'fechados') matchesCategory = stage == 'Fechado';
                          else if (widget.category == 'desistentes') matchesCategory = stage == 'Desistente';
                          else if (widget.category == 'producao') matchesCategory = isCurrentMonth && stage != 'Fechado' && stage != 'Desistente';
                          else if (widget.category == 'carteira') matchesCategory = !isCurrentMonth && stage != 'Fechado' && stage != 'Desistente';
                          if (!matchesCategory) return false;

                          // 3. FILTROS DA TELA (Pesquisa, Fase, Hierarquia)
                          if (_searchQuery.isNotEmpty && !name.contains(_searchQuery.toLowerCase())) return false;
                          if (isFilteredCategory && _selectedStage != null && stage != _selectedStage) return false;
                          
                          if (_selectedRegionFilter != null && cRegion != _selectedRegionFilter) return false;
                          if (_selectedTeamFilter != null && tid != _selectedTeamFilter) return false;
                          if (_selectedSellerFilter != null && vid != _selectedSellerFilter) return false;
                          
                          if (_selectedSegment != null) {
                            String mappedInterest = interest;
                            if (interest.contains('Veículos')) mappedInterest = 'Automóvel';
                            if (mappedInterest != _selectedSegment) return false;
                          }
                          return true;
                        }).toList();

                        filteredClients.sort((a, b) => DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));

                        return Column(
                          children: [
                            if (isFilteredCategory)
                              Container(
                                color: Colors.white,
                                child: Row(
                                  children: _stages.map((stage) {
                                    final isSelected = _selectedStage == stage;
                                    return Expanded(
                                      child: GestureDetector(
                                        onTap: () { setState(() { _selectedStage = isSelected ? null : stage; }); },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isSelected ? const Color(0xFFF59E0B) : Colors.transparent, width: 3))),
                                          child: Text(stage, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8))),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            
                            Expanded(
                              child: filteredClients.isEmpty 
                                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.inbox_rounded, size: 64, color: Color(0xFFCBD5E1)), const SizedBox(height: 16), Text(_selectedStage != null ? 'Nenhum lead em "$_selectedStage"' : 'Nenhum lead encontrado.', style: const TextStyle(color: Colors.black54, fontSize: 15))]))
                                : ListView.builder(
                                    padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 80),
                                    itemCount: filteredClients.length,
                                    itemBuilder: (context, index) {
                                      final client = filteredClients[index];
                                      final sellerFullName = sellerNames[client['vendedor_id']] ?? 'Equipe';
                                      final sellerFirstName = sellerFullName.split(' ').first;

                                      return FadeInUp(
                                        duration: const Duration(milliseconds: 300),
                                        child: _ExpandableTeamClientCard(client: client, currencyFormatter: currencyFormatter, sellerFirstName: sellerFirstName),
                                      );
                                    },
                                  ),
                            ),
                          ],
                        );
                      }
                    )
                  );
                }
              );
            }
          );
        }
      )
    );
  }
}

// ------------------------------------------------------------------------
// COMPONENTE: CARD COM BADGE DO VENDEDOR
// ------------------------------------------------------------------------
class _ExpandableTeamClientCard extends StatefulWidget {
  final Map<String, dynamic> client;
  final NumberFormat currencyFormatter;
  final String sellerFirstName;
  const _ExpandableTeamClientCard({required this.client, required this.currencyFormatter, required this.sellerFirstName});

  @override
  State<_ExpandableTeamClientCard> createState() => _ExpandableTeamClientCardState();
}

class _ExpandableTeamClientCardState extends State<_ExpandableTeamClientCard> {
  bool _isExpanded = false;
  final TextEditingController _msgController = TextEditingController();

  // --- FUNÇÃO DE LOG PARA A TELA DO GESTOR ---
  Future<void> _logActivity(String actionType, String description) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    
    // Identifica que quem está fazendo a ação é um perfil de Gestão
    String actionUserName = 'Gestão'; 
    try {
      final prof = await Supabase.instance.client.from('profiles').select('full_name').eq('id', userId).maybeSingle();
      if (prof != null && prof['full_name'] != null) actionUserName = prof['full_name'];
    } catch(e) {}

    await Supabase.instance.client.from('activity_logs').insert({
      'vendedor_id': userId,
      'vendedor_nome': actionUserName, // Registra o nome do Gestor que editou
      'client_id': widget.client['id'],
      'client_nome': widget.client['name'],
      'action_type': actionType,
      'description': description,
    });
  }

  @override
  void dispose() { _msgController.dispose(); super.dispose(); }

  Future<void> _executeAction(String actionType, String rawPhone) async {
    final phone = rawPhone.replaceAll(RegExp(r'\D'), '');
    final finalPhone = (phone.length == 10 || phone.length == 11) ? '55$phone' : phone;
    Uri url = actionType == 'whatsapp' ? Uri.parse('https://wa.me/$finalPhone?text=Olá') : Uri.parse('tel:$phone');
    try { await launchUrl(url, mode: LaunchMode.externalApplication); } catch (e) {}
  }

  Future<void> _sendSupervisorMessage() async {
    if (_msgController.text.trim().isEmpty) return;
    final String text = _msgController.text.trim();
    final List<dynamic> currentHistory = widget.client['chat_history'] != null ? List<dynamic>.from(widget.client['chat_history']) : [];

    currentHistory.add({'sender': 'supervisor', 'text': text, 'timestamp': DateTime.now().toIso8601String()});

    await Supabase.instance.client.from('clients').update({
      'chat_history': currentHistory,
      'is_help_mode': true, 
      'unread_vendedor': (widget.client['unread_vendedor'] ?? 0) + 1,
    }).eq('id', widget.client['id']);
    
    if (mounted) { _msgController.clear(); FocusScope.of(context).unfocus(); }
  }

  Future<void> _toggleHelpOff() async {
    await Supabase.instance.client.from('clients').update({
      'is_help_mode': false,
      'phone_released': false, 
    }).eq('id', widget.client['id']);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Acompanhamento encerrado.'), backgroundColor: Colors.black54));
  }

  // --- NOVA FUNÇÃO: DIÁLOGO DE EDIÇÃO DO GESTOR ---
  Future<void> _showEditDialog() async {
    final nameCtrl = TextEditingController(text: widget.client['name']);
    final phoneCtrl = TextEditingController(text: widget.client['phone']);
    final creditCtrl = TextEditingController(text: widget.client['credit_value']?.toString());
    final infoCtrl = TextEditingController(text: widget.client['additional_info']);
    
    String selectedInterest = widget.client['interest'] ?? 'Imóvel';
    String selectedCapture = widget.client['capture_type'] ?? 'Indicação';
    String selectedPlan = widget.client['plan_type'] ?? 'Normal';

    final interests = ['Imóvel', 'Automóvel', 'Motocicleta', 'Serviços'];
    final captureTypes = ['Indicação', 'Visitas Externas', 'Leads da Empresa', 'Leads Próprios', 'Redes Sociais', 'P.A.P', 'Ação de Vendas'];
    final planTypes = ['Normal', 'Light', 'Superlight'];

    if (!interests.contains(selectedInterest)) selectedInterest = 'Imóvel';
    if (!captureTypes.contains(selectedCapture)) selectedCapture = 'Indicação';
    if (!planTypes.contains(selectedPlan)) selectedPlan = 'Normal';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Editar Lead', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildEditInput(controller: nameCtrl, label: 'Nome'),
                  const SizedBox(height: 12),
                  _buildEditInput(controller: phoneCtrl, label: 'Telefone', isPhone: true),
                  const SizedBox(height: 12),
                  _buildEditInput(controller: creditCtrl, label: 'Valor do Crédito', isCurrency: true),
                  const SizedBox(height: 12),
                  _buildEditDropdown('Produto', selectedInterest, interests, (v) => setDialogState(() => selectedInterest = v!)),
                  const SizedBox(height: 12),
                  _buildEditDropdown('Plano', selectedPlan, planTypes, (v) => setDialogState(() => selectedPlan = v!)),
                  const SizedBox(height: 12),
                  _buildEditDropdown('Captação', selectedCapture, captureTypes, (v) => setDialogState(() => selectedCapture = v!)),
                  const SizedBox(height: 12),
                  _buildEditInput(controller: infoCtrl, label: 'Anotações', maxLines: 2),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx), 
                child: const Text('Cancelar', style: TextStyle(color: Colors.black54))
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () async {
                  
                  List<String> changes = [];
                  if (nameCtrl.text.trim() != (widget.client['name'] ?? '')) changes.add('Nome');
                  if (phoneCtrl.text.trim() != (widget.client['phone'] ?? '')) changes.add('Telefone');
                  
                  if (creditCtrl.text.trim() != (widget.client['credit_value']?.toString() ?? '')) {
                    changes.add('Crédito (para ${_safeCurrency(creditCtrl.text.trim())})');
                  }
                  if (selectedInterest != (widget.client['interest'] ?? 'Imóvel')) changes.add('Produto (para $selectedInterest)');
                  if (selectedPlan != (widget.client['plan_type'] ?? 'Normal')) changes.add('Plano (para $selectedPlan)');
                  if (selectedCapture != (widget.client['capture_type'] ?? 'Indicação')) changes.add('Captação (para $selectedCapture)');
                  
                  // --- MUDANÇA AQUI: Mostra o texto exato da nova anotação ---
                  if (infoCtrl.text.trim() != (widget.client['additional_info'] ?? '')) {
                    final novaAnotacao = infoCtrl.text.trim().isEmpty ? "Vazia" : infoCtrl.text.trim();
                    changes.add('Anotações (para: "$novaAnotacao")');
                  }

                  // 1. SALVA NO BANCO
                  await Supabase.instance.client.from('clients').update({
                    'name': nameCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'credit_value': creditCtrl.text.trim(),
                    'interest': selectedInterest,
                    'capture_type': selectedCapture,
                    'plan_type': selectedPlan,
                    'additional_info': infoCtrl.text.trim(),
                  }).eq('id', widget.client['id']);
                  
                  // 2. REGISTRA O LOG APENAS SE HOUVE MUDANÇA (Isso impede logs duplicados e vazios!)
                  if (changes.isNotEmpty) {
                    String logDesc = 'Alterou: ${changes.join(', ')}.';
                    await _logActivity('EDIT', logDesc);
                  }
                  
                  if (mounted) Navigator.pop(ctx);
                },
                child: const Text('Salvar', style: TextStyle(color: Colors.white)),
              )
            ],
          );
        }
      ),
    );
  }

  Widget _buildEditInput({required TextEditingController controller, required String label, bool isPhone = false, bool isCurrency = false, int maxLines = 1}) {
    List<TextInputFormatter> formatters = [];
    if (isPhone) formatters.add(PhoneInputFormatter());
    if (isCurrency) formatters.add(CurrencyInputFormatter());
    return TextFormField(
      controller: controller, maxLines: maxLines,
      keyboardType: isPhone || isCurrency ? TextInputType.number : TextInputType.text,
      inputFormatters: formatters,
      decoration: InputDecoration(labelText: label, filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
    );
  }

  Widget _buildEditDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      isExpanded: true, value: value,
      decoration: InputDecoration(labelText: label, filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
      items: items.map((v) => DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis))).toList(), onChanged: onChanged,
    );
  }

  String _safePhone(String? phone) {
    if (phone == null || phone.isEmpty) return 'Sem telefone';
    if (phone.contains('(')) return phone;
    final t = phone.replaceAll(RegExp(r'\D'), '');
    if (t.length == 11) return '(${t.substring(0, 2)}) ${t.substring(2, 7)}-${t.substring(7, 11)}';
    if (t.length == 10) return '(${t.substring(0, 2)}) ${t.substring(2, 6)}-${t.substring(6, 10)}';
    return phone;
  }

  String _safeCurrency(String? value) {
    if (value == null || value.trim().isEmpty) return 'Valor não definido';
    if (value.contains('R\$')) return value;
    final t = value.replaceAll(RegExp(r'\D'), '');
    if (t.isEmpty) return value;
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(double.parse(t) / 100);
  }

  @override
  Widget build(BuildContext context) {
    final stage = widget.client['stage'] ?? 'Novo Cliente';
    final creditText = _safeCurrency(widget.client['credit_value']?.toString());
    
    final bool isHelpMode = widget.client['is_help_mode'] == true;
    final bool phoneReleased = widget.client['phone_released'] == true; 
    final String rawPhone = _safePhone(widget.client['phone']);
    final List<dynamic> chatHistory = widget.client['chat_history'] != null ? List<dynamic>.from(widget.client['chat_history']) : [];
    final String info = widget.client['additional_info']?.toString().trim() ?? '';

    final String createdAt = widget.client['created_at'] != null
        ? DateFormat("dd/MM/yy 'às' HH:mm").format(DateTime.parse(widget.client['created_at']).toLocal())
        : '';

    return GestureDetector(
      onTap: () async {
        setState(() => _isExpanded = !_isExpanded);
        if (_isExpanded && (widget.client['unread_supervisor'] ?? 0) > 0) {
          await Supabase.instance.client.from('clients').update({'unread_supervisor': 0}).eq('id', widget.client['id']);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut, margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: isHelpMode ? const Color(0xFFFFFBEB) : Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: isHelpMode ? const Color(0xFFF59E0B).withOpacity(0.5) : (_isExpanded ? const Color(0xFFF59E0B).withOpacity(0.3) : Colors.transparent), width: isHelpMode ? 2.0 : 1.5), boxShadow: [BoxShadow(color: isHelpMode ? const Color(0xFFF59E0B).withOpacity(0.1) : Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    Container(height: 48, width: 48, decoration: BoxDecoration(color: isHelpMode ? const Color(0xFFF59E0B).withOpacity(0.1) : const Color(0xFFF4F7FE), shape: BoxShape.circle), child: Icon(isHelpMode ? Icons.warning_rounded : Icons.person_outline_rounded, color: isHelpMode ? const Color(0xFFF59E0B) : const Color(0xFF0F172A))),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  widget.client['name'], 
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.3), 
                                  maxLines: 1, 
                                  overflow: TextOverflow.ellipsis
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.badge_rounded, size: 10, color: Color(0xFF64748B)), const SizedBox(width: 4), Flexible(child: Text(widget.sellerFirstName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis))])),
                            ],
                          ),
                          const SizedBox(height: 6), 
                          
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (createdAt.isNotEmpty) ...[
                                      Row(
                                        children: [
                                          const Icon(Icons.access_time_rounded, size: 11, color: Color(0xFF94A3B8)),
                                          const SizedBox(width: 4),
                                          Expanded(child: Text(createdAt, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis)),
                                        ],
                                      ),
                                    ],
                                    if (phoneReleased) ...[
                                      const SizedBox(height: 4),
                                      Text(rawPhone, style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                    ]
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildStageBadge(stage),
                            ],
                          ),
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
                            const SizedBox(height: 12),
                            Row(children: [ Expanded(child: _buildHighlight(Icons.radar_rounded, widget.client['capture_type'] ?? 'Indicação', const Color(0xFF8B5CF6))), const SizedBox(width: 12), Expanded(child: _buildHighlight(Icons.next_plan_rounded, widget.client['plan_type'] ?? 'Normal', const Color(0xFFF59E0B))) ]),
                            if (info.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ const Text('Anotações do Cadastro', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)), const SizedBox(height: 4), Text(info, style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B))) ]),
                              )
                            ],
                            const SizedBox(height: 24),
                            // --- TÍTULO COM O BOTÃO EDITAR ALINHADO ---
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Histórico e Ações do Lead', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                InkWell(
                                  onTap: _showEditDialog,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFDE68A))),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.edit_rounded, size: 12, color: Color(0xFFD97706)),
                                        SizedBox(width: 4),
                                        Text('Editar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // -------------------------------------------
                            const SizedBox(height: 12),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 250), padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
                              child: chatHistory.isEmpty ? const Center(child: Text('Nenhuma anotação do vendedor.', style: TextStyle(fontSize: 12, color: Colors.black38))) : ListView.builder(shrinkWrap: true, itemCount: chatHistory.length, itemBuilder: (ctx, i) => _buildChatBubble(chatHistory[i], isMe: chatHistory[i]['sender'] == 'supervisor')),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: TextField(controller: _msgController, style: const TextStyle(fontSize: 13), decoration: InputDecoration(hintText: isHelpMode ? 'Responder vendedor...' : 'Enviar orientação...', filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFFDE68A))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFFDE68A))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFF59E0B)))))),
                                const SizedBox(width: 8),
                                InkWell(onTap: () => _sendSupervisorMessage(), borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle), child: const Icon(Icons.send_rounded, color: Colors.white, size: 18)))
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (!phoneReleased) ...[
                              const Center(child: Text('Aguardando o vendedor liberar o contato.', style: TextStyle(fontSize: 11, color: Colors.black38, fontStyle: FontStyle.italic))),
                            ] else ...[
                              Row(children: [ Expanded(child: _buildActionButton(Icons.phone_rounded, 'Ligar', const Color(0xFF3B82F6), const Color(0xFFEFF6FF), () => _executeAction('ligacao', rawPhone))), const SizedBox(width: 12), Expanded(child: _buildActionButton(Icons.chat_rounded, 'WhatsApp', const Color(0xFF10B981), const Color(0xFFECFDF5), () => _executeAction('whatsapp', rawPhone))), ]),
                              if (isHelpMode) ...[
                                const SizedBox(height: 12),
                                InkWell(onTap: _toggleHelpOff, borderRadius: BorderRadius.circular(12), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle_rounded, color: Colors.black54, size: 16), SizedBox(width: 6), Text('Encerrar Ajuda / Ocultar Contato', style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold))]))),
                              ]
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
        decoration: BoxDecoration(color: isAlert ? const Color(0xFFFEF2F2) : (isMe ? const Color(0xFFFFFBEB) : const Color(0xFFEEF2FF)), borderRadius: BorderRadius.only(topLeft: const Radius.circular(12), topRight: const Radius.circular(12), bottomLeft: Radius.circular(isMe ? 12 : 2), bottomRight: Radius.circular(isMe ? 2 : 12)), border: Border.all(color: isAlert ? Colors.red.withOpacity(0.3) : (isMe ? const Color(0xFFFDE68A) : const Color(0xFFC7D2FE)))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [Icon(isMe ? Icons.admin_panel_settings_rounded : Icons.person_rounded, size: 10, color: isAlert ? Colors.redAccent : (isMe ? const Color(0xFFD97706) : const Color(0xFF4F46E5))), const SizedBox(width: 4), Text(isAlert ? 'Pedido de Ajuda' : (isMe ? 'Eu (Gestão)' : 'Vendedor'), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isAlert ? Colors.redAccent : (isMe ? const Color(0xFFD97706) : const Color(0xFF4F46E5))))]),
          const SizedBox(height: 4), Text(msg['text'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))), const SizedBox(height: 4), Align(alignment: Alignment.bottomRight, child: Text(dateStr, style: const TextStyle(fontSize: 8, color: Colors.black38))),
        ]),
      ),
    );
  }

  Widget _buildStageBadge(String stage) {
    Color baseColor = const Color(0xFF94A3B8);
    if (stage == 'Novo Cliente') baseColor = const Color(0xFF10B981);
    else if (stage == 'Em negociação') baseColor = const Color(0xFF3B82F6);
    else if (stage == 'Cadastrado') baseColor = const Color(0xFFF59E0B);
    else if (stage == 'Fechado') baseColor = const Color(0xFF8B5CF6);
    else if (stage == 'Excluído') baseColor = Colors.redAccent;

    return InkWell(
      onTap: _showStagePicker, 
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 125), // Trava de segurança no tamanho
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), 
        decoration: BoxDecoration(color: baseColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: baseColor.withOpacity(0.3))), 
        child: Text(stage, style: TextStyle(color: baseColor, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 1),
      ),
    );
  }

  Future<void> _showStagePicker() async {
    final stages = ['Novo Cliente', 'Em negociação', 'Cadastrado', 'Fechado', 'Excluído'];
    final currentStage = widget.client['stage'] ?? 'Novo Cliente';

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text('Mover para fase:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ),
                ...stages.map((s) => ListTile(
                  title: Text(s, style: TextStyle(fontWeight: s == currentStage ? FontWeight.bold : FontWeight.w500, color: s == currentStage ? const Color(0xFF4F46E5) : const Color(0xFF334155))),
                  trailing: s == currentStage ? const Icon(Icons.check_circle_rounded, color: Color(0xFF4F46E5)) : null,
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (s != currentStage) {
                      // Salva a nova fase no Supabase
                      await Supabase.instance.client.from('clients').update({'stage': s}).eq('id', widget.client['id']);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cliente movido para $s'), backgroundColor: const Color(0xFF10B981)));
                      }
                    }
                  },
                )).toList(),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildHighlight(IconData icon, String text, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: color), const SizedBox(width: 6), Flexible(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis))]));
  }

  Widget _buildActionButton(IconData icon, String label, Color color, Color bgColor, VoidCallback onTap) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color, size: 16), const SizedBox(width: 6), Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold))])));
  }
}

class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    String formatted = '';
    if (text.isNotEmpty) {
      formatted = '(' + text.substring(0, math.min(text.length, 2));
      if (text.length > 2) {
        formatted += ') ' + text.substring(2, math.min(text.length, 7));
        if (text.length > 7) {
          formatted += '-' + text.substring(7, math.min(text.length, 11));
        }
      }
    }
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.isEmpty) text = '0';
    double value = double.parse(text) / 100;
    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    String newText = formatter.format(value);
    return TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newText.length));
  }
}