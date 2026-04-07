import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/set_password_screen.dart'; 
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/dashboard/team_overview_screen.dart';
import '../../features/dashboard/main_navigation_screen.dart';
import '../../features/help_requests/help_requests_screen.dart';
import '../../features/client_manage/add_client_screen.dart';
import '../../features/client_manage/client_list_screen.dart';
import '../../features/dashboard/role_decider_screen.dart';

// 1. Controle de Estado do Convite (Riverpod 2.x)
class InviteLinkNotifier extends Notifier<bool> {
  @override
  bool build() {
    final currentUrl = Uri.base.toString();
    return currentUrl.contains('access_token') || currentUrl.contains('type=invite');
  }

  void disable() {
    state = false;
  }
}

final inviteLinkProvider = NotifierProvider<InviteLinkNotifier, bool>(InviteLinkNotifier.new);

// 2. Inteligência de Autenticação
class AuthNotifier extends Notifier<bool> {
  @override
  bool build() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.passwordRecovery) {
        state = true;
      } else if (event == AuthChangeEvent.signedOut) {
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

final authStateProvider = NotifierProvider<AuthNotifier, bool>(AuthNotifier.new);

// 3. O Roteador Dinâmico
final goRouterProvider = Provider<GoRouter>((ref) {
  final isLoggedIn = ref.watch(authStateProvider);
  final isInvite = ref.watch(inviteLinkProvider);

  return GoRouter(
    initialLocation: '/login', 
    
    redirect: (BuildContext context, GoRouterState state) {
      final isGoingToLogin = state.matchedLocation == '/login';
      final isGoingToSetPassword = state.matchedLocation == '/set-password';

      // REGRA: Se for um convite válido, prende na tela de senha.
      if (isInvite) {
        if (!isGoingToSetPassword) return '/set-password';
        return null;
      }

      // FLUXO NORMAL DO SISTEMA
      if (!isLoggedIn && !isGoingToLogin) {
        return '/login';
      }
      
      if (isLoggedIn && isGoingToLogin) {
        return '/role-decider'; 
      }

      return null;
    },
    
    routes: [
      GoRoute(path: '/login', name: 'login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/set-password', name: 'set-password', builder: (context, state) => const SetPasswordScreen()),
      GoRoute(path: '/dashboard', name: 'dashboard', builder: (context, state) => const DashboardScreen()),
      GoRoute(path: '/add-client', name: 'add-client', builder: (context, state) => const AddClientScreen()),
      GoRoute(path: '/help-requests', name: 'help-requests', builder: (context, state) => const HelpRequestsScreen()),
      GoRoute(path: '/team-overview', name: 'team-overview', builder: (context, state) => const TeamOverviewScreen()),
      GoRoute(path: '/client-list/:category', name: 'client-list', builder: (context, state) {
        final category = state.pathParameters['category'] ?? 'current';
        return ClientListScreen(category: category);
      }),
      GoRoute(path: '/main-navigation', name: 'main-navigation', builder: (context, state) => const MainNavigationScreen()),
      GoRoute(path: '/role-decider', name: 'role-decider', builder: (context, state) => const RoleDeciderScreen()),
    ],
  );
});