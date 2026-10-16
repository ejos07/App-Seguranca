import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/comum.dart';

// =====================================================
// GSP - Guia de Segurança de Puxada (espelho do GSP.tsx)
// =====================================================
const List<String> kPerguntasGsp = [
  "COMPORTAMENTO [O motorista está utilizando o cinto de segurança durante o deslocamento?]",
  "COMPORTAMENTO [O caminhão foi estacionado em local adequado dentro da Revenda?]",
  "COMPORTAMENTO [Alguém auxilia o motorista na manobras dentro da Revenda?]",
  "COMPORTAMENTO [O motorista está utilizando todos os EPI´s no procedimento de abertura e fechamento do sider da carreta (P. Ex.: Fardamento Completo com faixas refletivas, Capacete - quando aplicável, Óculos de Segurança, Luvas e Bota de Segurança)? NOK (sinalizar qual)]",
  "COMPORTAMENTO [O motorista garante a utilização do trava - rodas antes das empilhadeiras iniciarem o descarregamento e carregamento dentro da Revenda e/ou Fábrica ?]",
  "COMPORTAMENTO [O Motorista utiliza os 03 pontos de apoio para subir e descer da cabine do caminhão?]",
  "COMPORTAMENTO [O motorista obedece o Plano de Tráfego dentro da Revenda?]",
  "COMPORTAMENTO [O motorista verificou o fechamento correto e seguro da lona antes de sair da Revenda e Fábrica?]",
  "COMPORTAMENTO [O motorista fez o giro 360° antes de sair com o veículo?]",
  "COMPORTAMENTO [O motorista verificou se as presilhas da lona estavam presas?]",
  "COMPORTAMENTO [O motorista fez a amarração da carga adequadamente utilizando as cintas de segurança disponíveis na carreta?]",
  "COMPORTAMENTO [O motorista está portando todos os documentos do caminhão e do frota (CRLV, CNH e ANTT (quando aplicável))]",
  "COMPORTAMENTO [O programa 5S a cabine da carreta está limpa e organizada?]",
  "COMPORTAMENTO [O diário de bordo do motorista foi preenchido corretamente, sem rasuras?]",
  "COMPORTAMENTO [O motorista respeita os limites de velocidade estabelecidos pela empresa?]",
  "COMPORTAMENTO [O motorista sinaliza as intenções de mudança de faixa?]",
  "CONDIÇÃO [Existe alguma ASA da carreta apresentando problema?]",
  "CONDIÇÃO [O sensor de cinto de segurança do frota está em perfeito estado de funcionamento?]",
  "CONDIÇÃO [Os pneus estão em perfeitas condições de utilização?]",
  "CONDIÇÃO [A parte elétrica da carreta e do cavalo está funcionando perfeitamente? (Farol, Lanterna, Seta, Alarme Sonoro de ré, Luz de Freio, Buzina, Instruções do painel)]",
  "CONDIÇÃO [O sistema de freio está em perfeito estado de funcionamento?]",
  "CONDIÇÃO [A célula de segurança (cama e tela de proteção) estão em condições seguras?]",
  "CONDIÇÕES DOS EPI'S (Luvas, Óculos, Capacete, Uniformes, Botina)",
];

/// "COMPORTAMENTO [texto]" -> (categoria, texto)
(String, String) separarPerguntaGsp(String p) {
  final m = RegExp(r'^(.*?)\s*\[\s*(.*?)\s*\]\s*$').firstMatch(p);
  if (m == null) return ('', p);
  return ((m.group(1) ?? '').trim(), m.group(2) ?? p);
}

class GspPage extends StatefulWidget {
  const GspPage({super.key});

  @override
  State<GspPage> createState() => _GspPageState();
}

class _GspPageState extends State<GspPage> {
  Sessao _sessao = Sessao.vazia;
  bool _carregandoSessao = true;

  List<String> _equipe = [];
  bool _carregandoEquipe = false;
  List<Map<String, dynamic>> _historico = [];
  bool _carregandoHistorico = false;
  bool _historicoCarregado = false;
  String _erroHistorico = '';

  // Formulário
  DateTime _data = DateTime.now();
  String _unb = kListaUnbs.first;
  String? _motorista;
  Key _chaveBusca = UniqueKey();
  final TextEditingController _cavaloCtrl = TextEditingController();
  final TextEditingController _carretaCtrl = TextEditingController();
  final TextEditingController _obsCtrl = TextEditingController();
  final Map<String, String> _respostas = {};
  final ScrollController _scrollForm = ScrollController();
  bool _tentouSalvar = false;
  bool _salvando = false;

  // Filtros
  String _busca = '';
  String _filtroUnb = '';

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  @override
  void dispose() {
    _cavaloCtrl.dispose();
    _carretaCtrl.dispose();
    _obsCtrl.dispose();
    _scrollForm.dispose();
    super.dispose();
  }

  Future<void> _iniciar() async {
    final s = await Sessao.carregar();
    if (!mounted) return;
    setState(() {
      _sessao = s;
      _carregandoSessao = false;
    });
    _carregarHistorico();
    _carregarEquipe(_unb);
  }

  // Igual ao web: reaproveita a rota de equipe do GSD
  Future<void> _carregarEquipe(String unb) async {
    setState(() => _carregandoEquipe = true);
    try {
      final q = 'unb=${Uri.encodeQueryComponent(unb)}'
          '&lider=${Uri.encodeQueryComponent(_sessao.nome)}'
          '&isTST=${_sessao.ehTST}';
      final r = await apiGet('/api/gsd/equipe?$q');
      if (!mounted) return;
      final data = decodificar(r);
      final lista = (data is Map ? data['funcionarios'] : null);
      setState(() {
        _equipe = lista is List ? (lista.map((e) => e.toString()).toSet().toList()..sort()) : <String>[];
        _carregandoEquipe = false;
      });
    } catch (e) {
      debugPrint('Erro equipe GSP: $e');
      if (mounted) setState(() => _carregandoEquipe = false);
    }
  }

  Future<void> _carregarHistorico() async {
    setState(() {
      _carregandoHistorico = true;
      _erroHistorico = '';
    });
    try {
      final r = await apiGet('/api/gsp/');
      if (!mounted) return;
      if (respostaOk(r)) {
        setState(() {
          _historico = listaDados(decodificar(r));
          _historicoCarregado = true;
        });
      } else {
        setState(() => _erroHistorico = mensagemErro(r, prefixo: 'Erro ao carregar'));
      }
    } catch (e) {
      if (mounted) setState(() => _erroHistorico = 'Falha de conexão com o servidor.');
    } finally {
      if (mounted) setState(() => _carregandoHistorico = false);
    }
  }

  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();
    setState(() => _tentouSalvar = true);

    if (_motorista == null) return avisar(context, 'Selecione um Motorista da lista.');
    if (_cavaloCtrl.text.trim().isEmpty || _carretaCtrl.text.trim().isEmpty) {
      return avisar(context, 'Preencha as placas do Cavalo e da Carreta.');
    }
    final faltam = kPerguntasGsp.where((p) => !_respostas.containsKey(p)).length;
    if (faltam > 0) return avisar(context, 'Faltam $faltam perguntas a serem respondidas (marcadas em vermelho).');

    final payload = {
      'unb': _unb,
      'motorista': _motorista,
      'placa_cavalo': _cavaloCtrl.text.trim().toUpperCase(),
      'placa_carreta': _carretaCtrl.text.trim().toUpperCase(),
      'data_relato': dataIsoDe(_data),
      'observacao': _obsCtrl.text.trim(),
      'avaliador': _sessao.nome,
      'respostas_dict': {for (final p in kPerguntasGsp) p: _respostas[p]},
    };

    setState(() => _salvando = true);
    try {
      final r = await apiPost('/api/gsp/', payload);
      if (!mounted) return;
      if (respostaOk(r)) {
        final prot = protocoloDe(decodificar(r), padrao: '-');
        avisar(context, 'GSP registrado com sucesso! Protocolo: $prot', erro: false);
        setState(() {
          _motorista = null;
          _chaveBusca = UniqueKey();
          _cavaloCtrl.clear();
          _carretaCtrl.clear();
          _obsCtrl.clear();
          _respostas.clear();
          _tentouSalvar = false;
        });
        if (_scrollForm.hasClients) _scrollForm.jumpTo(0);
        _carregarHistorico();
      } else {
        avisar(context, mensagemErro(r, prefixo: 'Erro ao salvar GSP'));
      }
    } catch (e) {
      if (mounted) avisar(context, 'Falha de conexão com o servidor.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _excluir(Map<String, dynamic> r) async {
    final id = (r['id'] ?? r['protocolo'] ?? '').toString();
    if (id.isEmpty) return;
    final ok = await confirmar(context, 'Excluir registro', 'Confirma a exclusão do registro ${r['protocolo'] ?? id}?',
        ok: 'Excluir');
    if (!ok) return;
    try {
      final resp = await apiDelete('/api/gsp/${Uri.encodeComponent(id)}');
      if (!mounted) return;
      if (respostaOk(resp)) {
        avisar(context, 'GSP excluído com sucesso!', erro: false);
        _carregarHistorico();
      } else {
        avisar(context, mensagemErro(resp, prefixo: 'Erro ao excluir'));
      }
    } catch (e) {
      if (mounted) avisar(context, 'Falha de conexão com o servidor.');
    }
  }

  List<Map<String, dynamic>> get _filtrados {
    final lista = _historico.where((r) {
      final matchBusca = contemTexto(r['motorista'], _busca) || contemTexto(r['avaliador'], _busca);
      final matchUnb = _filtroUnb.isEmpty || r['unb'] == _filtroUnb;
      final matchPerfil = _sessao.podeExcluir || registroEhMeu(_sessao, kRegraGsp, r);
      return matchBusca && matchUnb && matchPerfil;
    }).toList();
    lista.sort((a, b) => soDataIso(b['data_relato']).compareTo(soDataIso(a['data_relato'])));
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    const titulo = 'Segurança de Puxada (GSP)';
    if (_carregandoSessao || (!_historicoCarregado && _erroHistorico.isEmpty)) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_historicoCarregado) {
      return TelaErro(titulo: titulo, mensagem: _erroHistorico, onTentarDeNovo: _carregarHistorico);
    }

    final nivel = calcularAcesso(_sessao, kRegraGsp, _historico);
    if (nivel == NivelAcesso.nenhum) {
      return const TelaSemAcesso(
        titulo: titulo,
        mensagem: 'O GSP é liberado para Motorista Carreta Puxada, para quem já foi avaliado '
            'e para quem já aplicou GSP.',
      );
    }
    final podeCriar = nivel == NivelAcesso.completo;

    final abas = <Tab>[
      if (podeCriar) const Tab(icon: Icon(Icons.add_circle_outline), text: 'Novo GSP'),
      Tab(icon: const Icon(Icons.search), text: _sessao.podeExcluir ? 'Consulta' : 'Meus Registros'),
      if (_sessao.podeExcluir) const Tab(icon: Icon(Icons.pie_chart_outline), text: 'Dashboard'),
    ];
    final telas = <Widget>[
      if (podeCriar) _abaIncluir(),
      _abaConsulta(),
      if (_sessao.podeExcluir) _abaDashboard(),
    ];

    return DefaultTabController(
      key: ValueKey('abas-${abas.length}'),
      length: abas.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Segurança de Puxada (GSP)'),
          bottom: TabBar(
            tabs: abas,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: TabBarView(children: telas),
      ),
    );
  }

  Widget _abaIncluir() {
    final respondidas = kPerguntasGsp.where((p) => _respostas.containsKey(p)).length;
    final nok = _respostas.values.where((v) => v == 'NOK').length;

    return Column(children: [
      Expanded(
        child: ListView(
          controller: _scrollForm,
          padding: const EdgeInsets.all(AppEspaco.l),
          children: [
            SecaoForm(
              titulo: 'Dados da avaliação',
              icone: Icons.event_note_outlined,
              child: Row(children: [
                Expanded(
                  child: CampoData(label: 'Data*', valor: _data, onChanged: (d) => setState(() => _data = d)),
                ),
                const SizedBox(width: AppEspaco.m),
                Expanded(
                  child: CampoDropdown(
                    label: 'UNB*',
                    opcoes: kListaUnbs,
                    valor: _unb,
                    onChanged: (v) {
                      if (v == null || v == _unb) return;
                      setState(() {
                        _unb = v;
                        _motorista = null;
                        _chaveBusca = UniqueKey();
                      });
                      _carregarEquipe(v);
                    },
                  ),
                ),
              ]),
            ),
            SecaoForm(
              titulo: 'Motorista e veículo',
              icone: Icons.local_shipping_outlined,
              child: Column(children: [
                CampoSomenteLeitura(label: 'Avaliador', valor: _sessao.nome, icone: Icons.person_outline),
                const SizedBox(height: AppEspaco.m),
                CampoBuscaPessoa(
                  key: _chaveBusca,
                  label: 'Motorista*',
                  opcoes: _equipe,
                  carregando: _carregandoEquipe,
                  onChanged: (v) => setState(() => _motorista = v),
                ),
                const SizedBox(height: AppEspaco.m),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _cavaloCtrl,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [LengthLimitingTextInputFormatter(8)],
                      decoration: decoracao('Placa cavalo*', hint: 'ABC1D23', prefixo: Icons.pin_outlined),
                    ),
                  ),
                  const SizedBox(width: AppEspaco.m),
                  Expanded(
                    child: TextField(
                      controller: _carretaCtrl,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [LengthLimitingTextInputFormatter(8)],
                      decoration: decoracao('Placa carreta*', hint: 'XYZ9K87', prefixo: Icons.pin_outlined),
                    ),
                  ),
                ]),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppEspaco.xs, AppEspaco.xs, AppEspaco.xs, AppEspaco.m),
              child: Text('QUESTIONÁRIO GSP • ${kPerguntasGsp.length} PERGUNTAS', style: AppTexto.rotulo),
            ),
            ...List.generate(kPerguntasGsp.length, (i) {
              final p = kPerguntasGsp.elementAt(i);
              final (cat, texto) = separarPerguntaGsp(p);
              return PerguntaBinaria(
                numero: i + 1,
                categoria: cat,
                pergunta: texto,
                valor: _respostas[p],
                destacarFalta: _tentouSalvar,
                onChanged: (v) => setState(() => _respostas[p] = v),
              );
            }),
            const SizedBox(height: AppEspaco.s),
            SecaoForm(
              titulo: 'Observações',
              icone: Icons.notes_outlined,
              child: TextField(
                controller: _obsCtrl,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: decoracao('Observações', hint: 'Digite aqui as observações...'),
              ),
            ),
          ],
        ),
      ),
      BarraAcaoInferior(
        rotulo: 'Finalizar e salvar GSP',
        icone: Icons.send_rounded,
        carregando: _salvando,
        onPressed: _salvar,
        topo: ProgressoChecklist(respondidas: respondidas, total: kPerguntasGsp.length, ruins: nok),
      ),
    ]);
  }

  Widget _barraFiltros() {
    return BarraFiltros(
      hint: 'Buscar por motorista ou avaliador...',
      onBusca: (v) => setState(() => _busca = v),
      filtros: [
        FiltroMenu(rotulo: 'UNB', valor: _filtroUnb, opcoes: kListaUnbs, onChanged: (v) => setState(() => _filtroUnb = v)),
      ],
    );
  }

  Widget _abaConsulta() {
    final lista = _filtrados;
    Widget corpo;
    if (_carregandoHistorico && _historico.isEmpty) {
      corpo = const ListaCarregando();
    } else if (_erroHistorico.isNotEmpty) {
      corpo = EstadoVazio(_erroHistorico, icone: Icons.wifi_off);
    } else if (lista.isEmpty) {
      corpo = const EstadoVazio('Nenhum registro encontrado.');
    } else {
      corpo = ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: lista.length,
        itemBuilder: (ctx, i) {
          final r = lista.elementAt(i);
          final resp = respostasDe(r['respostas_dict']);
          final nok = resp.values.where((v) => v.toString().toUpperCase() == 'NOK').length;
          final obs = (r['observacao'] ?? '').toString().trim();
          return CardRegistro(
            fotoNome: (r['motorista'] ?? '').toString(),
            titulo: (r['protocolo'] ?? r['id'] ?? '-').toString(),
            subtitulo: '${dataBr(r['data_relato'])} • ${r['unb'] ?? '-'}\nMotorista: ${r['motorista'] ?? '-'}',
            etiqueta: nok > 0 ? Etiqueta('$nok NOK', cor: Colors.red) : const Etiqueta('100% OK', cor: Colors.green),
            cor: const Color(0xFF0E7490),
            onExcluir: _sessao.podeExcluir ? () => _excluir(r) : null,
            detalhes: [
              LinhaDetalhe('Avaliador', r['avaliador']),
              LinhaDetalhe('Motorista', r['motorista']),
              LinhaDetalhe('Placa do cavalo', r['placa_cavalo']),
              LinhaDetalhe('Placa da carreta', r['placa_carreta']),
              if (obs.isNotEmpty) ...[const SizedBox(height: 8), CaixaObservacao(obs)],
              const SizedBox(height: 10),
              const Text('Respostas do Checklist:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 4),
              ListaRespostas(respostas: resp, ehRuim: (v) => v.toUpperCase() == 'NOK'),
            ],
          );
        },
      );
    }
    return Column(children: [
      _barraFiltros(),
      Expanded(child: RefreshIndicator(onRefresh: _carregarHistorico, child: corpo)),
    ]);
  }

  Widget _abaDashboard() {
    final lista = _filtrados;
    final total = lista.length;
    final motoristas = lista.map((g) => (g['motorista'] ?? '').toString()).where((s) => s.isNotEmpty).toSet().length;
    final avaliadores = lista.map((g) => (g['avaliador'] ?? '').toString()).where((s) => s.isNotEmpty).toSet().length;

    var ok = 0;
    var nok = 0;
    final nokPorItem = <String, int>{};
    final nokPorCategoria = <String, int>{};
    final porData = <String, double>{};
    final okDia = <String, int>{};
    final totDia = <String, int>{};
    for (final g in lista) {
      final d = soDataIso(g['data_relato']);
      if (d.isNotEmpty) porData[d] = (porData[d] ?? 0.0) + 1;
      respostasDe(g['respostas_dict']).forEach((k, v) {
        final r = v.toString().toUpperCase().trim();
        if (r == 'OK') {
          ok++;
          okDia[d] = (okDia[d] ?? 0) + 1;
          totDia[d] = (totDia[d] ?? 0) + 1;
        } else if (r == 'NOK') {
          nok++;
          totDia[d] = (totDia[d] ?? 0) + 1;
          final (cat, texto) = separarPerguntaGsp(k);
          nokPorItem[texto] = (nokPorItem[texto] ?? 0) + 1;
          final c = cat.trim();
          final chave = c.isEmpty ? 'GERAL' : c;
          nokPorCategoria[chave] = (nokPorCategoria[chave] ?? 0) + 1;
        }
      });
    }
    final respondidas = ok + nok;
    final pct = respondidas == 0 ? 0.0 : ok * 100 / respondidas;
    final pctDia = <String, double>{};
    totDia.forEach((d, t) {
      if (t > 0 && d.isNotEmpty) pctDia[d] = (okDia[d] ?? 0) * 100 / t;
    });
    bool temNok(Map<String, dynamic> g) =>
        respostasDe(g['respostas_dict']).values.any((v) => v.toString().toUpperCase() == 'NOK');
    final comNok = lista.where(temNok).length;

    final (status, corStatus) = pct >= 95
        ? ('Padrão atingido', AppCores.sucesso)
        : (pct >= 85 ? ('Atenção', AppCores.alerta) : ('Abaixo do padrão', AppCores.perigo));

    final mensal = empilharPorMes(lista, campoData: 'data_relato', qtdSeries: 2, serieDe: (g) => temNok(g) ? 1 : 0);

    return Column(children: [
      _barraFiltros(),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _carregarHistorico,
          child: total == 0
              ? ListView(children: const [
                  SizedBox(height: 60),
                  EstadoVazio('Sem GSPs no filtro atual.', icone: Icons.insights_outlined),
                ])
              : ListView(padding: const EdgeInsets.fromLTRB(AppEspaco.l, AppEspaco.l, AppEspaco.l, AppEspaco.xxl), children: [
                  PainelIndice(
                    titulo: 'Conformidade dos GSPs',
                    percentual: pct,
                    status: status,
                    corStatus: corStatus,
                    descricao: 'Itens OK sobre o total de itens avaliados.',
                    numeros: [
                      ('$total', 'GSPs'),
                      ('$motoristas', 'motoristas'),
                      ('$nok', 'itens NOK'),
                    ],
                  ),
                  const TituloDash('Indicadores'),
                  GradeKpis([
                    KpiCard(
                        titulo: 'Motoristas avaliados',
                        valor: '$motoristas',
                        cor: AppCores.info,
                        icone: Icons.local_shipping_outlined,
                        subtitulo: motoristas == 0 ? null : '${(total / motoristas).toStringAsFixed(1)} GSP por motorista'),
                    KpiCard(
                        titulo: 'Avaliadores ativos',
                        valor: '$avaliadores',
                        cor: AppCores.roxo,
                        icone: Icons.badge_outlined),
                    KpiCard(
                        titulo: 'GSPs com NOK',
                        valor: '$comNok',
                        cor: AppCores.perigo,
                        icone: Icons.gpp_maybe_outlined,
                        fracao: total == 0 ? 0 : comNok / total,
                        subtitulo: total == 0 ? null : '${(comNok * 100 / total).toStringAsFixed(0)}% dos GSPs'),
                    KpiCard(
                        titulo: 'GSPs 100% OK',
                        valor: '${total - comNok}',
                        cor: AppCores.sucesso,
                        icone: Icons.verified_outlined,
                        fracao: total == 0 ? 0 : (total - comNok) / total),
                  ]),
                  if (nokPorItem.isNotEmpty)
                    CartaoInsight(
                      icone: Icons.priority_high_rounded,
                      titulo: 'ITEM MAIS REPROVADO',
                      texto: '${topContagem(nokPorItem, n: 1).first.rotulo} '
                          '(${topContagem(nokPorItem, n: 1).first.valor.toInt()} NOK)',
                      cor: AppCores.perigo,
                    ),
                  const TituloDash('Evolução'),
                  CartaoGrafico(
                    titulo: 'GSPs por mês',
                    subtitulo: '100% OK x com NOK',
                    icone: Icons.stacked_bar_chart,
                    child: GraficoBarrasEmpilhadas(
                      rotulos: mensal.rotulos,
                      valores: mensal.valores,
                      series: const [
                        SerieEmpilhada('100% OK', AppCores.sucesso),
                        SerieEmpilhada('Com NOK', AppCores.perigo),
                      ],
                    ),
                  ),
                  CartaoGrafico(
                    titulo: '% de conformidade',
                    icone: Icons.show_chart,
                    child: GraficoLinhaTempo(porData: pctDia, cor: AppCores.sucesso, maxY: 100, media: true, sufixo: '%'),
                  ),
                  CartaoGrafico(
                    titulo: 'Aplicações',
                    icone: Icons.timeline,
                    child: GraficoLinhaTempo(porData: porData, cor: AppCores.primaria),
                  ),
                  const TituloDash('Detalhamento'),
                  CartaoGrafico(
                    titulo: 'Top itens NOK',
                    icone: Icons.rule_outlined,
                    child: BarrasHorizontais(itens: topContagem(nokPorItem, n: 8), cor: AppCores.perigo),
                  ),
                  if (nokPorCategoria.length > 1)
                    CartaoGrafico(
                      titulo: 'NOK por categoria',
                      icone: Icons.category_outlined,
                      child: GraficoPizza(contagem: nokPorCategoria, rotuloCentro: 'NOK'),
                    ),
                  CartaoGrafico(
                    titulo: 'Top avaliadores',
                    icone: Icons.emoji_events_outlined,
                    child: BarrasHorizontais(itens: topContagem(contar(lista, 'avaliador'), n: 10), cor: AppCores.roxo),
                  ),
                ]),
        ),
      ),
    ]);
  }
}
