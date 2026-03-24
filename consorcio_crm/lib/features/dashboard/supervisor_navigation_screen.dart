import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Importação necessária

import '../settings/settings_screen.dart'; 
import 'team_overview_screen.dart';
import 'team_funnel_screen.dart'; 
import 'team_demands_screen.dart';
import 'updates_screen.dart';

// --- PROVEDOR DE NOTIFICAÇÕES DO GESTOR ---
final unreadSupervisorProvider = StreamProvider.autoDispose<int>((ref) {
  return Supabase.instance.client.from('clients').stream(primaryKey: ['id'])
      .eq('is_help_mode', true)
      .map((list) => list.fold(0, (sum, item) => sum + (item['unread_supervisor'] as int? ?? 0)));
});

class SupervisorNavigationScreen extends ConsumerStatefulWidget {
  const SupervisorNavigationScreen({super.key});

  @override
  ConsumerState<SupervisorNavigationScreen> createState() => _SupervisorNavigationScreenState();
}

class _SupervisorNavigationScreenState extends ConsumerState<SupervisorNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    TeamOverviewScreen(), 
    TeamFunnelScreen(), 
    TeamDemandsScreen(), 
    UpdatesScreen(), // <-- NOVA TELA ADICIONADA AQUI
    SettingsScreen(), 
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, -5))]),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white, 
              elevation: 0,
              selectedItemColor: const Color(0xFFF59E0B),
              unselectedItemColor: const Color(0xFF94A3B8),
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: -0.5),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 10, letterSpacing: -0.5),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Equipe'),
                BottomNavigationBarItem(icon: Icon(Icons.account_tree_rounded), label: 'Funil Geral'),
                BottomNavigationBarItem(
                  icon: NotificationBadge(icon: Icons.support_agent_rounded), 
                  label: 'Demandas'
                ),
                // --- NOVO ÍCONE DA ABA DE ATUALIZAÇÕES ---
                BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'Atualizações'),
                BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Ajustes'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- WIDGET DO SINO COM A BOLINHA VERMELHA (GESTOR) ---
class NotificationBadge extends ConsumerWidget {
  final IconData icon;

  const NotificationBadge({super.key, required this.icon});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(unreadSupervisorProvider);

    return countAsync.when(
      data: (count) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, size: 26),
            if (count > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Center(
                    child: Text(
                      count > 99 ? '99+' : count.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => Icon(icon, size: 26),
      error: (_, __) => Icon(icon, size: 26),
    );
  }
}