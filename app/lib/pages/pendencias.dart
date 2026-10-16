import 'package:flutter/material.dart';
import '../widgets/comum.dart';

// =====================================================
// Pendências da equipe + aviso de relatos (GET /api/pendencias)
//   admin -> todas as UNBs, por líder
//   TST   -> só a própria UNB, por líder (toca no líder e vê o time)
//   líder -> só o próprio time
//   todos -> aviso dos relatos novos em que a pessoa foi relatada
// =====================================================

String cpfDaSessao(Sessao s) {
  for (final c in ['cpf', 'CPF', 'documento', 'Documento', 'Senha_Atual (Documento)']) {
    final v = (s.bruto[c] ?? '').toString().trim();
    if (v.isNotEmpty) return v;
  }
  return '';
}

Future<Map<String, dynamic>> buscarPendencias(Sessao s) async {
  final q = 'nome=${Uri.encodeQueryComponent(s.nome)}'
      '&cpf=${Uri.encodeQueryComponent(cpfDaSessao(s))}'
      '&cargo=${Uri.encodeQueryComponent(s.cargo)}'
      '&perfil=${Uri.encodeQueryComponent(s.perfil)}';
  final r = await apiGet('/api/pendencias?$q');
  if (!respostaOk(r)) throw Exception(mensagemErro(r, prefixo: 'Erro ao carregar pendências'));
  final j = decodificar(r);
  if (j is! Map) throw Exception('Resposta inválida do servidor');
  return Map<String, dynamic>.from(j);
}

List<Map<String, dynamic>> _lista(dynamic v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

int _int(dynamic v) => v is int ? v : int.tryParse('${v ?? 0}') ?? 0;

const Color _corVencido = Color(0xFFEF4444);
const Color _corBreve = Color(0xFFF59E0B);
const Color _corOk = Color(0xFF10B981);

Color _corStatus(String s) => s == 'vence_em_breve' ? _corBreve : _corVencido;

String _textoStatus(Map<String, dynamic> p) {
  final s = (p['status'] ?? '').toString();
  final dias = p['dias'];
  if (s == 'sem_registro') return 'Nunca aplicado';
  if (s == 'vencido') return 'Vencido há ${dias is int ? -dias : '?'} dia(s)';
  if (s == 'vence_em_breve') return dias == 0 ? 'Vence hoje' : 'Vence em $dias dia(s)';
  return s;
}

// =====================================================
// CARD DA TELA INICIAL
// =====================================================
class CardPendencias extends StatefulWidget {
  final Sessao sessao;
  final int versao; // muda quando a Home é atualizada (puxar para baixo)
  const CardPendencias({super.key, required this.sessao, this.versao = 0});

  @override
  State<CardPendencias> createState() => _CardPendenciasState();
}

class _CardPendenciasState extends State<CardPendencias> {
  Map<String, dynamic>? _dados;
  bool _carregando = true;
  String _erro = '';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void didUpdateWidget(covariant CardPendencias old) {
    super.didUpdateWidget(old);
    if (old.versao != widget.versao) _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = '';
    });
    try {
      final d = await buscarPendencias(widget.sessao);
      if (mounted) setState(() => _dados = d);
    } catch (e) {
      if (mounted) setState(() => _erro = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _abrir() {
    final d = _dados;
    if (d == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PendenciasPage(sessao: widget.sessao, inicial: d)),
    ).then((_) => _carregar());
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando && _dados == null) {
      return _moldura(
        child: const Row(children: [
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Text('Verificando pendências...', style: TextStyle(color: Colors.grey)),
        ]),
      );
    }
    if (_erro.isNotEmpty && _dados == null) {
      return _moldura(
        child: Row(children: [
          const Icon(Icons.cloud_off, color: Colors.grey),
          const SizedBox(width: 10),
          const Expanded(child: Text('Não foi possível carregar as pendências.', style: TextStyle(color: Colors.grey))),
          IconButton(onPressed: _carregar, icon: const Icon(Icons.refresh)),
        ]),
      );
    }

    final d = _dados ?? {};
    final papel = (d['papel'] ?? 'colaborador').toString();
    final resumo = Map<String, dynamic>.from((d['resumo'] as Map?) ?? {});
    final vencidos = _int(resumo['vencidos']);
    final aVencer = _int(resumo['a_vencer']);
    final pessoas = _int(resumo['pessoas']);
    final relatosEquipe = _lista(d['relatos_equipe']);
    final meusRelatos = _lista(d['meus_relatos']);
    final minhas = _lista(d['minhas']);
    final temEquipe = papel != 'colaborador';

    // Sem equipe, sem pendência própria e sem relato novo: não mostra o card
    if (!temEquipe && meusRelatos.isEmpty && minhas.isEmpty) return const SizedBox.shrink();

    final titulo = switch (papel) {
      'tst' => 'Pendências da ${d['unb'] ?? 'unidade'}',
      'admin' => 'Pendências (todas as UNBs)',
      'lider' => 'Pendências da minha equipe',
      _ => 'Avisos',
    };
    final tudoEmDia = temEquipe && vencidos == 0 && aVencer == 0;

    return _moldura(
      onTap: _abrir,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (tudoEmDia ? _corOk : _corVencido).withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRaio.s + 2),
            ),
            child: Icon(tudoEmDia ? Icons.verified_outlined : Icons.notification_important_outlined,
                size: 20, color: tudoEmDia ? _corOk : _corVencido),
          ),
          const SizedBox(width: AppEspaco.m),
          Expanded(child: Text(titulo, style: AppTexto.tituloCard)),
          if (_carregando) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ]),
        if (temEquipe) ...[
          const SizedBox(height: 12),
          if (tudoEmDia)
            const Text('Tudo em dia! 🎉', style: TextStyle(color: _corOk, fontWeight: FontWeight.w600))
          else
            Row(children: [
              Expanded(child: _numero('$vencidos', 'vencidas', _corVencido)),
              Expanded(child: _numero('$aVencer', 'vencem em breve', _corBreve)),
              Expanded(child: _numero('$pessoas', 'pessoas', const Color(0xFF2563EB))),
            ]),
        ],
        if (minhas.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...minhas.map((x) {
            final cor = _corStatus((x['status'] ?? '').toString());
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: cor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cor.withOpacity(0.4)),
              ),
              child: Row(children: [
                Icon(Icons.person_pin_outlined, size: 18, color: cor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Seu ${x['modulo']}: ${_textoStatus(x)}',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: cor)),
                ),
              ]),
            );
          }),
        ],
        if (relatosEquipe.isNotEmpty || meusRelatos.isNotEmpty) ...[
          const SizedBox(height: 12),
          if (meusRelatos.isNotEmpty)
            _avisoRelato('Você foi relatado em ${meusRelatos.length} relato(s) novo(s).'),
          if (relatosEquipe.isNotEmpty)
            _avisoRelato(
                '${relatosEquipe.length} relato(s) novo(s) envolvendo ${papel == 'lider' ? 'sua equipe' : 'a unidade'}.'),
        ],
      ]),
    );
  }

  Widget _numero(String valor, String rotulo, Color cor) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: cor.withOpacity(0.07),
          borderRadius: BorderRadius.circular(AppRaio.m),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(valor, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cor, height: 1.1)),
          const SizedBox(height: 2),
          Text(rotulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: AppCores.textoSecundario)),
        ]),
      );

  Widget _avisoRelato(String texto) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppCores.tinta(AppCores.alerta, 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppCores.alerta.withOpacity(0.35)),
        ),
        child: Row(children: [
          Icon(Icons.campaign_outlined, size: 18, color: AppCores.legivel(const Color(0xFFB45309))),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: TextStyle(fontSize: 12.5, color: AppCores.legivel(const Color(0xFF92400E))))),
        ]),
      );

  Widget _moldura({required Widget child, VoidCallback? onTap}) => Material(
        color: AppCores.superficie,
        borderRadius: BorderRadius.circular(AppRaio.l),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRaio.l),
          onTap: onTap,
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.all(AppEspaco.l),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRaio.l),
              border: Border.all(color: AppCores.borda),
              boxShadow: [
                BoxShadow(color: AppCores.texto.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: child,
          ),
        ),
      );
}

// =====================================================
// TELA DE DETALHES
// =====================================================
class PendenciasPage extends StatefulWidget {
  final Sessao sessao;
  final Map<String, dynamic> inicial;
  const PendenciasPage({super.key, required this.sessao, required this.inicial});

  @override
  State<PendenciasPage> createState() => _PendenciasPageState();
}

class _PendenciasPageState extends State<PendenciasPage> {
  late Map<String, dynamic> _d = widget.inicial;
  String _filtroUnb = '';

  Future<void> _atualizar() async {
    try {
      final d = await buscarPendencias(widget.sessao);
      if (mounted) setState(() => _d = d);
    } catch (e) {
      if (mounted) avisar(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final papel = (_d['papel'] ?? 'colaborador').toString();
    final relatosEquipe = _lista(_d['relatos_equipe']);
    final meusRelatos = _lista(_d['meus_relatos']);
    final temEquipe = papel != 'colaborador' || _lista(_d['minhas']).isNotEmpty;
    final nAbas = (temEquipe ? 1 : 0) + 1;

    return DefaultTabController(
      key: ValueKey('abas-$nAbas'),
      length: nAbas,
      child: Scaffold(
        appBar: AppBar(
          title: Text(papel == 'tst' ? 'Pendências • ${_d['unb'] ?? ''}' : 'Pendências'),
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              if (temEquipe) const Tab(icon: Icon(Icons.assignment_late_outlined), text: 'Pendências'),
              Tab(
                icon: const Icon(Icons.campaign_outlined),
                text: 'Relatos (${relatosEquipe.length + meusRelatos.length})',
              ),
            ],
          ),
        ),
        body: TabBarView(children: [
          if (temEquipe) RefreshIndicator(onRefresh: _atualizar, child: _abaPendencias(papel)),
          RefreshIndicator(onRefresh: _atualizar, child: _abaRelatos(relatosEquipe, meusRelatos)),
        ]),
      ),
    );
  }

  Widget _regras() {
    final regras = Map<String, dynamic>.from((_d['regras'] as Map?) ?? {});
    final textos = (regras['textos'] is List) ? (regras['textos'] as List).map((e) => '• $e').join('\n') : '';
    final minhas = _lista(_d['minhas']);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (textos.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: FaixaInfo(textos)),
      if (minhas.isNotEmpty) ...[
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 6),
          child: Text('Minhas pendências', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        _cardPessoa({'nome': widget.sessao.nome, 'cargo': widget.sessao.cargo, 'pendencias': minhas}),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 4, 6),
          child: Text('Equipe', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ]);
  }

  Widget _abaPendencias(String papel) {
    if (papel == 'colaborador') {
      return ListView(padding: const EdgeInsets.all(12), children: [_regras()]);
    }
    if (papel == 'lider') {
      final equipe = _lista(_d['equipe']);
      if (equipe.isEmpty) {
        return ListView(padding: const EdgeInsets.all(12), children: [
          _regras(),
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Sua equipe está em dia! 🎉', style: TextStyle(color: _corOk, fontWeight: FontWeight.w600))),
          ),
        ]);
      }
      return ListView(padding: const EdgeInsets.all(12), children: [
        _regras(),
        ...equipe.map(_cardPessoa),
      ]);
    }

    // TST / admin: por líder
    var lideres = _lista(_d['lideres']);
    final unbs = lideres.map((l) => (l['unb'] ?? '').toString()).toSet().toList()..sort();
    if (_filtroUnb.isNotEmpty) lideres = lideres.where((l) => l['unb'] == _filtroUnb).toList();
    if (lideres.isEmpty && _filtroUnb.isEmpty) {
      return ListView(padding: const EdgeInsets.all(12), children: [
        _regras(),
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('Nenhuma pendência na unidade! 🎉', style: TextStyle(color: _corOk, fontWeight: FontWeight.w600))),
        ),
      ]);
    }

    return ListView(padding: const EdgeInsets.all(12), children: [
      _regras(),
      if (papel == 'admin' && unbs.length > 1)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FiltroMenu(rotulo: 'UNB', valor: _filtroUnb, opcoes: unbs, onChanged: (v) => setState(() => _filtroUnb = v)),
          ),
        ),
      ...lideres.map((l) {
        final pessoas = _lista(l['pessoas']);
        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: FotoPerfil(nome: (l['lider'] ?? '').toString(), raio: 20),
            title: Text((l['lider'] ?? '-').toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(spacing: 6, runSpacing: 4, children: [
                if (papel == 'admin') Etiqueta((l['unb'] ?? '').toString()),
                if (_int(l['vencidos']) > 0) Etiqueta('${l['vencidos']} vencidas', cor: _corVencido),
                if (_int(l['a_vencer']) > 0) Etiqueta('${l['a_vencer']} em breve', cor: _corBreve),
                Etiqueta('${pessoas.length} pessoa(s)', cor: const Color(0xFF2563EB)),
              ]),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: Text('Time de ${l['lider']}')),
                  body: ListView(padding: const EdgeInsets.all(12), children: pessoas.map(_cardPessoa).toList()),
                ),
              ),
            ),
          ),
        );
      }),
    ]);
  }

  Widget _cardPessoa(Map<String, dynamic> p) {
    final pend = _lista(p['pendencias']);
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            FotoPerfil(nome: (p['nome'] ?? '').toString(), raio: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((p['nome'] ?? '-').toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text((p['cargo'] ?? '').toString(), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          ...pend.map((x) {
            final cor = _corStatus((x['status'] ?? '').toString());
            final ultimo = x['ultimo'] == null ? 'nenhum ainda' : 'último ${dataBr(x['ultimo'])}';
            final venc = x['vencimento'] == null ? '' : ' • prazo ${dataBr(x['vencimento'])}';
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                Container(
                  width: 46,
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  decoration: BoxDecoration(color: cor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                  child: Text((x['modulo'] ?? '').toString(),
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cor)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${_textoStatus(x)} • $ultimo$venc',
                      style: TextStyle(fontSize: 12.5, color: AppCores.legivel(cor == _corVencido ? const Color(0xFFB91C1C) : const Color(0xFF92400E)))),
                ),
              ]),
            );
          }),
        ]),
      ),
    );
  }

  Widget _abaRelatos(List<Map<String, dynamic>> equipe, List<Map<String, dynamic>> meus) {
    if (equipe.isEmpty && meus.isEmpty) {
      return const EstadoVazio('Nenhum relato novo.', icone: Icons.campaign_outlined);
    }
    final corte = Map<String, dynamic>.from((_d['regras'] as Map?) ?? {})['corte_relatos'];
    return ListView(padding: const EdgeInsets.all(12), children: [
      FaixaInfo('Mostrando apenas relatos registrados depois de ${dataBr(corte)}.'),
      if (meus.isNotEmpty) ...[
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 14, 4, 6),
          child: Text('Relatos em que você foi relatado', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        ...meus.map(_cardRelato),
      ],
      if (equipe.isNotEmpty) ...[
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 14, 4, 6),
          child: Text('Relatos da equipe', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        ...equipe.map(_cardRelato),
      ],
    ]);
  }

  Widget _cardRelato(Map<String, dynamic> r) {
    final classif = (r['classificacao'] ?? '').toString();
    final s = semAcento(classif).toLowerCase();
    final cor = s.contains('positiva')
        ? _corOk
        : (s.contains('condic') ? _corBreve : (s.contains('incidente') ? const Color(0xFF3B82F6) : _corVencido));
    final desc = (r['descricao'] ?? '').toString().trim();
    final detalhe = (r['detalhe'] ?? '').toString().trim();
    return CardRegistro(
      fotoNome: (r['relatado'] ?? '').toString(),
      titulo: (r['protocolo'] ?? '-').toString(),
      subtitulo: '${dataBr(r['data'])} • ${r['area'] ?? '-'}\n${r['relatado'] ?? '-'}',
      etiqueta: Etiqueta(classif.isEmpty ? '-' : classif.split(' (').first, cor: cor),
      cor: cor,
      detalhes: [
        if (detalhe.isNotEmpty) LinhaDetalhe('Detalhe', detalhe),
        if (desc.isNotEmpty) ...[const SizedBox(height: 6), Text(desc, style: const TextStyle(fontSize: 13))],
      ],
    );
  }
}
