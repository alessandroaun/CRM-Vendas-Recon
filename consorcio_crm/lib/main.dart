import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart'; // <-- NOVO IMPORT DO PACOTE INTL
import 'core/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // <-- NOVA LINHA: Carrega o idioma português para as datas
  await initializeDateFormatting('pt_BR', null);
  await Supabase.initialize(
    url: 'https://kygnotvsbigxitgoisds.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt5Z25vdHZzYmlneGl0Z29pc2RzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM0MTg3ODMsImV4cCI6MjA4ODk5NDc4M30.loedsWs65Ev1k725E6GrwMwg4TZLT-8Mrdvy8xPivjU',
  );

 runApp(
    const ProviderScope(
      child: ConsorcioCRMApp(),
    ),
  );
}

class ConsorcioCRMApp extends ConsumerWidget {
  const ConsorcioCRMApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'Portal Recon Premium',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F172A), 
          primary: const Color(0xFF0F172A),
          secondary: const Color(0xFFD97706), 
        ),
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        useMaterial3: true,
      ),
      routerConfig: router, 
    );
  }
}