import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/login_page.dart';
import 'pages/base_layout.dart'; // Início | Relatos | + | Perfil
import 'pages/relatos_form_page.dart';
import 'pages/dto_form_page.dart';
import 'pages/gsd_page.dart';
import 'pages/gsa_page.dart';
import 'pages/gsp_page.dart';
import 'pages/gestao_usuarios_page.dart';
import 'pages/splash.dart';

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

      // O aplicativo inicia SEMPRE na SplashScreen
      home: const SplashScreen(),

      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const BaseLayout(),
        '/novo_relato': (context) => const RelatosFormPage(),
        '/novo_dto': (context) => const DtoFormPage(),
        '/gsd': (context) => const GsdPage(),
        '/gsa': (context) => const GsaPage(),
        '/gsp': (context) => const GspPage(),
        '/usuarios': (context) => const GestaoUsuariosPage(),
      },
    );
  }
}

/// Guarda de Rota: verifica o login salvo antes de abrir a tela
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

    // REMOVIDO: await prefs.clear();
    // Ele apagava o login salvo e obrigava a logar toda vez que esta tela fosse usada.

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
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
