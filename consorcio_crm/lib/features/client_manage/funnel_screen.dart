import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;

import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';

import '../auth/profile_provider.dart';

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

// --- PROVEDOR DE CLIENTES DO VENDEDOR ---
// Puxa estritamente os clientes deste vendedor específico, já com autoDispose para não deixar fantasmas
final myClientsProvider = StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, userId) {
  return Supabase.instance.client
      .from('clients')
      .stream(primaryKey: ['id'])
      .eq('vendedor_id', userId)
      .order('created_at', ascending: false);
});

// ------------------------------------------------------------------------
// TELA 1: O HUB DO FUNIL DO VENDEDOR
// ------------------------------------------------------------------------
class FunnelScreen extends ConsumerStatefulWidget {
  const FunnelScreen({super.key});

  @override
  ConsumerState<FunnelScreen> createState() => _FunnelScreenState();
}

class _FunnelScreenState extends ConsumerState<FunnelScreen> {
  int _selectedFilterIndex = 1; // Padrão: Mês Atual
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
            const Text('Filtre a sua Carteira:', style: TextStyle(color: Colors.black54, fontSize: 13)),
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
                if (start.isAfter(end)) {
                  showTopSnackBar(Overlay.of(context), const CustomSnackBar.error(message: 'A data inicial não pode ser maior que a final.'));
                  return;
                }
                setState(() { _customStartDate = start; _customEndDate = end; _selectedFilterIndex = 2; });
                Navigator.pop(ctx);
              } catch (e) {
                showTopSnackBar(Overlay.of(context), const CustomSnackBar.error(message: 'Por favor, digite datas válidas.'));
              }
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

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0, centerTitle: true,
        title: const Text('Minha Carteira', style: TextStyle(color: Color(0xFF1E293B), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
        error: (err, stack) => Center(child: Text('Erro: $err')),
        data: (profile) {
          if (profile == null) return const Center(child: Text('Perfil não encontrado.'));
          
          final userId = profile.id;
          final clientsAsync = ref.watch(myClientsProvider(userId));
          final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
          
          String currentMonthName = DateFormat('MMMM', 'pt_BR').format(DateTime.now());
          currentMonthName = currentMonthName[0].toUpperCase() + currentMonthName.substring(1);

          return clientsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
            error: (err, stack) => Center(child: Text('Erro: $err')),
            data: (clients) {
              final now = DateTime.now();
              double totalProducao = 0, totalCarteira = 0, totalFechados = 0, totalDesistentes = 0;
              int countProducao = 0, countCarteira = 0, countFechados = 0, countDesistentes = 0;

              for (var c in clients) {
                final createdAt = DateTime.parse(c['created_at']);
                final isCurrentMonth = createdAt.year == now.year && createdAt.month == now.month;
                final val = _parseCurrency(c['credit_value'] ?? '');
                final stage = c['stage'] ?? 'Novo Cliente';
                
                // Mapeamento de Fases
                final isClosed = stage == 'Fechado';
                final isExcluded = stage == 'Excluído' || stage == 'Desistente'; // Segurança para leads antigos

                // 1. PRODUÇÃO DO MÊS (Ignora o filtro de data, sempre mostra o mês atual)
                if (isCurrentMonth && !isClosed && !isExcluded) {
                  totalProducao += val; 
                  countProducao++;
                }

                // 2. Filtro de tempo APENAS para as outras gavetas
                bool passesDateFilter = false;
                if (_selectedFilterIndex == 1) {
                  passesDateFilter = true; 
                } else if (_selectedFilterIndex == 0) {
                  passesDateFilter = isCurrentMonth; 
                } else if (_selectedFilterIndex == 2 && _customStartDate != null && _customEndDate != null) {
                  passesDateFilter = createdAt.isAfter(_customStartDate!.subtract(const Duration(seconds: 1))) && 
                                       createdAt.isBefore(_customEndDate!.add(const Duration(seconds: 1)));
                }

                if (!passesDateFilter) continue; 

                // Contabiliza respeitando o filtro para as demais gavetas
                if (isClosed) { 
                  totalFechados += val; countFechados++; 
                } else if (isExcluded) { 
                  totalDesistentes += val; countDesistentes++; 
                } else if (!isCurrentMonth && !isClosed && !isExcluded) { 
                  totalCarteira += val; countCarteira++; 
                }
              }

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                children: [
                  FadeInDown(child: const Text('Selecione a sua Carteira', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
                  const SizedBox(height: 16),
                  
                  // Pílulas de Filtro do Hub
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
                  const SizedBox(height: 16),

                  FadeInUp(delay: const Duration(milliseconds: 100), child: _buildHubCard(context, userId, 'Prospecções de $currentMonthName', 'Suas prospecções do mês', totalProducao, countProducao, currencyFormatter, 'producao', const Color(0xFFF59E0B), Icons.calendar_month_rounded)),
                  const SizedBox(height: 16),
                  FadeInUp(delay: const Duration(milliseconds: 200), child: _buildHubCard(context, userId, 'Clientes em Carteira', 'Pendências de meses anteriores', totalCarteira, countCarteira, currencyFormatter, 'carteira', const Color(0xFF0EA5E9), Icons.hourglass_top_rounded)),
                  const SizedBox(height: 16),
                  FadeInUp(delay: const Duration(milliseconds: 300), child: _buildHubCard(context, userId, 'Clientes já Fechados', 'Histórico de sucessos', totalFechados, countFechados, currencyFormatter, 'fechados', const Color(0xFF10B981), Icons.handshake_rounded)),
                  const SizedBox(height: 16),
                  FadeInUp(delay: const Duration(milliseconds: 400), child: _buildHubCard(context, userId, 'Desistentes / Excluídos', 'Oportunidades perdidas', totalDesistentes, countDesistentes, currencyFormatter, 'desistentes', const Color(0xFFEF4444), Icons.delete_sweep_rounded)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHubCard(BuildContext context, String userId, String title, String subtitle, double total, int count, NumberFormat formatter, String category, Color color, IconData icon) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FunnelListScreen(userId: userId, category: category, title: title))),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))]),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 28)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.3)), Text('$count leads', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))), const SizedBox(height: 8), Text(formatter.format(total), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5))])),
            const Icon(Icons.chevron_right_rounded, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------
// TELA 2: LISTA DE CLIENTES COM FILTROS DO VENDEDOR
// ------------------------------------------------------------------------
class FunnelListScreen extends ConsumerStatefulWidget {
  final String userId;
  final String category;
  final String title;

  const FunnelListScreen({super.key, required this.userId, required this.category, required this.title});

  @override
  ConsumerState<FunnelListScreen> createState() => _FunnelListScreenState();
}

class _FunnelListScreenState extends ConsumerState<FunnelListScreen> {
  bool _isSearching = false;
  String _searchQuery = '';
  
  int _dateFilterIndex = 1; 
  DateTime? _startDate;
  DateTime? _endDate;

  String? _selectedStage; 
  String? _selectedSegment; 

  final TextEditingController _searchController = TextEditingController();
  final List<String> _stages = ['Novo Cliente', 'Em negociação', 'Cadastrado'];
  final List<String> _segments = ['Imóvel', 'Automóvel', 'Motocicleta', 'Serviços'];

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
                if (start.isAfter(end)) {
                  showTopSnackBar(Overlay.of(context), const CustomSnackBar.error(message: 'Data inicial maior que a final.'));
                  return;
                }
                setState(() { _startDate = start; _endDate = end; _dateFilterIndex = 2; });
                Navigator.pop(ctx);
              } catch (e) {
                showTopSnackBar(Overlay.of(context), const CustomSnackBar.error(message: 'Datas inválidas.'));
              }
            },
            child: const Text('Aplicar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      )
    );
  }

  void _showAdvancedFilters() {
    showModalBottomSheet(
      context: context, 
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // <--- A MÁGICA QUE RESOLVE O BUG DE OVERFLOW
      builder: (ctx) => SafeArea(
        child: Container(
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
                      children: [
                        _buildDateFilterChip('Mês Atual', 0, ctx), const SizedBox(width: 8),
                        _buildDateFilterChip('Todo o Período', 1, ctx), const SizedBox(width: 8),
                        _buildDateFilterChip('Personalizado', 2, ctx),
                      ],
                    ),
                  ),
                  const Divider(height: 32),
                ],

                // FILTRO DE VENDEDOR REMOVIDO DAQUI

                const Text('Filtrar por Segmento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 12),
                ..._segments.map((seg) => _buildSegmentOption(seg)).toList(),
                const Divider(height: 32),
                
                ListTile(
                  onTap: () { setState(() { _selectedSegment = null; _dateFilterIndex = 1; }); Navigator.pop(context); },
                  leading: const Icon(Icons.clear_all_rounded, color: Colors.redAccent),
                  title: const Text('Limpar Todos os Filtros', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateFilterChip(String label, int index, BuildContext ctx) {
    final isSelected = _dateFilterIndex == index;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
      selected: isSelected,
      selectedColor: const Color(0xFFF59E0B),
      backgroundColor: const Color(0xFFF1F5F9),
      onSelected: (val) {
        Navigator.pop(ctx);
        if (index == 2) {
          _showCustomDateDialog();
        } else {
          setState(() => _dateFilterIndex = index);
        }
      },
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
    final clientsAsync = ref.watch(myClientsProvider(widget.userId));
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
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () { setState(() { _isSearching = !_isSearching; if (!_isSearching) { _searchQuery = ''; _searchController.clear(); } }); },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAdvancedFilters(),
        backgroundColor: const Color(0xFF0F172A), elevation: 4,
        icon: const Icon(Icons.filter_alt_rounded, color: Colors.white, size: 18),
        label: Text(_selectedSegment ?? 'Filtros', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
      body: clientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
        error: (err, stack) => Center(child: Text('Erro: $err')),
        data: (allClients) {
          final now = DateTime.now();

          final filteredClients = allClients.where((c) {
            final createdAt = DateTime.parse(c['created_at']);
            final isCurrentMonth = createdAt.year == now.year && createdAt.month == now.month;
            final stage = c['stage'] ?? 'Novo Cliente';
            final interest = c['interest'] ?? 'Serviços';
            final name = (c['name'] ?? '').toString().toLowerCase();
            
            final isClosed = stage == 'Fechado';
            final isExcluded = stage == 'Excluído' || stage == 'Desistente';

            // 1. Regra de Data
            bool matchesDate = false;
            if (widget.category == 'producao') {
              matchesDate = true; // Produção já é garantida pelo isCurrentMonth lá embaixo
            } else {
              if (_dateFilterIndex == 1) matchesDate = true;
              else if (_dateFilterIndex == 0) matchesDate = isCurrentMonth;
              else if (_dateFilterIndex == 2 && _startDate != null && _endDate != null) {
                matchesDate = createdAt.isAfter(_startDate!.subtract(const Duration(seconds: 1))) && 
                              createdAt.isBefore(_endDate!.add(const Duration(seconds: 1)));
              }
            }
            if (!matchesDate) return false;

            // 2. Regra das Categorias (Carteiras)
            bool matchesCategory = false;
            if (widget.category == 'fechados') {
              matchesCategory = isClosed;
            } else if (widget.category == 'desistentes') {
              matchesCategory = isExcluded;
            } else if (widget.category == 'producao') {
              matchesCategory = isCurrentMonth && !isClosed && !isExcluded;
            } else if (widget.category == 'carteira') {
              matchesCategory = !isCurrentMonth && !isClosed && !isExcluded;
            }
            
            if (!matchesCategory) return false;

            // 3. Demais Filtros Visuais (Busca, Estágio e Segmento)
            if (_searchQuery.isNotEmpty && !name.contains(_searchQuery.toLowerCase())) return false;
            if (isFilteredCategory && _selectedStage != null && stage != _selectedStage) return false;
            if (_selectedSegment != null) {
              String mappedInterest = interest;
              if (interest.contains('Veículos')) mappedInterest = 'Automóvel';
              if (mappedInterest != _selectedSegment) return false;
            }
            return true;
          }).toList();

          // Ordenação Decrescente
          filteredClients.sort((a, b) {
            final dateA = DateTime.parse(a['created_at']);
            final dateB = DateTime.parse(b['created_at']);
            return dateB.compareTo(dateA); 
          });

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
                        return FadeInUp(
                          duration: const Duration(milliseconds: 300),
                          child: _ExpandableClientCard(client: client, currencyFormatter: currencyFormatter),
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
// COMPONENTE: CARD DO CLIENTE (SEM NOME DO VENDEDOR)
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
  final TextEditingController _msgController = TextEditingController();

  // --- NOVA FUNÇÃO: REGISTRAR ATIVIDADE NO LOG ---
  Future<void> _logActivity(String actionType, String description) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    
    String sellerName = 'Vendedor';
    try {
      final prof = await Supabase.instance.client.from('profiles').select('full_name').eq('id', userId).maybeSingle();
      if (prof != null && prof['full_name'] != null) sellerName = prof['full_name'];
    } catch(e) {}

    await Supabase.instance.client.from('activity_logs').insert({
      'vendedor_id': userId,
      'vendedor_nome': sellerName,
      'client_id': widget.client['id'],
      'client_nome': widget.client['name'],
      'action_type': actionType,
      'description': description,
    });
  }

  @override
  void dispose() { _msgController.dispose(); super.dispose(); }

  Future<void> _executeAction(String actionType) async {
    final phone = widget.client['phone'].toString().replaceAll(RegExp(r'\D'), '');
    final finalPhone = (phone.length == 10 || phone.length == 11) ? '55$phone' : phone;
    Uri url = actionType == 'whatsapp' ? Uri.parse('https://wa.me/$finalPhone?text=Olá') : Uri.parse('tel:$phone');
    
    // --- REGISTRO DE ATIVIDADE DE CONTATO ---
    final logAction = actionType == 'whatsapp' ? 'WHATSAPP' : 'CALL';
    final logDesc = actionType == 'whatsapp' ? 'Iniciou contato via WhatsApp.' : 'Realizou uma tentativa de ligação.';
    await _logActivity(logAction, logDesc);
    // ----------------------------------------

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
      updateData['phone_released'] = true;
    }
    
    if (requestingHelp || isHelpMode) {
      updateData['unread_supervisor'] = (widget.client['unread_supervisor'] ?? 0) + 1;
    }

    await Supabase.instance.client.from('clients').update(updateData).eq('id', widget.client['id']);
    // Injetar log do comentário
    if (text.isNotEmpty && !requestingHelp) {
      await _logActivity('COMMENT', 'Adicionou uma nova ação realizada.'); // <-- Frase corrigida!
    } else if (requestingHelp) {
      await _logActivity('HELP', 'Solicitou ajuda da gestão.');
    }
    if (mounted) { _msgController.clear(); FocusScope.of(context).unfocus(); }
  }

  // --- NOVA FUNÇÃO: AGENDAR LEMBRETE ---
  Future<void> _showReminderDialog() async {
    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF8B5CF6))), child: child!),
    );
    if (selectedDate == null) return;

    TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF8B5CF6))), child: child!),
    );
    if (selectedTime == null) return;

    final DateTime reminderDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
    
    if (reminderDateTime.isBefore(DateTime.now())) {
      showTopSnackBar(Overlay.of(context), const CustomSnackBar.error(message: 'A data do lembrete deve ser no futuro.'));
      return;
    }

    String selectedType = 'Retornar Ligação';
    final types = ['Retornar Ligação', 'Promessa de Pagamento', 'Visita Agendada', 'Reunião', 'Outro'];

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Agendar Lembrete', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.alarm_rounded, color: Color(0xFF8B5CF6), size: 20),
                    const SizedBox(width: 8),
                    Text(DateFormat('dd/MM/yyyy HH:mm').format(reminderDateTime), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6), fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Motivo do Lembrete:', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: selectedType,
                  decoration: InputDecoration(filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                  items: types.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setDialogState(() => selectedType = v!),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.black54))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () async {
                  // 1. Adiciona o lembrete no histórico de conversas pra ficar visível na tela
                  final List<dynamic> currentHistory = widget.client['chat_history'] != null ? List<dynamic>.from(widget.client['chat_history']) : [];
                  currentHistory.add({
                    'sender': 'sistema',
                    'text': 'Lembrete: $selectedType',
                    'timestamp': DateTime.now().toIso8601String(),
                    'reminder_date': reminderDateTime.toIso8601String(),
                    'is_reminder': true,
                  });

                  // 2. Atualiza no Supabase
                  await Supabase.instance.client.from('clients').update({
                    'chat_history': currentHistory,
                    // DICA: Se no futuro você criar uma coluna 'next_reminder' no banco de dados, você pode salvar a data nela aqui também!
                  }).eq('id', widget.client['id']);

                  // 3. Registra no Log de Atividades
                  await _logActivity('REMINDER', 'Agendou lembrete: $selectedType para ${DateFormat('dd/MM/yy HH:mm').format(reminderDateTime)}');

                  // NOTA PARA O DESENVOLVEDOR: 
                  // É AQUI DENTRO QUE VOCÊ VAI CHAMAR O flutter_local_notifications NO FUTURO
                  // Exemplo: LocalNotificationService.schedule(title: selectedType, date: reminderDateTime);

                  if (mounted) {
                    Navigator.pop(ctx);
                    setState(() {}); // Força a tela a atualizar pra mostrar o lembrete
                    showTopSnackBar(Overlay.of(context), const CustomSnackBar.success(message: 'Lembrete salvo com sucesso!'));
                  }
                },
                child: const Text('Confirmar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            ],
          );
        }
      ),
    );
  }

  Future<void> _acceptSupervisorHelp() async {
    await Supabase.instance.client.from('clients').update({'phone_released': true}).eq('id', widget.client['id']);
    if (mounted) {
      showTopSnackBar(Overlay.of(context), const CustomSnackBar.success(message: 'Contato liberado para a gestão.'));
    }
  }

  // --- NOVA FUNÇÃO: DIÁLOGO DE EDIÇÃO DO CLIENTE ---
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
        ),
        TextFormField(
          controller: controller, maxLines: maxLines,
          keyboardType: isPhone || isCurrency ? TextInputType.number : TextInputType.text,
          inputFormatters: formatters,
          decoration: InputDecoration(
            filled: true, 
            fillColor: const Color(0xFFF8FAFC), 
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14) // Dá um respiro interno no campo
          ),
        ),
      ],
    );
  }

  Widget _buildEditDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
        ),
        DropdownButtonFormField<String>(
          isExpanded: true, value: value,
          decoration: InputDecoration(
            filled: true, 
            fillColor: const Color(0xFFF8FAFC), 
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
          ),
          items: items.map((v) => DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis))).toList(), 
          onChanged: onChanged,
        ),
      ],
    );
  }

  // --- FORMATADORES DE EXIBIÇÃO SEGURA ---
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
    final phoneText = _safePhone(widget.client['phone']);
    final bool isHelpMode = widget.client['is_help_mode'] == true;
    final bool phoneReleased = widget.client['phone_released'] == true;
    final List<dynamic> chatHistory = widget.client['chat_history'] != null ? List<dynamic>.from(widget.client['chat_history']) : [];
    final int unread = widget.client['unread_vendedor'] ?? 0;
    final String info = widget.client['additional_info']?.toString().trim() ?? '';

    final String createdAt = widget.client['created_at'] != null
        ? DateFormat("dd/MM/yy 'às' HH:mm").format(DateTime.parse(widget.client['created_at']).toLocal())
        : '';

    return GestureDetector(
      onTap: () async {
        setState(() => _isExpanded = !_isExpanded);
        if (_isExpanded && unread > 0) {
          await Supabase.instance.client.from('clients').update({'unread_vendedor': 0}).eq('id', widget.client['id']);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut, margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: isHelpMode ? const Color(0xFFFEF2F2) : Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: isHelpMode ? Colors.redAccent.withOpacity(0.5) : (_isExpanded ? const Color(0xFFF59E0B).withOpacity(0.3) : Colors.transparent), width: isHelpMode ? 2.0 : 1.5), boxShadow: [BoxShadow(color: isHelpMode ? Colors.redAccent.withOpacity(0.1) : Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))]),
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
                    Container(height: 48, width: 48, decoration: BoxDecoration(color: isHelpMode ? Colors.redAccent.withOpacity(0.1) : const Color(0xFFF4F7FE), shape: BoxShape.circle), child: Icon(isHelpMode ? Icons.support_agent_rounded : Icons.person_outline_rounded, color: isHelpMode ? Colors.redAccent : const Color(0xFF0F172A))),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.client['name'], 
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.3), 
                            maxLines: 1, 
                            overflow: TextOverflow.ellipsis
                          ),
                          const SizedBox(height: 6), 
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(phoneText, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                                    if (createdAt.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.access_time_rounded, size: 11, color: Color(0xFF94A3B8)),
                                          const SizedBox(width: 4),
                                          Expanded(child: Text(createdAt, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis)),
                                        ],
                                      ),
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
                            const SizedBox(height: 20),
                            Row(
                              children: [ 
                                Expanded(child: _buildActionButton(Icons.phone_rounded, 'Ligar', const Color(0xFF3B82F6), const Color(0xFFEFF6FF), () => _executeAction('ligacao'))), 
                                const SizedBox(width: 8), 
                                Expanded(child: _buildActionButton(Icons.chat_rounded, 'WhatsApp', const Color(0xFF10B981), const Color(0xFFECFDF5), () => _executeAction('whatsapp'))),
                                const SizedBox(width: 8), 
                                Expanded(child: _buildActionButton(Icons.notification_add_rounded, 'Lembrete', const Color(0xFF8B5CF6), const Color(0xFFF5F3FF), _showReminderDialog)),
                              ]
                            ),
                            const SizedBox(height: 24),
                            // --- TÍTULO COM O BOTÃO EDITAR ALINHADO ---
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Registros de Ações', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                InkWell(
                                  onTap: _showEditDialog,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.edit_rounded, size: 12, color: Color(0xFF64748B)),
                                        SizedBox(width: 4),
                                        Text('Editar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
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
                            if (!isHelpMode) ...[
                              InkWell(onTap: () => _sendMessage(requestingHelp: true), borderRadius: BorderRadius.circular(12), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.redAccent.withOpacity(0.3))), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 6), Text('Pedir Ajuda ao Supervisor', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold))]))),
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
    final bool isReminder = msg['is_reminder'] == true; // NOVO: Verifica se é um lembrete

    // Lógica inteligente de cores
    Color bgColor = isReminder ? const Color(0xFFF5F3FF) : (isAlert ? const Color(0xFFFEF2F2) : (isMe ? const Color(0xFFEEF2FF) : const Color(0xFFFFFBEB)));
    Color borderColor = isReminder ? const Color(0xFFDDD6FE) : (isAlert ? Colors.red.withOpacity(0.3) : (isMe ? const Color(0xFFC7D2FE) : const Color(0xFFFDE68A)));
    Color iconColor = isReminder ? const Color(0xFF8B5CF6) : (isAlert ? Colors.redAccent : (isMe ? const Color(0xFF4F46E5) : const Color(0xFFD97706)));
    IconData icon = isReminder ? Icons.alarm_rounded : (isMe ? Icons.person_rounded : Icons.admin_panel_settings_rounded);
    String title = isReminder ? 'Lembrete Agendado' : (isAlert ? 'Pedido de Ajuda' : (isMe ? 'Eu (Vendedor)' : 'Supervisor'));

    return Align(
      alignment: isReminder ? Alignment.center : (isMe ? Alignment.centerRight : Alignment.centerLeft),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 12, color: iconColor), const SizedBox(width: 4), Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: iconColor))]),
          const SizedBox(height: 4),
          Text(msg['text'] ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500)),
          
          // Se for lembrete, mostra a data do alarme em destaque!
          if (isReminder && msg['reminder_date'] != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text('⏰ Para: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(msg['reminder_date']))}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: iconColor)),
            ),
          ],
          
          const SizedBox(height: 4), Align(alignment: Alignment.bottomRight, child: Text(dateStr, style: const TextStyle(fontSize: 8, color: Colors.black38))),
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
                      // Injetar log da mudança de fase
                      await _logActivity('STAGE', 'Moveu o lead de "$currentStage" para "$s".');
                      if (mounted) {
                        showTopSnackBar(Overlay.of(context), CustomSnackBar.success(message: 'Cliente movido para $s'));
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