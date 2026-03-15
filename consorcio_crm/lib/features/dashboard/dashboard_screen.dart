import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/router/app_router.dart';
import '../auth/profile_provider.dart';

// Provedor para calcular o potencial do mês atual do vendedor
final currentMonthPotentialProvider = StreamProvider<double>((ref) {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return Stream.value(0.0);

  final now = DateTime.now();
  
  return Supabase.instance.client
      .from('clients')
      .stream(primaryKey: ['id'])
      .eq('vendedor_id', userId)
      .map((clients) {
        double total = 0;
        for (var c in clients) {
          final createdAt = DateTime.parse(c['created_at']);
          final isCurrentMonth = createdAt.year == now.year && createdAt.month == now.month;
          final isClosed = c['stage'] == 'Fechamento';
          
          if (isCurrentMonth && !isClosed) {
            total += _parseCurrency(c['credit_value'] ?? '');
          }
        }
        return total;
      });
});

double _parseCurrency(String value) {
  if (value.isEmpty) return 0.0;
  String clean = value.replaceAll(RegExp(r'[^0-9,\.]'), '');
  if (clean.isEmpty) return 0.0;
  if (clean.contains('.') && clean.contains(',')) {
    clean = clean.replaceAll('.', '').replaceAll(',', '.');
  } else if (clean.contains(',')) {
    clean = clean.replaceAll(',', '.');
  } else if (clean.contains('.') && clean.lastIndexOf('.') < clean.length - 3) {
    clean = clean.replaceAll('.', '');
  }
  return double.tryParse(clean) ?? 0.0;
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _getMonthName(int month) {
    // Agora retornando o nome completo para maior elegância
    const months = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final currentMonthName = _getMonthName(DateTime.now().month);
    final currencyFormatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A))),
        error: (error, stack) => Center(child: Text('Erro: $error')),
        data: (profile) {
          if (profile == null) return const Center(child: Text('Perfil não encontrado.'));

          final isSupervisor = profile.role == 'supervisor';

          return CustomScrollView(
            slivers: [
              // --- CABEÇALHO AMPLIADO E OTIMIZADO ---
              SliverAppBar(
                floating: false,
                pinned: true,
                backgroundColor: const Color(0xFF0F172A),
                elevation: 0,
                toolbarHeight: 85, // Aumentado para dar mais presença
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Olá, ${profile.fullName.split(' ').first}',
                      style: const TextStyle(
                        fontSize: 22, // Aumentado
                        fontWeight: FontWeight.bold, 
                        color: Colors.white, 
                        letterSpacing: -0.8
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSupervisor ? 'Supervisão Regional' : 'Executivo de Vendas',
                      style: const TextStyle(
                        fontSize: 14, // Aumentado
                        color: Color(0xFFD97706), 
                        fontWeight: FontWeight.w600
                      ),
                    ),
                  ],
                ),
                actions: [
                  if (!isSupervisor)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Consumer(
                          builder: (context, ref, child) {
                            final potentialAsync = ref.watch(currentMonthPotentialProvider);
                            return potentialAsync.when(
                              loading: () => const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2)),
                              error: (_, __) => const Text('Erro', style: TextStyle(color: Colors.red)),
                              data: (total) => Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Potencial $currentMonthName', // Nome completo
                                    style: const TextStyle(
                                      color: Colors.white70, 
                                      fontSize: 11, // Ajustado
                                      fontWeight: FontWeight.w600
                                    ),
                                  ),
                                  Text(
                                    currencyFormatter.format(total),
                                    style: const TextStyle(
                                      fontSize: 17, // Aumentado para destaque premium
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF10B981),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 28),
                    tooltip: 'Sair do sistema',
                    onPressed: () => ref.read(authStateProvider.notifier).logout(),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
              
              SliverPadding(
                padding: const EdgeInsets.only(top: 24.0, left: 24.0, right: 24.0, bottom: 40.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const Text(
                      'Gestão de Negócios', 
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5)
                    ),
                    const SizedBox(height: 20),

                    if (isSupervisor) ...[
                      FadeInUp(duration: const Duration(milliseconds: 300), child: _buildPremiumCard(context: context, icon: Icons.notification_important_rounded, iconColor: const Color(0xFFD97706), title: 'Pedidos de Ajuda', subtitle: 'Apoio estratégico imediato.', route: '/help-requests')),
                      const SizedBox(height: 16),
                      FadeInUp(duration: const Duration(milliseconds: 400), child: _buildPremiumCard(context: context, icon: Icons.insert_chart_rounded, iconColor: const Color(0xFF3B82F6), title: 'Visão Geral da Equipe', subtitle: 'Análise completa da filial.', route: '/team-overview')),
                    ] else ...[
                      FadeInUp(duration: const Duration(milliseconds: 300), child: _buildPremiumCard(context: context, icon: Icons.person_add_alt_1_rounded, iconColor: const Color(0xFF10B981), title: 'Novo Prospect', subtitle: 'Registrar nova oportunidade.', route: '/add-client')),
                      const SizedBox(height: 16),
                      FadeInUp(duration: const Duration(milliseconds: 400), child: _buildPremiumCard(context: context, icon: Icons.calendar_month_rounded, iconColor: const Color(0xFF3B82F6), title: 'Produção $currentMonthName', subtitle: 'Clientes prospectados este mês.', route: '/client-list/current')),
                      const SizedBox(height: 16),
                      FadeInUp(duration: const Duration(milliseconds: 500), child: _buildPremiumCard(context: context, icon: Icons.hourglass_top_rounded, iconColor: const Color(0xFF8B5CF6), title: 'Pendências de Carteira', subtitle: 'Negociações em andamento.', route: '/client-list/negotiating')),
                      const SizedBox(height: 16),
                      FadeInUp(duration: const Duration(milliseconds: 600), child: _buildPremiumCard(context: context, icon: Icons.handshake_rounded, iconColor: const Color(0xFF10B981), title: 'Contratos Fechados', subtitle: 'Pós-venda e histórico.', route: '/client-list/closed')),
                    ],
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPremiumCard({required BuildContext context, required IconData icon, required Color iconColor, required String title, required String subtitle, required String route}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(22), // Levemente mais arredondado
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))]
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => context.push(route),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0), // Mais respiro vertical
            child: Row(
              children: [
                Container(
                  height: 60, 
                  width: 60, 
                  decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle), 
                  child: Icon(icon, color: iconColor, size: 30)
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.4)), 
                      const SizedBox(height: 4), 
                      Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.2))
                    ]
                  )
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.black26),
              ],
            ),
          ),
        ),
      ),
    );
  }
}