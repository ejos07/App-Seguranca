import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =====================================================
// DESIGN SYSTEM DO APP (tema claro + escuro)
// Para mudar a identidade visual (ex.: cores da marca), altere SÓ este arquivo.
//
// Cores de MARCA e STATUS são fixas (const).
// Cores NEUTRAS (fundo, superfície, borda, texto) mudam com o tema:
// leia sempre AppCores.xxx dentro do build() — nunca guarde em const.
// =====================================================

class AppCores {
  AppCores._();

  /// Ligado automaticamente pelo MaterialApp (ver main.dart -> builder)
  static bool escuro = false;

  // ---------- Marca (fixas) ----------
  static const Color primaria = Color(0xFF2563EB);
  static const Color primariaEscura = Color(0xFF1E3A8A);
  static const Color cabecalho = Color(0xFF0F172A); // AppBar / topo
  static const Color cabecalho2 = Color(0xFF1E293B);

  // ---------- Status (fixas) ----------
  static const Color sucesso = Color(0xFF10B981);
  static const Color alerta = Color(0xFFF59E0B);
  static const Color perigo = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  static const Color roxo = Color(0xFF7C3AED);
  static const Color ciano = Color(0xFF06B6D4);
  static const Color rosa = Color(0xFFEC4899);

  // ---------- Neutras: CLARO ----------
  static const Color _fundoC = Color(0xFFF1F5F9);
  static const Color _superficieC = Colors.white;
  static const Color _superficieSuaveC = Color(0xFFF8FAFC);
  static const Color _bordaC = Color(0xFFE2E8F0);
  static const Color _textoC = Color(0xFF0F172A);
  static const Color _textoSecC = Color(0xFF64748B);
  static const Color _textoSuaveC = Color(0xFF94A3B8);

  // ---------- Neutras: ESCURO ----------
  static const Color _fundoE = Color(0xFF0B1120);
  static const Color _superficieE = Color(0xFF141C2B);
  static const Color _superficieSuaveE = Color(0xFF1A2334);
  static const Color _bordaE = Color(0xFF263246);
  static const Color _textoE = Color(0xFFE5E9F0);
  static const Color _textoSecE = Color(0xFF9AA8BC);
  static const Color _textoSuaveE = Color(0xFF6B7A90);

  // ---------- Neutras: dinâmicas ----------
  static Color get fundo => escuro ? _fundoE : _fundoC;
  static Color get superficie => escuro ? _superficieE : _superficieC;
  static Color get superficieSuave => escuro ? _superficieSuaveE : _superficieSuaveC;
  static Color get borda => escuro ? _bordaE : _bordaC;
  static Color get texto => escuro ? _textoE : _textoC;
  static Color get textoSecundario => escuro ? _textoSecE : _textoSecC;
  static Color get textoSuave => escuro ? _textoSuaveE : _textoSuaveC;

  /// Fundo da AppBar
  static Color get barra => escuro ? const Color(0xFF0F1626) : cabecalho;

  /// Sombra leve dos cartões (some no escuro)
  static List<BoxShadow> get sombra => escuro
      ? const []
      : [BoxShadow(color: _textoC.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))];

  /// Fundo "tingido" para destaques coloridos (chips, ícones)
  static Color tinta(Color cor, [double forca = 0.12]) => cor.withOpacity(escuro ? forca + 0.08 : forca);

  /// Clareia cores escuras no tema escuro para o texto continuar legível
  static Color legivel(Color cor) => escuro ? (Color.lerp(cor, Colors.white, 0.45) ?? cor) : cor;

  static const LinearGradient gradienteMarca = LinearGradient(
    colors: [cabecalho, primariaEscura, primaria],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Paleta para gráficos (categorias)
  static const List<Color> paleta = [
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4),
    Color(0xFFEC4899),
    Color(0xFF84CC16),
  ];
}

class AppEspaco {
  AppEspaco._();
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRaio {
  AppRaio._();
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 20;
}

class AppTexto {
  AppTexto._();
  static TextStyle get tituloSecao =>
      TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppCores.texto, letterSpacing: -0.2);
  static TextStyle get tituloCard => TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppCores.texto);
  static TextStyle get corpo => TextStyle(fontSize: 14, color: AppCores.texto, height: 1.35);
  static TextStyle get legenda => TextStyle(fontSize: 12.5, color: AppCores.textoSecundario, height: 1.3);
  static TextStyle get rotulo => TextStyle(
      fontSize: 11, fontWeight: FontWeight.w700, color: AppCores.textoSecundario, letterSpacing: 0.6);
  static TextStyle get numeroGrande =>
      TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppCores.texto, height: 1.05, letterSpacing: -0.5);
}

// =====================================================
// PREFERÊNCIA DE TEMA (Sistema / Claro / Escuro) — salva no aparelho
// =====================================================
class TemaApp {
  TemaApp._();
  static const String _chave = 'tema_app';
  static final ValueNotifier<ThemeMode> modo = ValueNotifier<ThemeMode>(ThemeMode.system);

  static Future<void> carregar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      modo.value = _deTexto(prefs.getString(_chave));
    } catch (_) {}
  }

  static Future<void> definir(ThemeMode m) async {
    modo.value = m;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chave, m.name);
    } catch (_) {}
  }

  static ThemeMode _deTexto(String? s) {
    if (s == 'light') return ThemeMode.light;
    if (s == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  static String rotulo(ThemeMode m) {
    if (m == ThemeMode.light) return 'Claro';
    if (m == ThemeMode.dark) return 'Escuro';
    return 'Automático (sistema)';
  }

  static IconData icone(ThemeMode m) {
    if (m == ThemeMode.light) return Icons.light_mode_outlined;
    if (m == ThemeMode.dark) return Icons.dark_mode_outlined;
    return Icons.brightness_auto_outlined;
  }

  /// Usado no builder do MaterialApp: liga/desliga AppCores.escuro e
  /// redesenha as telas abertas (sem perder o que foi digitado).
  static Widget sincronizar(BuildContext context, Widget? child) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    if (escuro != AppCores.escuro) {
      AppCores.escuro = escuro;
      WidgetsBinding.instance.addPostFrameCallback((_) => _redesenharTudo());
    }
    return child ?? const SizedBox.shrink();
  }

  static void _redesenharTudo() {
    final raiz = WidgetsBinding.instance.rootElement;
    if (raiz == null) return;
    void marcar(Element e) {
      e.markNeedsBuild();
      e.visitChildren(marcar);
    }

    raiz.visitChildren(marcar);
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData claro() => _construir(false);
  static ThemeData escuro() => _construir(true);

  static ThemeData _construir(bool escuro) {
    // As cores neutras dependem do flag; calcula com o valor certo e restaura.
    final anterior = AppCores.escuro;
    AppCores.escuro = escuro;
    try {
      return _tema(escuro);
    } finally {
      AppCores.escuro = anterior;
    }
  }

  static ThemeData _tema(bool escuro) {
    final brilho = escuro ? Brightness.dark : Brightness.light;
    final fundo = AppCores.fundo;
    final superficie = AppCores.superficie;
    final borda = AppCores.borda;
    final texto = AppCores.texto;
    final textoSec = AppCores.textoSecundario;
    final textoSuave = AppCores.textoSuave;
    final primaria = escuro ? const Color(0xFF3B82F6) : AppCores.primaria;

    final esquema = ColorScheme.fromSeed(
      seedColor: AppCores.primaria,
      brightness: brilho,
      primary: primaria,
      error: AppCores.perigo,
      surface: superficie,
      onSurface: texto,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: esquema, brightness: brilho);

    // Inter via google_fonts (compatível com qualquer versão do pacote)
    final String? fonteInter = GoogleFonts.inter().fontFamily;
    final TextTheme textos = base.textTheme.apply(
      fontFamily: fonteInter,
      bodyColor: texto,
      displayColor: texto,
    );

    final bordaPadrao = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRaio.m),
      borderSide: BorderSide(color: borda),
    );

    return base.copyWith(
      primaryColor: primaria,
      scaffoldBackgroundColor: fundo,
      canvasColor: superficie,
      textTheme: textos,
      dividerColor: borda,
      dividerTheme: DividerThemeData(color: borda, thickness: 1, space: 1),

      appBarTheme: AppBarTheme(
        backgroundColor: AppCores.barra,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: Colors.white,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: escuro ? AppCores.superficieSuave : superficie,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: bordaPadrao,
        enabledBorder: bordaPadrao,
        disabledBorder: bordaPadrao,
        focusedBorder: bordaPadrao.copyWith(borderSide: BorderSide(color: primaria, width: 1.6)),
        errorBorder: bordaPadrao.copyWith(borderSide: const BorderSide(color: AppCores.perigo)),
        focusedErrorBorder: bordaPadrao.copyWith(borderSide: const BorderSide(color: AppCores.perigo, width: 1.6)),
        labelStyle: TextStyle(color: textoSec),
        floatingLabelStyle: TextStyle(color: primaria),
        hintStyle: TextStyle(color: textoSuave),
        prefixIconColor: textoSuave,
        suffixIconColor: textoSuave,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaria,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primaria.withOpacity(0.45),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRaio.m)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaria,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRaio.m)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: texto,
          minimumSize: const Size(44, 46),
          side: BorderSide(color: borda),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRaio.m)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaria,
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaria,
        foregroundColor: Colors.white,
        elevation: 2,
      ),

      cardTheme: CardThemeData(
        color: superficie,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRaio.l),
          side: BorderSide(color: borda),
        ),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: textoSec,
        collapsedIconColor: textoSuave,
        textColor: texto,
        collapsedTextColor: texto,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: superficie,
        selectedColor: primaria.withOpacity(escuro ? 0.25 : 0.12),
        side: BorderSide(color: borda),
        shape: const StadiumBorder(),
        labelStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: texto),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: escuro ? const Color(0xFF2A3548) : const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRaio.m)),
        contentTextStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: superficie,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRaio.xl)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: superficie,
        modalBackgroundColor: superficie,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRaio.xl))),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: superficie,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRaio.m),
          side: BorderSide(color: borda),
        ),
        textStyle: GoogleFonts.inter(fontSize: 14, color: texto),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: superficie,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AppCores.barra,
        headerForegroundColor: Colors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: superficie,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: primaria.withOpacity(escuro ? 0.25 : 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((estados) {
          final sel = estados.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
            color: sel ? primaria : textoSec,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((estados) {
          final sel = estados.contains(WidgetState.selected);
          return IconThemeData(color: sel ? primaria : textoSec);
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primaria),
      listTileTheme: ListTileThemeData(iconColor: textoSec, textColor: texto),
      iconTheme: IconThemeData(color: textoSec),
    );
  }
}
