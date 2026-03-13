import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';

import '../../core/router/app_router.dart';
import '../auth/profile_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

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
              // Cabeçalho Premium expansível
              SliverAppBar(
                expandedHeight: 140.0,
                floating: false,
                pinned: true,
                backgroundColor: const Color(0xFF0F172A),
                elevation: 0,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Colors.white70),
                    tooltip: 'Sair com segurança',
                    onPressed: () => ref.read(authStateProvider.notifier).logout(),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 24, bottom: 16, right: 24),
                  title: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Olá, ${profile.fullName.split(' ').first}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
                      ),
                      Text(
                        isSupervisor ? 'Supervisão Regional' : 'Executivo de Vendas',
                        style: const TextStyle(fontSize: 12, color: Color(0xFFD97706), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Corpo do Dashboard com os botões
              SliverPadding(
                padding: const EdgeInsets.all(24.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const Text(
                      'Ações Rápidas',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 16),

                    if (isSupervisor) ...[
                      FadeInUp(
                        duration: const Duration(milliseconds: 500),
                        child: _buildPremiumCard(
                          context: context,
                          icon: Icons.notification_important_rounded,
                          iconColor: const Color(0xFFD97706),
                          title: 'Pedidos de Ajuda',
                          subtitle: 'Vendedores aguardando suporte estratégico.',
                          route: '/help-requests',
                        ),
                      ),
                      const SizedBox(height: 16),
                      FadeInUp(
                        duration: const Duration(milliseconds: 600),
                        child: _buildPremiumCard(
                          context: context,
                          icon: Icons.insert_chart_rounded,
                          iconColor: const Color(0xFF3B82F6),
                          title: 'Visão Geral da Equipe',
                          subtitle: 'Monitore as métricas e a esteira de vendas.',
                          route: '/team-overview',
                        ),
                      ),
                    ] else ...[
                      FadeInUp(
                        duration: const Duration(milliseconds: 500),
                        child: _buildPremiumCard(
                          context: context,
                          icon: Icons.person_add_alt_1_rounded,
                          iconColor: const Color(0xFF10B981), // Verde Esmeralda
                          title: 'Cadastrar Cliente',
                          subtitle: 'Inicie uma nova jornada de negociação.',
                          route: '/add-client',
                        ),
                      ),
                      const SizedBox(height: 16),
                      FadeInUp(
                        duration: const Duration(milliseconds: 600),
                        child: _buildPremiumCard(
                          context: context,
                          icon: Icons.folder_shared_rounded,
                          iconColor: const Color(0xFF3B82F6), // Azul vibrante
                          title: 'Minhas Negociações',
                          subtitle: 'Gerencie seu funil e contate prospects.',
                          route: '/client-list',
                        ),
                      ),
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

  Widget _buildPremiumCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push(route),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                // Ícone em um círculo com cor de fundo suave
                Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.3)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.3)),
                    ],
                  ),
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