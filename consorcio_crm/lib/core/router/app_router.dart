import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/login_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/dashboard/team_overview_screen.dart';
import '../../features/dashboard/main_navigation_screen.dart';
import '../../features/help_requests/help_requests_screen.dart';
import '../../features/client_manage/add_client_screen.dart';
import '../../features/client_manage/client_list_screen.dart';
import '../../features/dashboard/role_decider_screen.dart';

// 1. A Inteligência de Autenticação REAL conectada ao Supabase
class AuthNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Escuta as mudanças de sessão do Supabase em tempo real
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        state = true; // Logou
      } else if (event == AuthChangeEvent.signedOut) {
        state = false; // Deslogou
      }
    });

    // Ao abrir o app, verifica se já existe uma sessão salva
    return Supabase.instance.client.auth.currentSession != null;
  }

  // Método real de login se comunicando com o backend (Future<void>)
  Future<void> login(String email, String password) async {
    await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();
  }
}

// Criando o provider de autenticação
final authStateProvider = NotifierProvider<AuthNotifier, bool>(AuthNotifier.new);

// 2. O Roteador Dinâmico
final goRouterProvider = Provider<GoRouter>((ref) {
  final isLoggedIn = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    
    redirect: (BuildContext context, GoRouterState state) {
      final isGoingToLogin = state.matchedLocation == '/login';

      if (!isLoggedIn && !isGoingToLogin) {
        return '/login';
      }
      
      // MUDANÇA AQUI: Agora o app redireciona para o novo esqueleto de navegação após o login
      if (isLoggedIn && isGoingToLogin) {
        return '/role-decider'; 
      }

      return null;
    },
    
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/dashboard', // Mantivemos a rota antiga caso precise acessar diretamente
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/add-client',
        name: 'add-client',
        builder: (context, state) => const AddClientScreen(),
      ),
      GoRoute(
        path: '/help-requests',
        name: 'help-requests',
        builder: (context, state) => const HelpRequestsScreen(),
      ),
      GoRoute(
        path: '/team-overview',
        name: 'team-overview',
        builder: (context, state) => const TeamOverviewScreen(),
      ),
      // Rota dinâmica que aceita a categoria do funil de vendas
      GoRoute(
        path: '/client-list/:category',
        name: 'client-list',
        builder: (context, state) {
          final category = state.pathParameters['category'] ?? 'current';
          return ClientListScreen(category: category);
        },
      ),
      // NOVA ROTA: O Esqueleto principal com o menu inferior
      GoRoute(
        path: '/main-navigation',
        name: 'main-navigation',
        builder: (context, state) => const MainNavigationScreen(),
      ),
      GoRoute(
        path: '/role-decider',
        name: 'role-decider',
        builder: (context, state) => const RoleDeciderScreen(),
      ),
    ],
  );
});