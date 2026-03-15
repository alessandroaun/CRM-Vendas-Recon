import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_screen.dart'; 
import 'team_overview_screen.dart';
import 'team_funnel_screen.dart'; 
import 'team_demands_screen.dart';

class SupervisorNavigationScreen extends ConsumerStatefulWidget {
  const SupervisorNavigationScreen({super.key});

  @override
  ConsumerState<SupervisorNavigationScreen> createState() => _SupervisorNavigationScreenState();
}

class _SupervisorNavigationScreenState extends ConsumerState<SupervisorNavigationScreen> {
  int _currentIndex = 0;

  // Lista limpa com EXATAMENTE as 4 telas oficiais na ordem correta
  final List<Widget> _screens = const [
    TeamOverviewScreen(), 
    TeamFunnelScreen(), 
    TeamDemandsScreen(), 
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
              selectedItemColor: const Color(0xFFF59E0B), // Laranja do Supervisor
              unselectedItemColor: const Color(0xFF94A3B8),
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Equipe'),
                BottomNavigationBarItem(icon: Icon(Icons.account_tree_rounded), label: 'Funil Geral'),
                BottomNavigationBarItem(icon: Icon(Icons.support_agent_rounded), label: 'Demandas'),
                BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Ajustes'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}