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
        ? const Color(0xFFFCA5A5)
        : (_s.perfil == 'tecnico' ? const Color(0xFFC7D2FE) : const Color(0xFFE2E8F0));
    final rotuloPerfil = _s.perfil == 'admin'
        ? 'ADMINISTRADOR'
        : (_s.perfil == 'tecnico' ? 'SEGURANÇA' : 'COLABORADOR');
    final cargo = _s.cargo.isNotEmpty ? _s.cargo : _cargoRh;

    return Scaffold(
      appBar: AppBar(title: const Text('Meu Perfil')),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppEspaco.l, AppEspaco.l, AppEspaco.l, AppEspaco.xxl),
          children: [
            CabecalhoMarca(
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.7), width: 2.5),
                  ),
                  child: FotoPerfil(nome: _s.nome, raio: 46),
                ),
                const SizedBox(height: AppEspaco.m),
                Text(_s.nome,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)),
                if (cargo.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(cargo,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.8))),
                ],
                const SizedBox(height: AppEspaco.m),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: corPerfil.withOpacity(0.6)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.verified_user_outlined, size: 14, color: corPerfil),
                    const SizedBox(width: 6),
                    Text(rotuloPerfil,
                        style: TextStyle(
                            color: corPerfil, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: AppEspaco.xl),
            _titulo('DADOS PROFISSIONAIS'),
            _cartao([
              _linha(Icons.badge_outlined, 'Cargo', cargo.isEmpty ? '-' : cargo),
              _linha(Icons.business_outlined, 'UNB', _mostrar(_unb, ['unb', 'UNB'])),
              _linha(Icons.supervisor_account_outlined, 'Líder', _mostrar(_lider, ['lider', 'Lider'])),
              _linha(Icons.alternate_email, 'E-mail', _mostrar(_email, ['email', 'Email'])),
              if (_s.perfil == 'tecnico')
                _linha(Icons.admin_panel_settings_outlined, 'Acesso administrativo', _s.acessoAdmin ? 'Sim' : 'Não'),
            ]),
            const SizedBox(height: AppEspaco.l + 4),
            _titulo('APARÊNCIA'),
            _seletorTema(),
            const SizedBox(height: AppEspaco.l + 4),
            _titulo('SOBRE O APLICATIVO'),
            _cartao([
              _linha(Icons.info_outline, 'Versão', kVersaoApp),
              _linha(Icons.dns_outlined, 'Servidor', Api.baseUrl),
            ]),
            const SizedBox(height: AppEspaco.xl),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppCores.perigo,
                  side: BorderSide(color: AppCores.perigo.withOpacity(0.5)),
                  backgroundColor: AppCores.perigo.withOpacity(0.04),
                ),
                onPressed: _sair,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sair da conta', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Automático (segue o celular) / Claro / Escuro — fica salvo no aparelho
  Widget _seletorTema() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: TemaApp.modo,
      builder: (context, atual, _) {
        Widget opcao(ThemeMode m, String rotulo) {
          final sel = atual == m;
          return Expanded(
            child: GestureDetector(
              onTap: () => TemaApp.definir(m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: AppEspaco.m),
                decoration: BoxDecoration(
                  color: sel ? AppCores.tinta(AppCores.primaria, 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRaio.m),
                  border: Border.all(color: sel ? AppCores.primaria : Colors.transparent, width: 1.4),
                ),
                child: Column(children: [
                  Icon(TemaApp.icone(m), color: sel ? AppCores.primaria : AppCores.textoSecundario),
                  const SizedBox(height: 4),
                  Text(rotulo,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          color: sel ? AppCores.primaria : AppCores.textoSecundario)),
                ]),
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(AppEspaco.s),
          decoration: BoxDecoration(
            color: AppCores.superficie,
            borderRadius: BorderRadius.circular(AppRaio.l),
            border: Border.all(color: AppCores.borda),
          ),
          child: Row(children: [
            opcao(ThemeMode.system, 'Automático'),
            const SizedBox(width: AppEspaco.xs),
            opcao(ThemeMode.light, 'Claro'),
            const SizedBox(width: AppEspaco.xs),
            opcao(ThemeMode.dark, 'Escuro'),
          ]),
        );
      },
    );
  }

  Widget _titulo(String t) => Padding(
        padding: const EdgeInsets.only(left: AppEspaco.xs, bottom: AppEspaco.s),
        child: Text(t, style: AppTexto.rotulo),
      );

  Widget _cartao(List<Widget> linhas) {
    final filhos = <Widget>[];
    for (var i = 0; i < linhas.length; i++) {
      if (i > 0) filhos.add(Divider(height: 1, indent: 64, color: AppCores.borda));
      filhos.add(linhas.elementAt(i));
    }
    return Container(
      decoration: BoxDecoration(
        color: AppCores.superficie,
        borderRadius: BorderRadius.circular(AppRaio.l),
        border: Border.all(color: AppCores.borda),
      ),
      child: Column(children: filhos),
    );
  }

  Widget _linha(IconData icone, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppEspaco.l, vertical: AppEspaco.m),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppCores.primaria.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppRaio.s + 2),
          ),
          child: Icon(icone, size: 19, color: AppCores.primaria),
        ),
        const SizedBox(width: AppEspaco.m),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11.5, color: AppCores.textoSecundario)),
            const SizedBox(height: 2),
            Text(valor, style: TextStyle(fontSize: 14.5, color: AppCores.texto, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }
}
