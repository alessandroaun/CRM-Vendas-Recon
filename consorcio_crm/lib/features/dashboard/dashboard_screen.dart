import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // <--- O import que estava faltando!

import '../../core/router/app_router.dart';
import '../auth/profile_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Consórcio Recon'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () {
              ref.read(authStateProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A))),
        error: (error, stack) => Center(
          child: Text('Erro ao carregar dados: $error', style: const TextStyle(color: Colors.red)),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Perfil não encontrado.'));
          }

          final isSupervisor = profile.role == 'supervisor';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Olá, ${profile.fullName}',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                ),
                Text(
                  isSupervisor ? 'Painel da Supervisão - Filial Fortaleza' : 'Sua Carteira de Clientes',
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 32),

                if (isSupervisor) ...[
                  _buildMenuCard(
                    icon: Icons.notification_important_rounded,
                    iconColor: Colors.orange,
                    title: 'Pedidos de Ajuda',
                    subtitle: 'Vendedores precisando de apoio no fechamento',
                    onTap: () {
                      context.push('/help-requests');
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildMenuCard(
                    icon: Icons.people_alt_rounded,
                    iconColor: const Color(0xFF1E3A8A),
                    title: 'Visão Geral da Equipe',
                    subtitle: 'Acompanhe todas as negociações da filial',
                    onTap: () {
                      // Será implementado na visão do supervisor
                    },
                  ),
                ] else ...[
                  _buildMenuCard(
                    icon: Icons.person_add_alt_1_rounded,
                    iconColor: Colors.green,
                    title: 'Cadastrar Cliente',
                    subtitle: 'Adicionar nova prospecção de consórcio',
                    onTap: () {
                      context.push('/add-client'); // Agora o Flutter entende o que é isso!
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildMenuCard(
                    icon: Icons.list_alt_rounded,
                    iconColor: const Color(0xFF1E3A8A),
                    title: 'Minhas Negociações',
                    subtitle: 'Atualizar estágios e solicitar ajuda',
                    onTap: () {
                      context.push('/client-list'); // Já deixei pronto para a próxima tela
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 14, color: Colors.black54)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}