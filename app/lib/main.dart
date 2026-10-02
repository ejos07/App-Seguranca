import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/login_page.dart';
import 'pages/base_layout.dart'; // Contém a BottomNavigationBar (Relatos + DTO)
import 'pages/relatos_form_page.dart';
import 'pages/dto_form_page.dart';
import 'pages/splash.dart'; // <-- IMPORTANTE: Importe o arquivo da sua tela de splash

void main() {
  runApp(const AppSeguranca());
}

class AppSeguranca extends StatelessWidget {
  const AppSeguranca({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Segurança',
      debugShowCheckedModeBanner: false,
      
      // Configuração de localização (Padrão Brasileiro)
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],

      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        primaryColor: const Color(0xFF2563EB),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          error: const Color(0xFFB91C1C),
        ),
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      
      // O aplicativo inicia SEMPRE na SplashScreen agora
      home: const SplashScreen(),
      
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const BaseLayout(),
        '/novo_relato': (context) => RelatosFormPage(),
        '/novo_dto': (context) => const DtoFormPage(),
      },
    );
  }
}

/// Guarda de Rota: Verifica o armazenamento local antes de renderizar a tela
class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  @override
  void initState() {
    super.initState();
    _verificarSessao();
  }

  Future<void> _verificarSessao() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. FORÇA A LIMPEZA TOTAL DO DISCO (Destrói o Auto Backup do Android)
    await prefs.clear(); 

    final usuario = prefs.getString('usuario');

    if (!mounted) return;

    if (usuario != null && usuario.isNotEmpty) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tela de carregamento nativa exibida milissegundos antes da decisão de rota
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}