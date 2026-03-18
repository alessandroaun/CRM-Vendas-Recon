import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // NOVO IMPORT: Necessário para a máscara de data
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';

import '../auth/profile_provider.dart';

final performanceClientsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return const Stream.empty();

  return Supabase.instance.client
      .from('clients')
      .stream(primaryKey: ['id'])
      .eq('vendedor_id', userId)
      .order('created_at', ascending: false);
});

// --- CLASSE DA MÁSCARA DE DATA (Formata DD/MM/AAAA automaticamente) ---
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
    
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class HomePerformanceScreen extends StatefulWidget {
  const HomePerformanceScreen({super.key});

  @override
  State<HomePerformanceScreen> createState() => _HomePerformanceScreenState();
}

class _HomePerformanceScreenState extends State<HomePerformanceScreen> {
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

  // --- NOVA FUNÇÃO: CAIXA FLUTUANTE DE DATA ---
  void _showCustomDateDialog(BuildContext context) {
    final startCtrl = TextEditingController(text: _customStartDate != null ? DateFormat('dd/MM/yyyy').format(_customStartDate!) : '');
    final endCtrl = TextEditingController(text: _customEndDate != null ? DateFormat('dd/MM/yyyy').format(_customEndDate!) : '');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Período Personalizado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A), letterSpacing: -0.5)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Digite as datas para filtrar a sua produção:', style: TextStyle(color: Colors.black54, fontSize: 13)),
              const SizedBox(height: 20),
              TextField(
                controller: startCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [DateTextFormatter()],
                decoration: InputDecoration(
                  labelText: 'Data Inicial',
                  hintText: 'DD/MM/AAAA',
                  filled: true,
                  fillColor: const Color(0xFFF4F7FE),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF4F46E5)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: endCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [DateTextFormatter()],
                decoration: InputDecoration(
                  labelText: 'Data Final',
                  hintText: 'DD/MM/AAAA',
                  filled: true,
                  fillColor: const Color(0xFFF4F7FE),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF4F46E5)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (_customStartDate == null) setState(() => _selectedFilterIndex = 0);
              },
              child: const Text('Cancelar', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                try {
                  final start = DateFormat('dd/MM/yyyy').parseStrict(startCtrl.text);
                  // Pega o último segundo do dia final para garantir que o dia inteiro entra na conta
                  final end = DateFormat('dd/MM/yyyy').parseStrict(endCtrl.text).add(const Duration(hours: 23, minutes: 59, seconds: 59));

                  if (start.isAfter(end)) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A data inicial não pode ser maior que a final.')));
                     return;
                  }

                  setState(() {
                    _customStartDate = start;
                    _customEndDate = end;
                    _selectedFilterIndex = 2;
                  });
                  Navigator.pop(ctx);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, digite datas válidas (DD/MM/AAAA).')));
                }
              },
              child: const Text('Aplicar Filtro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    );
  }

  List<Map<String, dynamic>> _filterClients(List<Map<String, dynamic>> allClients) {
    final now = DateTime.now();
    return allClients.where((c) {
      if (_selectedFilterIndex == 1) return true; // Todo o período
      
      final createdAt = DateTime.parse(c['created_at']);
      
      if (_selectedFilterIndex == 0) { // Mês Atual
        return createdAt.year == now.year && createdAt.month == now.month;
      }
      
      if (_selectedFilterIndex == 2) { // Personalizado
        if (_customStartDate != null && _customEndDate != null) {
          return createdAt.isAfter(_customStartDate!.subtract(const Duration(seconds: 1))) && 
                 createdAt.isBefore(_customEndDate!.add(const Duration(seconds: 1)));
        }
      }
      
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0, centerTitle: true,
        title: const Text('Performance', style: TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF1E293B)), onPressed: () {})],
      ),
      body: Consumer(
        builder: (context, ref, child) {
          final clientsAsync = ref.watch(performanceClientsProvider);
          final profileAsync = ref.watch(userProfileProvider);

          return clientsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
            error: (err, stack) => Center(child: Text('Erro: $err')),
            data: (allClients) {
              final filteredClients = _filterClients(allClients);

              String firstName = 'Executivo';
              profileAsync.whenData((profile) {
                if (profile != null && profile.fullName.isNotEmpty) {
                  firstName = profile.fullName.split(' ').first;
                }
              });

              final totalClients = filteredClients.length;
              double totalNegotiationCredit = 0.0;
              double totalCreditsSold = 0.0; 
              Map<String, int> segmentCounts = {'Imóvel': 0, 'Automóvel': 0, 'Motocicleta': 0, 'Serviços': 0};

              for (var c in filteredClients) {
                String interest = c['interest'] ?? 'Serviços';
                if (interest == 'Veículos Pesados') interest = 'Automóvel';
                double value = _parseCurrency(c['credit_value'] ?? '');

                if (c['stage'] == 'Em negociação') {
                  totalNegotiationCredit += value;
                  segmentCounts[interest] = (segmentCounts[interest] ?? 0) + 1;
                } else if (c['stage'] == 'Fechado') {
                  totalCreditsSold += value; 
                }
              }

              String topSegment = 'Nenhum';
              int maxCount = 0;
              segmentCounts.forEach((key, value) {
                if (value > maxCount) { maxCount = value; topSegment = key; }
              });

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeInDown(
                      duration: const Duration(milliseconds: 400),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Olá $firstName,', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5)),
                          const SizedBox(height: 4),
                          const Text('Suas estatísticas são essas...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    FadeIn(
                      duration: const Duration(milliseconds: 500),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('Mês Atual', 0),
                            const SizedBox(width: 12),
                            _buildFilterChip('Todo o Período', 1),
                            const SizedBox(width: 12),
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
                      // --- A MÁGICA DO TAMANHO AQUI (1.45 deixa compacto e retangular) ---
                      childAspectRatio: 1.45, 
                      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                      children: [
                        FadeInUp(delay: const Duration(milliseconds: 100), child: _buildMetricCard(title: 'Vendidos', value: currencyFormatter.format(totalCreditsSold), subtitle: 'Fechados no período', icon: Icons.verified_rounded, gradientColors: [const Color(0xFF34D399), const Color(0xFF10B981)])),
                        FadeInUp(delay: const Duration(milliseconds: 200), child: _buildMetricCard(title: 'Negociando', value: currencyFormatter.format(totalNegotiationCredit), subtitle: 'Crédito no funil', icon: Icons.monetization_on_rounded, gradientColors: [const Color(0xFFA78BFA), const Color(0xFF8B5CF6)])),
                        FadeInUp(delay: const Duration(milliseconds: 300), child: _buildMetricCard(title: 'Clientes', value: totalClients.toString(), subtitle: 'Cadastrados', icon: Icons.people_alt_rounded, gradientColors: [const Color(0xFF60A5FA), const Color(0xFF3B82F6)])),
                        FadeInUp(delay: const Duration(milliseconds: 400), child: _buildMetricCard(title: 'Destaque', value: topSegment, subtitle: '$maxCount negociando', icon: Icons.star_rounded, gradientColors: [const Color(0xFFF472B6), const Color(0xFFEC4899)])),
                      ],
                    ),
                    const SizedBox(height: 32),

                    FadeInUp(
                      delay: const Duration(milliseconds: 500),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Distribuição de Segmentos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                            const SizedBox(height: 20),
                            _buildProgressBar('Imóvel', segmentCounts['Imóvel'] ?? 0, totalClients, const Color(0xFF4F46E5)),
                            const SizedBox(height: 16),
                            _buildProgressBar('Automóvel', segmentCounts['Automóvel'] ?? 0, totalClients, const Color(0xFF4F46E5)),
                            const SizedBox(height: 16),
                            _buildProgressBar('Motocicleta', segmentCounts['Motocicleta'] ?? 0, totalClients, const Color(0xFF4F46E5)),
                            const SizedBox(height: 16),
                            _buildProgressBar('Serviços', segmentCounts['Serviços'] ?? 0, totalClients, const Color(0xFF4F46E5)),
                          ],
                        ),
                      ),
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
      final startStr = DateFormat('dd/MM/yy').format(_customStartDate!);
      final endStr = DateFormat('dd/MM/yy').format(_customEndDate!);
      displayLabel = '$startStr a $endStr';
    }

    return GestureDetector(
      onTap: () {
        if (index == 2) {
          _showCustomDateDialog(context); // Chama a nossa nova caixa flutuante!
        } else {
          setState(() => _selectedFilterIndex = index);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
          border: isSelected ? null : Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (index == 2 && !isSelected) ...[
               const Icon(Icons.edit_calendar_rounded, size: 14, color: Color(0xFF64748B)),
               const SizedBox(width: 6),
            ],
            Text(displayLabel, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({required String title, required String value, required String subtitle, required IconData icon, required List<Color> gradientColors}) {
    return Container(
      padding: const EdgeInsets.all(12), // Padding reduzido para caber melhor
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 5))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: Colors.white, size: 14)),
              const SizedBox(width: 8), 
              // FittedBox garante que o título não vai cortar
              Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B))))),
            ],
          ),
          const Spacer(), // Empurra os valores para a base do card
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5))),
          const SizedBox(height: 2), 
          Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildProgressBar(String title, int count, int total, Color color) {
    final double percentage = total == 0 ? 0.0 : (count / total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))), Text('$count leads', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))]),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(height: 10, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10))),
            FractionallySizedBox(widthFactor: percentage, child: Container(height: 10, decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withOpacity(0.6), color]), borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))]))),
          ],
        ),
      ],
    );
  }
}