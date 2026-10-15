import 'package:flutter/material.dart';
import '../widgets/comum.dart';

// =====================================================
// Gestão de Usuários e Acessos (espelho do GestaoUsuarios.tsx)
// Só ADMIN acessa (a tela fecha sozinha para outros perfis)
// =====================================================
class GestaoUsuariosPage extends StatefulWidget {
  const GestaoUsuariosPage({super.key});

  @override
  State<GestaoUsuariosPage> createState() => _GestaoUsuariosPageState();
}

class _GestaoUsuariosPageState extends State<GestaoUsuariosPage> with SingleTickerProviderStateMixin {
  late final TabController _abas = TabController(length: 2, vsync: this);

  Sessao _sessao = Sessao.vazia;
  bool _carregando = true;
  String _erro = '';
  List<Map<String, dynamic>> _usuarios = [];
  String _busca = '';

  // Reset
  String? _usuarioReset;
  Key _chaveBuscaReset = UniqueKey();
  bool _resetando = false;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  @override
  void dispose() {
    _abas.dispose();
    super.dispose();
  }

  Future<void> _iniciar() async {
    final s = await Sessao.carregar();
    if (!mounted) return;
    _sessao = s;
    if (!s.ehAdmin) {
      avisar(context, 'Acesso restrito ao administrador.');
      Navigator.pop(context);
      return;
    }
    await _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = '';
    });
    try {
      final r = await apiGet('/api/usuarios/');
      if (!mounted) return;
      if (respostaOk(r)) {
        final lista = listaDados(decodificar(r));
        lista.sort((a, b) => _nome(a).compareTo(_nome(b)));
        setState(() => _usuarios = lista);
      } else {
        setState(() => _erro = mensagemErro(r, prefixo: 'Erro ao carregar usuários'));
      }
    } catch (e) {
      if (mounted) setState(() => _erro = 'Falha de conexão com o servidor.');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  String _nome(Map<String, dynamic> u) => (u['Nome'] ?? u['nome'] ?? '').toString();
  String _doc(Map<String, dynamic> u) => (u['Senha_Atual (Documento)'] ?? '').toString();

  /// Mostra só os 4 últimos dígitos do documento na lista
  String _docMascarado(Map<String, dynamic> u) {
    final d = _doc(u).replaceAll(RegExp(r'\D'), '');
    if (d.length < 4) return d.isEmpty ? '-' : d;
    return '•••••••${d.substring(d.length - 4)}';
  }

  List<Map<String, dynamic>> get _filtrados => _usuarios
      .where((u) => contemTexto(_nome(u), _busca) || contemTexto(u['UNB'], _busca) || contemTexto(u['Cargo'], _busca))
      .toList();

  Future<void> _resetar() async {
    if (_usuarioReset == null) return avisar(context, 'Selecione um usuário da lista.');
    Map<String, dynamic>? user;
    for (final u in _usuarios) {
      if (_nome(u) == _usuarioReset) {
        user = u;
        break;
      }
    }
    if (user == null) return;

    final ok = await confirmar(context, 'Resetar senha',
        'Tem certeza que deseja resetar a senha de ${_nome(user)}?\n\nA senha voltará a ser o CPF/Documento.',
        ok: 'Resetar');
    if (!ok || !mounted) return;

    setState(() => _resetando = true);
    try {
      final r = await apiPost('/api/usuarios/resetar_senha', {'cpf': _doc(user)});
      if (!mounted) return;
      if (respostaOk(r)) {
        avisar(context, 'Senha de ${_nome(user)} resetada! O acesso voltou para o CPF padrão.', erro: false);
        setState(() {
          _usuarioReset = null;
          _chaveBuscaReset = UniqueKey();
        });
      } else {
        avisar(context, mensagemErro(r, prefixo: 'Erro ao resetar senha'));
      }
    } catch (e) {
      if (mounted) avisar(context, 'Falha de conexão com o servidor.');
    } finally {
      if (mounted) setState(() => _resetando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão de Usuários'),
        bottom: TabBar(
          controller: _abas,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.people_outline), text: 'Usuários'),
            Tab(icon: Icon(Icons.key_outlined), text: 'Resetar Senha'),
          ],
        ),
      ),
      body: _carregando && _usuarios.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _abas, children: [_abaLista(), _abaReset()]),
    );
  }

  Widget _abaLista() {
    final lista = _filtrados;
    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          FaixaInfo('O sistema possui ${_usuarios.length} colaboradores mapeados.', icone: Icons.people),
          const SizedBox(height: 10),
          CampoBuscaTexto(hint: 'Procurar por nome, cargo ou UNB...', onChanged: (v) => setState(() => _busca = v)),
        ]),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _carregar,
          child: _erro.isNotEmpty
              ? EstadoVazio(_erro, icone: Icons.wifi_off)
              : lista.isEmpty
                  ? const EstadoVazio('Nenhum colaborador encontrado.')
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: lista.length,
                      itemBuilder: (ctx, i) => _cardUsuario(lista.elementAt(i)),
                    ),
        ),
      ),
    ]);
  }

  Widget _cardUsuario(Map<String, dynamic> u) {
    final perfil = (u['Perfil_App'] ?? 'colaborador').toString();
    final status = (u['Status'] ?? '-').toString();
    final corPerfil = perfil == 'admin'
        ? const Color(0xFF991B1B)
        : (perfil == 'tecnico' ? const Color(0xFF3730A3) : const Color(0xFF475569));
    final corStatus = status == 'ATIVO' ? const Color(0xFF065F46) : const Color(0xFF92400E);

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE2E8F0),
          child: Text(_nome(u).isEmpty ? '?' : _nome(u).substring(0, 1),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155))),
        ),
        title: Text(_nome(u), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(spacing: 6, runSpacing: 4, children: [
            Etiqueta(perfil.toUpperCase(), cor: corPerfil),
            Etiqueta(status, cor: corStatus),
            if ((u['UNB'] ?? '').toString().isNotEmpty) Etiqueta(u['UNB'].toString()),
          ]),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinhaDetalhe('Documento', _docMascarado(u)),
          LinhaDetalhe('Cargo', u['Cargo']),
          LinhaDetalhe('Líder direto', u['Lider']),
          LinhaDetalhe('Admissão', u['Data_Admissao']),
          LinhaDetalhe('E-mail', u['Email']),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _usuarioReset = _nome(u);
                  _chaveBuscaReset = UniqueKey();
                });
                _abas.animateTo(1);
              },
              icon: const Icon(Icons.key, color: Colors.red),
              label: const Text('Resetar senha', style: TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _abaReset() {
    final nomes = _usuarios.map(_nome).where((n) => n.isNotEmpty).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Restaurar Acesso', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'Se um colaborador esquecer a senha, você pode resetá-la aqui. A senha voltará a ser o CPF/Documento '
          'da pessoa, e o sistema exigirá que ela cadastre uma nova no próximo login.',
          style: TextStyle(color: Colors.grey, height: 1.4),
        ),
        const SizedBox(height: 20),
        if (_usuarioReset != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FaixaInfo('Selecionado: $_usuarioReset', icone: Icons.person, cor: const Color(0xFFB91C1C)),
          ),
        CampoBuscaPessoa(
          key: _chaveBuscaReset,
          label: 'Colaborador*',
          opcoes: nomes,
          onChanged: (v) => setState(() => _usuarioReset = v ?? _usuarioReset),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: _resetando ? null : _resetar,
            icon: _resetando
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.warning_amber_rounded),
            label: Text(_resetando ? 'Resetando...' : 'Confirmar Reset de Senha'),
          ),
        ),
      ]),
    );
  }
}
