import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/login_page.dart';
import 'pages/base_layout.dart'; // Início | Relatos | + | Perfil
import 'pages/relatos_form_page.dart';
import 'pages/dto_form_page.dart';
import 'pages/dto_page.dart'; // tela de DTO (consulta) que ficava na barra antiga
import 'pages/gsd_page.dart';
import 'pages/gsa_page.dart';
import 'pages/gsp_page.dart';
import 'pages/gestao_usuarios_page.dart';
import 'pages/splash.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TemaApp.carregar(); // tema escolhido no Perfil (Automático / Claro / Escuro)
  runApp(const AppSeguranca());
}

class AppSeguranca extends StatelessWidget {
  const AppSeguranca({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: TemaApp.modo,
      builder: (context, modo, _) => MaterialApp(
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

      // Visual centralizado em lib/theme/app_theme.dart
      theme: AppTheme.claro(),
      darkTheme: AppTheme.escuro(),
      themeMode: modo,
      themeAnimationDuration: Duration.zero,
      builder: TemaApp.sincronizar,
      locale: const Locale('pt', 'BR'),

      // O aplicativo inicia SEMPRE na SplashScreen
      home: const SplashScreen(),

      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const BaseLayout(),
        '/novo_relato': (context) => const RelatosFormPage(),
        '/novo_dto': (context) => const DtoFormPage(),
        '/dto': (context) => const DtoPage(),
        '/gsd': (context) => const GsdPage(),
        '/gsa': (context) => const GsaPage(),
        '/gsp': (context) => const GspPage(),
        '/usuarios': (context) => const GestaoUsuariosPage(),
      },
      ),
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
