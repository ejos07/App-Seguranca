import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

// =====================================================
// Splash com o vídeo assets/animacao-splash.mp4
// - Fundo branco igual ao da splash nativa (#FFFFFF)
// - O vídeo é levemente ampliado e recortado (ClipRect) para esconder a
//   linha de 1-2 px que o encoder (H.264) deixa na borda do quadro.
// - Ao terminar: vai para /home se houver login salvo, senão /login.
// =====================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Se ainda aparecer a linha, aumente um pouco (ex.: 1.06)
  static const double _zoomBorda = 1.04;
  static const Duration _tempoMaximo = Duration(seconds: 8);

  late final VideoPlayerController _video;
  bool _pronto = false;
  bool _navegou = false;
  Timer? _seguranca;

  @override
  void initState() {
    super.initState();
    _video = VideoPlayerController.asset('assets/animacao-splash.mp4');
    _iniciar();
    // Se o vídeo travar ou não carregar, segue mesmo assim
    _seguranca = Timer(_tempoMaximo, _seguir);
  }

  Future<void> _iniciar() async {
    try {
      await _video.initialize();
      await _video.setVolume(0);
      if (!mounted) return;
      setState(() => _pronto = true);
      _video.addListener(_aoAtualizarVideo);
      await _video.play();
    } catch (e) {
      debugPrint('Splash: erro no vídeo -> $e');
      _seguir();
    }
  }

  void _aoAtualizarVideo() {
    final v = _video.value;
    if (v.isInitialized && !v.isPlaying && v.position >= v.duration - const Duration(milliseconds: 150)) {
      _seguir();
    }
  }

  Future<void> _seguir() async {
    if (_navegou) return;
    _navegou = true;
    _seguranca?.cancel();

    final prefs = await SharedPreferences.getInstance();
    final usuario = prefs.getString('usuario');
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      (usuario != null && usuario.isNotEmpty) ? '/home' : '/login',
    );
  }

  @override
  void dispose() {
    _seguranca?.cancel();
    _video.removeListener(_aoAtualizarVideo);
    _video.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: _pronto
            ? ClipRect(
                child: AspectRatio(
                  aspectRatio: _video.value.aspectRatio,
                  child: Transform.scale(
                    scale: _zoomBorda,
                    child: VideoPlayer(_video),
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
