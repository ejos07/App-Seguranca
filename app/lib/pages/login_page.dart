import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http; // Adicione no pubspec: flutter pub add http
import '../services/api.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Equivalente ao useState('') para os inputs
  final TextEditingController _cpfController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _novaSenhaController = TextEditingController();
  final TextEditingController _confirmaSenhaController = TextEditingController();

  // Estados de controle da interface
  bool _modoTrocaSenha = false;
  String _erro = '';
  bool _isLoading = false;


  Future<void> _handleLogin() async {
    setState(() {
      _erro = '';
      _isLoading = true;
    });

    try {
      final cpfLimpo = _cpfController.text.replaceAll(RegExp(r'\D'), '');
      
      final response = await Api.post('/login', {
        'cpf': cpfLimpo,
        'senha': _senhaController.text
      });

      // IMPRESSÃO DE DEBUG: Mostra o que o FastAPI realmente respondeu
      print('=== RESPOSTA DO SERVIDOR (LOGIN) ===');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      print('====================================');

      // Proteção arquitetural Mobile: Só tenta converter JSON se o status for de sucesso (2xx)
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'sucesso') {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('usuario', jsonEncode(data['usuario']));
          
          if (!mounted) return;
          // CORREÇÃO: A rota configurada no main.dart agora é '/home'
          Navigator.pushReplacementNamed(context, '/home');
        } else if (data['status'] == 'precisa_trocar_senha') {
          setState(() => _modoTrocaSenha = true);
        } else {
          setState(() => _erro = data['detail'] ?? 'Erro ao efetuar login.');
        }
      } else {
        // Se o servidor retornar 404, 422, etc., tenta ler o erro do FastAPI
        try {
          final errorData = jsonDecode(response.body);
          setState(() => _erro = errorData['detail'] ?? 'Credenciais inválidas ou erro no servidor.');
        } catch (_) {
          setState(() => _erro = 'Erro no servidor (Status: ${response.statusCode}).');
        }
      }
    } catch (e) {
      // Agora isto só captura erros reais (ex: código quebrado na UI) e não erros de rede silenciados
      print('ERRO INTERNO NO LOGIN: $e');
      setState(() => _erro = 'Falha interna na aplicação.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAtualizarSenha() async {
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
      final cpfLimpo = _cpfController.text.replaceAll(RegExp(r'\D'), '');
      final response = await Api.post('/atualizar_senha', {
        'cpf': cpfLimpo,
        'nova_senha': _novaSenhaController.text
      });

      print('=== RESPOSTA DO SERVIDOR (TROCA SENHA) ===');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'sucesso') {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('usuario', jsonEncode(data['usuario']));
          
          if (!mounted) return;
          // CORREÇÃO: A rota configurada no main.dart agora é '/home'
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          setState(() => _erro = data['detail'] ?? 'Erro ao atualizar a senha.');
        }
      } else {
        setState(() => _erro = 'Erro no servidor (Status: ${response.statusCode}).');
      }
    } catch (e) {
      print('ERRO INTERNO NA TROCA DE SENHA: $e');
      setState(() => _erro = 'Falha interna na aplicação.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    // Limpeza de memória dos controllers (Boas práticas Mobile)
    _cpfController.dispose();
    _senhaController.dispose();
    _novaSenhaController.dispose();
    _confirmaSenhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // SafeArea protege a UI do entalhe da câmera e barra de status do celular
      body: SafeArea(
        child: Center(
          // SingleChildScrollView evita que o teclado virtual esmague o layout
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _modoTrocaSenha ? _buildTrocaSenhaForm() : _buildLoginForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '🛡️ App Segurança',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        
        if (_erro.isNotEmpty) _buildErrorCard(),

        // Label + Input de CPF
        const Text('CPF (Somente números)', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: _cpfController,
          // Força o teclado numérico nativo a abrir
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.person, color: Colors.grey),
            hintText: 'Ex: 12345678900',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Color(0xFFF8FAFC),
          ),
        ),
        const SizedBox(height: 16),

        // Label + Input de Senha
        const Text('Senha', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: _senhaController,
          obscureText: true, // Substitui type="password"
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.lock, color: Colors.grey),
            hintText: 'Sua senha',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Color(0xFFF8FAFC),
          ),
        ),
        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: _isLoading ? null : _handleLogin,
          child: _isLoading 
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
            : const Text('Entrar'),
        ),
      ],
    );
  }

  Widget _buildTrocaSenhaForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '⚠️ Nova Senha',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.orange),
        ),
        const SizedBox(height: 8),
        const Text(
          'Defina a sua nova senha de acesso pessoal.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 24),

        if (_erro.isNotEmpty) _buildErrorCard(),

        const Text('Nova Senha', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: _novaSenhaController,
          obscureText: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.vpn_key, color: Colors.grey),
            hintText: 'Mínimo 4 caracteres',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),

        const Text('Confirme a Nova Senha', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: _confirmaSenhaController,
          obscureText: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.vpn_key, color: Colors.grey),
            hintText: 'Repita a senha',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),

        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          onPressed: _isLoading ? null : _handleAtualizarSenha,
          child: _isLoading 
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
            : const Text('Salvar e Entrar'),
        ),
      ],
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        border: Border.all(color: const Color(0xFFFECACA)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _erro,
        style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}