import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Importe as telas para onde a splash pode redirecionar (ajuste os caminhos se necessário)
import 'login_page.dart'; 
import 'base_layout.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final String _fullText = "ambev";
  String _displayedText = "";
  int _currentIndex = 0;
  Timer? _timer;
  
  bool _isFadingOut = false; 

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  void _startTyping() {
    _timer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (_currentIndex < _fullText.length) {
        setState(() {
          _displayedText += _fullText[_currentIndex];
          _currentIndex++;
        });
      } else {
        _timer?.cancel();
        
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            setState(() {
              _isFadingOut = true;
            });
          }
          
          // O tempo de fade é 600ms. Quando acabar, verificamos o login.
          Future.delayed(const Duration(milliseconds: 600), () async {
            
            // --- INÍCIO DA LÓGICA DE VALIDAÇÃO DE SESSÃO ---
            final prefs = await SharedPreferences.getInstance();
            
            // 1. FORÇA A LIMPEZA TOTAL DO DISCO (mantido do seu código original)
            await prefs.clear(); 
            
            final usuario = prefs.getString('usuario');
            // --- FIM DA LÓGICA ---

            if (mounted) {
              // Decide silenciosamente qual será a próxima tela
              Widget proximaTela = (usuario != null && usuario.isNotEmpty) 
                  ? const BaseLayout() 
                  : const LoginPage();

              // Aplica a sua transição Fade na tela escolhida
              Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => proximaTela,
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 800),
                ),
              );
            }
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00448C), 
      body: Center(
        child: AnimatedOpacity(
          opacity: _isFadingOut ? 0.0 : 1.0, 
          duration: const Duration(milliseconds: 600), 
          curve: Curves.easeOut, 
          child: Text(
            _displayedText,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 70.0,
              fontWeight: FontWeight.w700,
              letterSpacing: -2.5,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}