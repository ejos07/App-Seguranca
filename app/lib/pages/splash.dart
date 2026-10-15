import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Importe as telas para onde a splash pode redirecionar
import 'login_page.dart'; 
import 'base_layout.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;
  bool _navigated = false; 

  @override
  void initState() {
    super.initState();
    
    // AQUI FOI ALTERADO PARA O NOME EXATO DO SEU VÍDEO
    _controller = VideoPlayerController.asset('assets/animacao-splash.mp4')
      ..initialize().then((_) {
        setState(() {});
        _controller.setVolume(0.0); 
        _controller.play();
      });

    _controller.addListener(() {
      if (_controller.value.isInitialized &&
          !_controller.value.isPlaying &&
          _controller.value.duration == _controller.value.position) {
            
        if (!_navigated) {
          _navigated = true;
          _checkSessionAndNavigate();
        }
      }
    });
  }

  Future<void> _checkSessionAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.clear(); 
    
    final usuario = prefs.getString('usuario');

    if (mounted) {
      Widget proximaTela = (usuario != null && usuario.isNotEmpty) 
          ? const BaseLayout() 
          : const LoginPage();

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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Se precisar, mude essa cor para combinar com o fundo do seu vídeo
      backgroundColor: const Color.fromARGB(255, 255, 255, 255), 
      body: Center(
        child: _controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}