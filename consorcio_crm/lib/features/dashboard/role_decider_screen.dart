import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/profile_provider.dart';
import 'main_navigation_screen.dart'; // Menu do Vendedor
import 'supervisor_navigation_screen.dart'; // Menu do Supervisor/Gerente
import 'admin_navigation_screen.dart'; // <-- NOVO: Menu do Administrativo

class RoleDeciderScreen extends ConsumerWidget {
  const RoleDeciderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
        error: (err, stack) => Center(child: Text('Erro de conexão: $err')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Perfil não encontrado. Fale com o suporte.'));
          }

          final role = profile.role;
          
          // 1. Administrativo vai para o menu restrito
          if (role == 'administrativo') {
            return AdminNavigationScreen();
          } 
          // 2. Gestão vai para o menu Master (que depois filtraremos internamente)
          else if (role == 'supervisor' || role == 'gerente' || role == 'diretor' || role == 'administrador') {
            return const SupervisorNavigationScreen(); 
          } 
          // 3. Vendedor vai para o menu Padrão
          else {
            return const MainNavigationScreen(); 
          }
        },
      ),
    );
  }
}