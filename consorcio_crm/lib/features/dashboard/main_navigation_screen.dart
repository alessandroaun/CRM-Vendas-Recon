import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_performance_screen.dart';
import '../client_manage/add_client_screen.dart';
import '../client_manage/funnel_screen.dart';
import '../notifications/notifications_screen.dart';
import '../settings/settings_screen.dart';

// Ajuste esse import se o caminho do seu admin_panel_screen for diferente!
import '../auth/admin_panel_screen.dart'; 

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _currentIndex = 0;
  
  // Variáveis para o controle de acesso
  String? _userRole;
  bool _isLoadingRole = true;

  final List<Widget> _screens = const [
    HomePerformanceScreen(),
    AddClientScreen(),      
    FunnelScreen(),         
    NotificationsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  // Busca o cargo do usuário atual diretamente do banco de dados ao iniciar
  Future<void> _fetchUserRole() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final response = await Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq('id', userId)
            .single();
        
        if (mounted) {
          setState(() {
            _userRole = response['role'] as String?;
            _isLoadingRole = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingRole = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRole = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Tela de carregamento rápido enquanto descobre o cargo
    if (_isLoadingRole) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F7FE),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
      );
    }

    // 2. O BLOQUEIO: Se for administrativo, mostra APENAS o Centro de Comando
    if (_userRole == 'administrativo') {
      return const AdminPanelScreen();
    }

    // 3. Se for vendedor, supervisor, gerente, diretor ou administrador... carrega o app normal!
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), 
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              elevation: 0,
              selectedItemColor: const Color(0xFF4F46E5),
              unselectedItemColor: const Color(0xFF94A3B8),
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.person_add_rounded), label: 'Cadastrar'),
                BottomNavigationBarItem(icon: Icon(Icons.view_kanban_rounded), label: 'Funil'),
                BottomNavigationBarItem(icon: Icon(Icons.notifications_rounded), label: 'Avisos'),
                BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Ajustes'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}