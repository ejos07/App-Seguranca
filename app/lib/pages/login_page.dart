import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../services/api.dart';
import '../theme/app_theme.dart';

// =====================================================
// Login (mesma lógica de antes: /api/login e /api/atualizar_senha)
// =====================================================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _cpfController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _novaSenhaController = TextEditingController();
  final TextEditingController _confirmaSenhaController = TextEditingController();
  final FocusNode _focoSenha = FocusNode();

  // Aceita CPF com ou sem pontuação; o envio usa só os números
  final MaskTextInputFormatter _mascaraCpf =
      MaskTextInputFormatter(mask: '###.###.###-##', filter: {'#': RegExp(r'[0-9]')});

  bool _modoTrocaSenha = false;
  bool _mostrarSenha = false;
  bool _mostrarNovaSenha = false;
  String _erro = '';
  bool _isLoading = false;

  String get _cpfLimpo => _cpfController.text.replaceAll(RegExp(r'\D'), '');

  Future<void> _salvarUsuarioEEntrar(dynamic usuario) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('usuario', jsonEncode(usuario));
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  String _lerDetalhe(String corpo, String padrao) {
    try {
      final j = jsonDecode(corpo);
      if (j is Map && j['detail'] != null) return j['detail'].toString();
    } catch (_) {}
    return padrao;
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (_cpfLimpo.isEmpty || _senhaController.text.isEmpty) {
      setState(() => _erro = 'Informe o CPF e a senha.');
      return;
    }
    setState(() {
      _erro = '';
      _isLoading = true;
    });

    try {
      final response = await Api.post('/api/login', {'cpf': _cpfLimpo, 'senha': _senhaController.text});
      // Não imprime o corpo: ele contém dados pessoais do usuário
      debugPrint('LOGIN -> status ${response.statusCode}');
      final corpo = utf8.decode(response.bodyBytes);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(corpo);
        if (data['status'] == 'sucesso') {
          await _salvarUsuarioEEntrar(data['usuario']);
        } else if (data['status'] == 'precisa_trocar_senha') {
          setState(() => _modoTrocaSenha = true);
        } else {
          setState(() => _erro = (data['detail'] ?? 'Erro ao efetuar login.').toString());
        }
      } else {
        setState(() => _erro = _lerDetalhe(corpo, 'CPF ou senha inválidos (${response.statusCode}).'));
      }
    } catch (e) {
      debugPrint('ERRO NO LOGIN: $e');
      if (mounted) setState(() => _erro = 'Não foi possível conectar ao servidor. Verifique sua conexão.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAtualizarSenha() async {
    FocusScope.of(context).unfocus();
    setState(() => _erro = '');

    if (_novaSenhaController.text.length < 4) {
      setState(() => _erro = 'A senha precisa ter pelo menos 4 caracteres.');
      return;
    }
    if (_novaSenhaController.text != _confirmaSenhaController.text) {
      setState(() => _erro = 'As senhas não coincidem.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response =
          await Api.post('/api/atualizar_senha', {'cpf': _cpfLimpo, 'nova_senha': _novaSenhaController.text});
      debugPrint('TROCA SENHA -> status ${response.statusCode}');
      final corpo = utf8.decode(response.bodyBytes);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(corpo);
        if (data['status'] == 'sucesso') {
          await _salvarUsuarioEEntrar(data['usuario']);
        } else {
          setState(() => _erro = (data['detail'] ?? 'Erro ao atualizar a senha.').toString());
        }
      } else {
        setState(() => _erro = _lerDetalhe(corpo, 'Erro no servidor (${response.statusCode}).'));
      }
    } catch (e) {
      debugPrint('ERRO NA TROCA DE SENHA: $e');
      if (mounted) setState(() => _erro = 'Não foi possível conectar ao servidor. Verifique sua conexão.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _cpfController.dispose();
    _senhaController.dispose();
    _novaSenhaController.dispose();
    _confirmaSenhaController.dispose();
    _focoSenha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final altura = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: AppCores.fundo,
      body: SingleChildScrollView(
        child: Column(children: [
          // ---------- Topo com a marca ----------
          Container(
            width: double.infinity,
            height: altura * 0.36,
            decoration: const BoxDecoration(
              gradient: AppCores.gradienteMarca,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRaio.xl),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: Image.asset(
                    'assets/logo.png',
                    height: 56,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.health_and_safety, size: 56, color: AppCores.primaria),
                  ),
                ),
                const SizedBox(height: AppEspaco.l),
                const Text('App Segurança',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                const SizedBox(height: 4),
                Text('Relatos • DTO • GSD • GSA • GSP',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
              ]),
            ),
          ),

          // ---------- Cartão do formulário ----------
          Transform.translate(
            offset: const Offset(0, -36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppEspaco.xl),
              child: Container(
                padding: const EdgeInsets.all(AppEspaco.xl),
                decoration: BoxDecoration(
                  color: AppCores.superficie,
                  borderRadius: BorderRadius.circular(AppRaio.xl),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 24, offset: const Offset(0, 10)),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _modoTrocaSenha ? _buildTrocaSenhaForm() : _buildLoginForm(),
                ),
              ),
            ),
          ),
          Text('Grupo Rizatti • Segurança do Trabalho', style: AppTexto.legenda.copyWith(fontSize: 12)),
          const SizedBox(height: AppEspaco.xl),
        ]),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      key: const ValueKey('login'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Entrar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppCores.texto)),
        const SizedBox(height: 4),
        Text('Use seu CPF e senha de acesso.', style: AppTexto.legenda),
        const SizedBox(height: AppEspaco.xl),
        if (_erro.isNotEmpty) _buildErrorCard(),
        TextField(
          controller: _cpfController,
          keyboardType: TextInputType.number,
          inputFormatters: [_mascaraCpf],
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _focoSenha.requestFocus(),
          decoration: const InputDecoration(
            labelText: 'CPF',
            hintText: '000.000.000-00',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        const SizedBox(height: AppEspaco.l),
        TextField(
          controller: _senhaController,
          focusNode: _focoSenha,
          obscureText: !_mostrarSenha,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _isLoading ? null : _handleLogin(),
          decoration: InputDecoration(
            labelText: 'Senha',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              tooltip: _mostrarSenha ? 'Ocultar senha' : 'Mostrar senha',
              icon: Icon(_mostrarSenha ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => setState(() => _mostrarSenha = !_mostrarSenha),
            ),
          ),
        ),
        const SizedBox(height: AppEspaco.s),
        Text('Primeiro acesso? A senha inicial é o seu CPF (só números).',
            style: TextStyle(fontSize: 12, color: AppCores.textoSuave)),
        const SizedBox(height: AppEspaco.xl),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleLogin,
          child: _isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Entrar'),
        ),
      ],
    );
  }

  Widget _buildTrocaSenhaForm() {
    return Column(
      key: const ValueKey('troca'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppCores.alerta.withOpacity(0.15), borderRadius: BorderRadius.circular(AppRaio.m)),
            child: const Icon(Icons.key_outlined, color: AppCores.alerta),
          ),
          const SizedBox(width: AppEspaco.m),
          Expanded(
            child: Text('Crie sua senha', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppCores.texto)),
          ),
        ]),
        const SizedBox(height: AppEspaco.s),
        Text('No primeiro acesso, defina uma senha pessoal para entrar no app.', style: AppTexto.legenda),
        const SizedBox(height: AppEspaco.xl),
        if (_erro.isNotEmpty) _buildErrorCard(),
        TextField(
          controller: _novaSenhaController,
          obscureText: !_mostrarNovaSenha,
          decoration: InputDecoration(
            labelText: 'Nova senha',
            hintText: 'Mínimo 4 caracteres',
            prefixIcon: const Icon(Icons.lock_reset),
            suffixIcon: IconButton(
              icon: Icon(_mostrarNovaSenha ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => setState(() => _mostrarNovaSenha = !_mostrarNovaSenha),
            ),
          ),
        ),
        const SizedBox(height: AppEspaco.l),
        TextField(
          controller: _confirmaSenhaController,
          obscureText: !_mostrarNovaSenha,
          onSubmitted: (_) => _isLoading ? null : _handleAtualizarSenha(),
          decoration: const InputDecoration(
            labelText: 'Confirme a nova senha',
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        const SizedBox(height: AppEspaco.xl),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppCores.sucesso),
          onPressed: _isLoading ? null : _handleAtualizarSenha,
          child: _isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Salvar e entrar'),
        ),
        TextButton(
          onPressed: _isLoading
              ? null
              : () => setState(() {
                    _modoTrocaSenha = false;
                    _erro = '';
                  }),
          child: const Text('Voltar'),
        ),
      ],
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppEspaco.l),
      padding: const EdgeInsets.all(AppEspaco.m),
      decoration: BoxDecoration(
        color: AppCores.tinta(AppCores.perigo, 0.07),
        border: Border.all(color: AppCores.perigo.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(AppRaio.m),
      ),
      child: Row(children: [
        Icon(Icons.error_outline, color: AppCores.legivel(const Color(0xFFB91C1C)), size: 20),
        const SizedBox(width: AppEspaco.s),
        Expanded(
          child: Text(_erro,
              style: TextStyle(color: AppCores.legivel(const Color(0xFFB91C1C)), fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}
