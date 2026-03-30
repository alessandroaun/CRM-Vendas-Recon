import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/login_screen.dart';
// --- NOVO IMPORT: Tela de Senha ---
import '../../features/auth/set_password_screen.dart'; 
// ----------------------------------
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/dashboard/team_overview_screen.dart';
import '../../features/dashboard/main_navigation_screen.dart';
import '../../features/help_requests/help_requests_screen.dart';
import '../../features/client_manage/add_client_screen.dart';
import '../../features/client_manage/client_list_screen.dart';
import '../../features/dashboard/role_decider_screen.dart';

// 1. A Inteligência de Autenticação REAL conectada ao Supabase
class AuthNotifier extends Notifier<bool> {
  // <-- NOVA VARIÁVEL: Avisa o roteador que é hora de criar a senha
  bool isSettingPassword = false;

  @override
  bool build() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      
      if (event == AuthChangeEvent.passwordRecovery) {
        // Clicou no link do e-mail!
        isSettingPassword = true; 
        state = true; // Aciona o roteador
      } else if (event == AuthChangeEvent.signedIn) {
        state = true;
      } else if (event == AuthChangeEvent.signedOut) {
        // Ao deslogar, reseta tudo
        isSettingPassword = false;
        state = false;
      }
    });

    return Supabase.instance.client.auth.currentSession != null;
  }

  Future<void> login(String email, String password) async {
    await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
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
  final authNotifier = ref.read(authStateProvider.notifier); // <-- Puxando as infos do Notifier

  return GoRouter(
    initialLocation: '/login',
    
    redirect: (BuildContext context, GoRouterState state) {
      final isGoingToLogin = state.matchedLocation == '/login';
      final isGoingToSetPassword = state.matchedLocation == '/set-password';

      // 1. MAGIA AQUI: O usuário clicou no e-mail? Trava ele na tela de senha!
      if (authNotifier.isSettingPassword) {
        if (!isGoingToSetPassword) return '/set-password';
        return null; // Já está na tela certa, deixa passar
      }

      // 2. Não está logado e tentou acessar tela restrita? Vai pro login
      if (!isLoggedIn && !isGoingToLogin) {
        return '/login';
      }
      
      // 3. Está logado normalmente e abriu a tela de login? Vai pro sistema
      if (isLoggedIn && isGoingToLogin) {
        return '/role-decider'; 
      }

      return null;
    },
    
    routes: [
      // ... SUAS ROTAS CONTINUAM EXATAMENTE IGUAIS AQUI PARA BAIXO (Login, SetPassword, Dashboard, etc) ...
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      // --- NOVA ROTA: Configurar Senha ---
      GoRoute(
        path: '/set-password',
        name: 'set-password',
        builder: (context, state) => const SetPasswordScreen(),
      ),
      // -----------------------------------
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