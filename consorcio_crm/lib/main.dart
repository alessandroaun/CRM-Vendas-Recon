import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'core/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. EXTRAÇÃO BRUTA DA URL ANTES DO APLICATIVO NASCER
  final currentUrl = Uri.base.toString();
  String? extractedRefreshToken;
  final isInvite = currentUrl.contains('access_token') || currentUrl.contains('type=invite');

  // Captura o token oculto no fragmento da URL gerada pelo Supabase
  if (currentUrl.contains('#')) {
    final fragment = currentUrl.split('#')[1];
    final params = Uri.splitQueryString(fragment);
    extractedRefreshToken = params['refresh_token'];
  }

  // 2. INICIALIZAÇÃO DO SUPABASE (CORRIGINDO O CONFLITO PKCE)
  await Supabase.initialize(
    url: 'https://kygnotvsbigxitgoisds.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt5Z25vdHZzYmlneGl0Z29pc2RzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM0MTg3ODMsImV4cCI6MjA4ODk5NDc4M30.loedsWs65Ev1k725E6GrwMwg4TZLT-8Mrdvy8xPivjU',
    // Força o SDK a aceitar o formato de URL que o seu projeto está gerando
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );

  // 3. RECUPERAÇÃO MANUAL DA SESSÃO (A BALA DE PRATA)
  // Se o SDK falhar por qualquer motivo na Web, nós forçamos o login nos bastidores
  if (extractedRefreshToken != null) {
    try {
      await Supabase.instance.client.auth.setSession(extractedRefreshToken);
    } catch (e) {
      debugPrint('Erro ao forçar sessão manual: $e');
    }
  }

  // 4. PAUSA E LIMPEZA DA URL
  if (isInvite) {
    await Future.delayed(const Duration(milliseconds: 1500));
  }

  usePathUrlStrategy();
  await initializeDateFormatting('pt_BR', null);

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