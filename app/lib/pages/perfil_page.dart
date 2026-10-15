import 'package:flutter/material.dart';
import '../widgets/comum.dart';
import '../services/api.dart';

// =====================================================
// Perfil do Usuário
// =====================================================
class PerfilPage extends StatelessWidget {
  final Sessao sessao;
  const PerfilPage({super.key, required this.sessao});

  String get _iniciais {
    final partes = sessao.nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
    return (partes.first.substring(0, 1) + partes.last.substring(0, 1)).toUpperCase();
  }

  String _campo(List<String> chaves) {
    for (final c in chaves) {
      final v = (sessao.bruto[c] ?? '').toString().trim();
      if (v.isNotEmpty && v != '-') return v;
    }
    return '-';
  }

  Future<void> _sair(BuildContext context) async {
    final ok = await confirmar(context, 'Sair da conta', 'Deseja realmente sair?', ok: 'Sair');
    if (!ok) return;
    await Sessao.sair();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perfilTxt = sessao.perfil.toUpperCase();
    final corPerfil = sessao.perfil == 'admin'
        ? const Color(0xFF991B1B)
        : (sessao.perfil == 'tecnico' ? const Color(0xFF3730A3) : const Color(0xFF475569));

    return Scaffold(
      appBar: AppBar(title: const Text('Meu Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: const Color(0xFF2563EB),
                child: Text(_iniciais,
                    style: const TextStyle(fontSize: 30, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              Text(sessao.nome,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 6),
              Etiqueta(perfilTxt, cor: corPerfil),
            ]),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Column(children: [
              _linha(Icons.badge_outlined, 'Cargo', sessao.cargo.isEmpty ? '-' : sessao.cargo),
              const Divider(height: 1),
              _linha(Icons.business_outlined, 'UNB', _campo(['unb', 'UNB'])),
              const Divider(height: 1),
              _linha(Icons.groups_outlined, 'Líder', _campo(['lider', 'Lider'])),
              const Divider(height: 1),
              _linha(Icons.email_outlined, 'E-mail', _campo(['email', 'Email'])),
              if (sessao.perfil == 'tecnico') ...[
                const Divider(height: 1),
                _linha(Icons.security_outlined, 'Acesso administrativo', sessao.acessoAdmin ? 'Sim' : 'Não'),
              ],
            ]),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Column(children: [
              _linha(Icons.info_outline, 'Versão do app', '1.0.1'),
              const Divider(height: 1),
              _linha(Icons.dns_outlined, 'Servidor', Api.baseUrl),
            ]),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              onPressed: () => _sair(context),
              icon: const Icon(Icons.logout),
              label: const Text('Sair da conta', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _linha(IconData icone, String label, String valor) {
    return ListTile(
      leading: Icon(icone, color: const Color(0xFF64748B)),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      subtitle: Text(valor, style: const TextStyle(fontSize: 15, color: Color(0xFF0F172A))),
    );
  }
}
