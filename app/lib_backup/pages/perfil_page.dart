import 'package:flutter/material.dart';
import '../widgets/comum.dart';
import '../services/api.dart';

// =====================================================
// Perfil do Usuário
// UNB / Líder / E-mail vêm do backend (/api/perfil), que procura o
// colaborador nos arquivos rzt/mb/bv_func_workplace:
//   rzt = RIZATTI | mb = MINASBEB | bv = BEVALE | Líder = coluna AC
// =====================================================
class PerfilPage extends StatefulWidget {
  final Sessao sessao;
  const PerfilPage({super.key, required this.sessao});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  bool _carregando = true;
  String _unb = '';
  String _lider = '';
  String _email = '';
  String _cargoRh = '';

  Sessao get _s => widget.sessao;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  /// CPF salvo no login (o nome da chave pode variar)
  String get _cpf {
    for (final c in ['cpf', 'CPF', 'documento', 'Documento', 'Senha_Atual (Documento)']) {
      final v = (_s.bruto[c] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  String _local(List<String> chaves) {
    for (final c in chaves) {
      final v = (_s.bruto[c] ?? '').toString().trim();
      if (v.isNotEmpty && v != '-') return v;
    }
    return '';
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final q = 'nome=${Uri.encodeQueryComponent(_s.nome)}&cpf=${Uri.encodeQueryComponent(_cpf)}';
      final r = await apiGet('/api/perfil?$q');
      final j = respostaOk(r) ? decodificar(r) : null;
      if (!mounted) return;
      setState(() {
        if (j is Map) {
          _unb = (j['unb'] ?? '').toString();
          _lider = (j['lider'] ?? '').toString();
          _email = (j['email'] ?? '').toString();
          _cargoRh = (j['cargo'] ?? '').toString();
        }
      });
    } catch (e) {
      debugPrint('Perfil: $e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  String _mostrar(String doServidor, List<String> chavesLocais) {
    if (doServidor.trim().isNotEmpty) return doServidor;
    final local = _local(chavesLocais);
    if (local.isNotEmpty) return local;
    return _carregando ? 'Carregando...' : '-';
  }

  Future<void> _sair() async {
    final ok = await confirmar(context, 'Sair da conta', 'Deseja realmente sair?', ok: 'Sair');
    if (!ok) return;
    await Sessao.sair();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final corPerfil = _s.perfil == 'admin'
        ? const Color(0xFF991B1B)
        : (_s.perfil == 'tecnico' ? const Color(0xFF3730A3) : const Color(0xFF475569));
    final cargo = _s.cargo.isNotEmpty ? _s.cargo : _cargoRh;

    return Scaffold(
      appBar: AppBar(title: const Text('Meu Perfil')),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Column(children: [
                FotoPerfil(nome: _s.nome, raio: 48),
                const SizedBox(height: 12),
                Text(_s.nome,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 6),
                Etiqueta(_s.perfil.toUpperCase(), cor: corPerfil),
              ]),
            ),
            const SizedBox(height: 24),
            _cartao([
              _linha(Icons.badge_outlined, 'Cargo', cargo.isEmpty ? '-' : cargo),
              _linha(Icons.business_outlined, 'UNB', _mostrar(_unb, ['unb', 'UNB'])),
              _linha(Icons.groups_outlined, 'Líder', _mostrar(_lider, ['lider', 'Lider'])),
              _linha(Icons.email_outlined, 'E-mail', _mostrar(_email, ['email', 'Email'])),
              if (_s.perfil == 'tecnico')
                _linha(Icons.security_outlined, 'Acesso administrativo', _s.acessoAdmin ? 'Sim' : 'Não'),
            ]),
            const SizedBox(height: 16),
            _cartao([
              _linha(Icons.info_outline, 'Versão do app', kVersaoApp),
              _linha(Icons.dns_outlined, 'Servidor', Api.baseUrl),
            ]),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                onPressed: _sair,
                icon: const Icon(Icons.logout),
                label: const Text('Sair da conta', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartao(List<Widget> linhas) {
    final filhos = <Widget>[];
    for (var i = 0; i < linhas.length; i++) {
      if (i > 0) filhos.add(const Divider(height: 1));
      filhos.add(linhas.elementAt(i));
    }
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Column(children: filhos),
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
