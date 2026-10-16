import 'package:flutter/material.dart';
import '../widgets/comum.dart';

// =====================================================
// GSD - Diálogos de Segurança (espelho do GSD.tsx)
// =====================================================
const List<String> kDepartamentosGsd = ["ADMINISTRATIVO", "ARMAZÉM", "DISTRIBUIÇÃO", "FROTA", "SEGURANÇA"];

const List<String> kPerguntasGsd = [
  "A equipe utiliza cinto de segurança durante todo o trajeto ?",
  "O motorista conduz o veículo em velocidade compatível com a via ?",
  "O motorista cumpre todas as normas regidas pelo código de trânsito ?",
  "O motorista pratica direção segura e faz todas as sinalizações durante o trajeto ?",
  "O veículo é estacionado em local adequado (permitido por lei), e de forma segura ?",
  "O motorista utiliza câmera de ré durante a manobra de estacionamento ?",
  "O(s) ajudante(s) auxilia o motorista na manobra de estacionamento e se posiciona de forma segura, sem exposição a riscos ?",
  "Em caso de aclive/declive, o calço/trava rodas é posicionado corretamente conforme orientação do treinamento feito pelo motorista educador da Fabet ?",
  "O freio de estacionamento foi acionado corretamente ?",
  "A área do freio de estacionamento e dos pedais está livre de objetos que podem causar desacionamento involuntário (garrafas, mochilas, etc.) ?",
  "Em casos de docas, o caminhão é estacionado corretamente e a equipe permanece em local segregado das máquinas de descarga ?",
  "O veículo permanece trancado e com a chave sob posse do motorista durante todo o processo de entrega ?",
  "A equipe utiliza o cone de segurança conforme padrão de entrega ?",
  "A equipe se movimenta em área segura, mantendo atenção ao fluxo de veículos ?",
  "No deslocamento entre o veículo e o PDV, a equipe tem cuidado ao atravessar vias e/ou obstáculos no percurso ?",
  "A equipe cumprimenta o cliente, valida nota fiscal e vasilhames antes de iniciar a entrega ?",
  "A equipe utiliza todos EPIs obrigatórios durante todo o processo de entrega ?",
  "A equipe abre corretamente as baias/porta da van ?",
  "A equipe utiliza corretamente os 3 pontos de apoio ao subir e descer do veículo ?",
  "A equipe manuseia o carrinho/paleteira/plataforma corretamente ?",
  "O colaborador se posiciona corretamente na plataforma durante a movimentação dos produtos, mantendo-a livre de produtos empilhados ?",
  "A equipe manuseia os produtos conforme padrão ?",
  "No PDV, se há escadas até o depósito, a equipe carrega 1 cx retornável por vez ?",
  "A equipe cumpre a entrega seguindo o passo a passo descrito nos treinamentos de Qualidade ?",
  "Em caso de avarias durante a entrega ou identificadas dentro do caminhão, a equipe consegue resolver o problema junto ao cliente ?",
  "No caso da armazenagem do cliente conter condições de risco á qualidade do produto, o mesmo é orientado pelo time de entrega ?",
  "Caso haja devolução de qualidade, esses produtos são alocados separadamente dentro do veículo para retorno a revenda ?",
  "Em caso de problemas com recebimento, o motorista sinaliza a central de monitoramento de maneira digital ?",
  "Durante a entrega, a equipe usa as ferramentas digitais com facilidade ?",
  "Equipe avalia no BEES os risco do local de entrega ?",
  "A equipe consegue orientar e ajudar o cliente em caso de problemas com a entrega/forma de pagamento e outros motivos ?",
  "Ao recolher os vasilhames no fim da entrega, faz apuração do refugo e organiza as caixas no caminhão, conforme a necessidade ?",
  "A equipe agradece e pede ao cliente para fazer avaliação da entrega ?",
  "A equipe usa tecnologia para finalizar a entrega e notificar a próxima através do BEES DELIVERY ?",
  "Equipe guarda o carrinho corretamente após a utilização ?",
  "A equipe verifica fechamento das baias/saider/portas antes de sair do PDV, utilizando o trava baias ?",
  "Calço e cones foram retirados corretamente conforme orientação da FABET após a finalização da entrega ?",
  "O motorista faz o giro 360º antes de sair com o veículo, avaliando se existe algum obstáculo que dificulte a manobra ou algo embaixo do caminhão ?",
  "Caso seja necessária uma manobra de ré, o ajudante se posiciona em local correto e auxilia o motorista ?",
];

class GsdPage extends StatefulWidget {
  const GsdPage({super.key});

  @override
  State<GsdPage> createState() => _GsdPageState();
}

class _GsdPageState extends State<GsdPage> {
  Sessao _sessao = Sessao.vazia;
  bool _carregandoSessao = true;

  // Dados
  List<String> _equipe = [];
  bool _carregandoEquipe = false;
  List<Map<String, dynamic>> _historico = [];
  bool _carregandoHistorico = false;
  bool _historicoCarregado = false;
  String _erroHistorico = '';

  // Formulário
  DateTime _data = DateTime.now();
  String _horarioInicio = horaAgora();
  String _unb = kListaUnbs.first;
  String _departamento = kDepartamentosGsd.first;
  String? _relatado;
  Key _chaveBusca = UniqueKey();
  final Map<String, String> _respostas = {};
  final TextEditingController _obsCtrl = TextEditingController();
  final ScrollController _scrollForm = ScrollController();
  bool _tentouSalvar = false;
  bool _salvando = false;

  // Filtros
  String _busca = '';
  String _filtroUnb = '';
  String _filtroDep = '';

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  @override
  void dispose() {
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
      debugPrint('Erro equipe GSD: $e');
      if (mounted) setState(() => _carregandoEquipe = false);
    }
  }

  Future<void> _carregarHistorico() async {
    setState(() {
      _carregandoHistorico = true;
      _erroHistorico = '';
    });
    try {
      final r = await apiGet('/api/gsd/');
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

  // ---------------- SALVAR ----------------
  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();
    setState(() => _tentouSalvar = true);

    if (_relatado == null) return avisar(context, 'Selecione um Colaborador Avaliado da lista.');

    final faltam = kPerguntasGsd.where((p) => !_respostas.containsKey(p)).toList();
    if (faltam.isNotEmpty) {
      return avisar(context, 'Faltam ${faltam.length} perguntas a serem respondidas (marcadas em vermelho).');
    }

    final payload = {
      'unb': _unb,
      'departamento': _departamento,
      'relatado': _relatado,
      'data_relato': dataIsoDe(_data),
      'observacao': _obsCtrl.text.trim(),
      'relator': _sessao.nome,
      'respostas_dict': {for (final p in kPerguntasGsd) p: _respostas[p]},
      'horario_inicio': _horarioInicio,
      'horario_final': horaAgora(),
    };

    setState(() => _salvando = true);
    try {
      final r = await apiPost('/api/gsd/', payload);
      if (!mounted) return;
      if (respostaOk(r)) {
        final prot = protocoloDe(decodificar(r), padrao: 'GSD-000000');
        avisar(context, 'GSD registrado com sucesso! Protocolo: $prot', erro: false);
        setState(() {
          _relatado = null;
          _chaveBusca = UniqueKey();
          _respostas.clear();
          _obsCtrl.clear();
          _tentouSalvar = false;
          _horarioInicio = horaAgora();
        });
        if (_scrollForm.hasClients) _scrollForm.jumpTo(0);
        _carregarHistorico();
      } else {
        avisar(context, mensagemErro(r, prefixo: 'Erro ao salvar GSD'));
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
      final resp = await apiDelete('/api/gsd/${Uri.encodeComponent(id)}');
      if (!mounted) return;
      if (respostaOk(resp)) {
        avisar(context, 'GSD excluído com sucesso!', erro: false);
        _carregarHistorico();
      } else {
        avisar(context, mensagemErro(resp, prefixo: 'Erro ao excluir'));
      }
    } catch (e) {
      if (mounted) avisar(context, 'Falha de conexão com o servidor.');
    }
  }

  // ---------------- FILTROS ----------------
  List<Map<String, dynamic>> get _filtrados {
    final lista = _historico.where((r) {
      final matchBusca = contemTexto(r['relatado'], _busca) || contemTexto(r['relator'], _busca);
      final matchUnb = _filtroUnb.isEmpty || r['unb'] == _filtroUnb;
      final matchDep = _filtroDep.isEmpty || r['departamento'] == _filtroDep;
      final matchPerfil = _sessao.podeExcluir || registroEhMeu(_sessao, kRegraGsd, r);
      return matchBusca && matchUnb && matchDep && matchPerfil;
    }).toList();
    lista.sort((a, b) => soDataIso(b['data_relato']).compareTo(soDataIso(a['data_relato'])));
    return lista;
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    const titulo = 'Diálogos de Segurança (GSD)';
    if (_carregandoSessao || (!_historicoCarregado && _erroHistorico.isEmpty)) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_historicoCarregado) {
      return TelaErro(titulo: titulo, mensagem: _erroHistorico, onTentarDeNovo: _carregarHistorico);
    }

    final nivel = calcularAcesso(_sessao, kRegraGsd, _historico);
    if (nivel == NivelAcesso.nenhum) {
      return const TelaSemAcesso(
        titulo: titulo,
        mensagem: 'O GSD é liberado para Motorista Caminhão Distribuição, Ajudante Distribuição, '
            'para quem já foi avaliado e para quem já aplicou GSD.',
      );
    }
    final podeCriar = nivel == NivelAcesso.completo;

    final abas = <Tab>[
      if (podeCriar) const Tab(icon: Icon(Icons.add_circle_outline), text: 'Novo GSD'),
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
          title: const Text('Diálogos de Segurança (GSD)'),
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
    final respondidas = kPerguntasGsd.where((p) => _respostas.containsKey(p)).length;
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
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: CampoData(label: 'Data*', valor: _data, onChanged: (d) => setState(() => _data = d)),
                  ),
                  const SizedBox(width: AppEspaco.m),
                  Expanded(
                    child: CampoSomenteLeitura(label: 'Início', valor: _horarioInicio, icone: Icons.schedule),
                  ),
                ]),
                const SizedBox(height: AppEspaco.m),
                Row(children: [
                  Expanded(
                    child: CampoDropdown(
                      label: 'UNB*',
                      opcoes: kListaUnbs,
                      valor: _unb,
                      onChanged: (v) {
                        if (v == null || v == _unb) return;
                        setState(() {
                          _unb = v;
                          _relatado = null;
                          _chaveBusca = UniqueKey();
                        });
                        _carregarEquipe(v);
                      },
                    ),
                  ),
                  const SizedBox(width: AppEspaco.m),
                  Expanded(
                    child: CampoDropdown(
                      label: 'Departamento*',
                      opcoes: kDepartamentosGsd,
                      valor: _departamento,
                      onChanged: (v) => setState(() => _departamento = v ?? _departamento),
                    ),
                  ),
                ]),
              ]),
            ),
            SecaoForm(
              titulo: 'Pessoas',
              icone: Icons.groups_2_outlined,
              child: Column(children: [
                CampoSomenteLeitura(label: 'Aplicador', valor: _sessao.nome, icone: Icons.person_outline),
                const SizedBox(height: AppEspaco.m),
                CampoBuscaPessoa(
                  key: _chaveBusca,
                  label: 'Colaborador avaliado*',
                  opcoes: _equipe,
                  carregando: _carregandoEquipe,
                  onChanged: (v) => setState(() => _relatado = v),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppEspaco.xs, AppEspaco.xs, AppEspaco.xs, AppEspaco.m),
              child: Text('QUESTIONÁRIO GSD • ${kPerguntasGsd.length} PERGUNTAS', style: AppTexto.rotulo),
            ),
            ...List.generate(kPerguntasGsd.length, (i) {
              final p = kPerguntasGsd.elementAt(i);
              return PerguntaBinaria(
                numero: i + 1,
                pergunta: p,
                valor: _respostas[p],
                destacarFalta: _tentouSalvar,
                onChanged: (v) => setState(() => _respostas[p] = v),
              );
            }),
            const SizedBox(height: AppEspaco.s),
            SecaoForm(
              titulo: 'Observações',
              subtitulo: 'Alguma observação identificada? Se sim, descreva.',
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
        rotulo: 'Finalizar e salvar GSD',
        icone: Icons.send_rounded,
        carregando: _salvando,
        onPressed: _salvar,
        topo: ProgressoChecklist(respondidas: respondidas, total: kPerguntasGsd.length, ruins: nok),
      ),
    ]);
  }

  Widget _barraFiltros() {
    return BarraFiltros(
      hint: 'Buscar por colaborador ou aplicador...',
      onBusca: (v) => setState(() => _busca = v),
      filtros: [
        FiltroMenu(rotulo: 'UNB', valor: _filtroUnb, opcoes: kListaUnbs, onChanged: (v) => setState(() => _filtroUnb = v)),
        FiltroMenu(
            rotulo: 'Departamento',
            valor: _filtroDep,
            opcoes: kDepartamentosGsd,
            onChanged: (v) => setState(() => _filtroDep = v)),
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
            fotoNome: (r['relatado'] ?? '').toString(),
            titulo: (r['protocolo'] ?? r['id'] ?? '-').toString(),
            subtitulo: '${dataBr(r['data_relato'])} • ${r['unb'] ?? '-'} • ${r['departamento'] ?? '-'}\n'
                'Avaliado: ${r['relatado'] ?? '-'}',
            etiqueta: nok > 0 ? Etiqueta('$nok NOK', cor: Colors.red) : const Etiqueta('100% OK', cor: Colors.green),
            onExcluir: _sessao.podeExcluir ? () => _excluir(r) : null,
            detalhes: [
              LinhaDetalhe('Aplicador', r['relator']),
              LinhaDetalhe('Colaborador avaliado', r['relatado']),
              LinhaDetalhe('Horário', 'Início ${r['horario_inicio'] ?? '-'} | Fim ${r['horario_final'] ?? '-'}'),
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
    final avaliados = lista.map((g) => (g['relatado'] ?? '').toString()).where((s) => s.isNotEmpty).toSet().length;
    final aplicadores = lista.map((g) => (g['relator'] ?? '').toString()).where((s) => s.isNotEmpty).toSet().length;
    final comObs = lista.where((g) => (g['observacao'] ?? '').toString().trim().isNotEmpty).length;

    var ok = 0;
    var nok = 0;
    final nokPorItem = <String, int>{};
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
          nokPorItem[k] = (nokPorItem[k] ?? 0) + 1;
        }
      });
    }
    final respondidas = ok + nok;
    final pct = respondidas == 0 ? 0.0 : ok * 100 / respondidas;
    final pctDia = <String, double>{};
    totDia.forEach((d, t) {
      if (t > 0 && d.isNotEmpty) pctDia[d] = (okDia[d] ?? 0) * 100 / t;
    });
    final comNok = lista.where((g) => respostasDe(g['respostas_dict']).values.any((v) => v.toString().toUpperCase() == 'NOK')).length;

    final (status, corStatus) = pct >= 95
        ? ('Padrão atingido', AppCores.sucesso)
        : (pct >= 85 ? ('Atenção', AppCores.alerta) : ('Abaixo do padrão', AppCores.perigo));

    final mensal = empilharPorMes(lista,
        campoData: 'data_relato',
        qtdSeries: 2,
        serieDe: (g) => respostasDe(g['respostas_dict']).values.any((v) => v.toString().toUpperCase() == 'NOK') ? 1 : 0);

    return Column(children: [
      _barraFiltros(),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _carregarHistorico,
          child: total == 0
              ? ListView(children: const [
                  SizedBox(height: 60),
                  EstadoVazio('Sem GSDs no filtro atual.', icone: Icons.insights_outlined),
                ])
              : ListView(padding: const EdgeInsets.fromLTRB(AppEspaco.l, AppEspaco.l, AppEspaco.l, AppEspaco.xxl), children: [
                  PainelIndice(
                    titulo: 'Conformidade dos GSDs',
                    percentual: pct,
                    status: status,
                    corStatus: corStatus,
                    descricao: 'Itens OK sobre o total de itens avaliados.',
                    numeros: [
                      ('$total', 'GSDs'),
                      ('$avaliados', 'avaliados'),
                      ('$nok', 'itens NOK'),
                    ],
                  ),
                  const TituloDash('Indicadores'),
                  GradeKpis([
                    KpiCard(
                        titulo: 'Colaboradores avaliados',
                        valor: '$avaliados',
                        cor: AppCores.info,
                        icone: Icons.groups_outlined),
                    KpiCard(
                        titulo: 'Aplicadores ativos',
                        valor: '$aplicadores',
                        cor: AppCores.roxo,
                        icone: Icons.badge_outlined,
                        subtitulo: aplicadores == 0 ? null : '${(total / aplicadores).toStringAsFixed(1)} GSD por aplicador'),
                    KpiCard(
                        titulo: 'GSDs com NOK',
                        valor: '$comNok',
                        cor: AppCores.perigo,
                        icone: Icons.gpp_maybe_outlined,
                        fracao: total == 0 ? 0 : comNok / total,
                        subtitulo: total == 0 ? null : '${(comNok * 100 / total).toStringAsFixed(0)}% dos GSDs'),
                    KpiCard(
                        titulo: 'GSDs com observação',
                        valor: '$comObs',
                        cor: AppCores.alerta,
                        icone: Icons.notes_outlined),
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
                    titulo: 'GSDs por mês',
                    subtitulo: 'Sem NOK x com NOK',
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
                    subtitulo: 'Perguntas com mais reprovações',
                    icone: Icons.rule_outlined,
                    child: BarrasHorizontais(itens: topContagem(nokPorItem, n: 8), cor: AppCores.perigo),
                  ),
                  CartaoGrafico(
                    titulo: 'Por departamento',
                    icone: Icons.apartment_outlined,
                    child: GraficoPizza(contagem: contar(lista, 'departamento'), rotuloCentro: 'GSDs'),
                  ),
                  CartaoGrafico(
                    titulo: 'Por UNB',
                    icone: Icons.business_outlined,
                    child: GraficoPizza(contagem: contar(lista, 'unb'), rotuloCentro: 'GSDs'),
                  ),
                  CartaoGrafico(
                    titulo: 'Top aplicadores',
                    icone: Icons.emoji_events_outlined,
                    child: BarrasHorizontais(itens: topContagem(contar(lista, 'relator'), n: 10), cor: AppCores.roxo),
                  ),
                ]),
        ),
      ),
    ]);
  }
}
