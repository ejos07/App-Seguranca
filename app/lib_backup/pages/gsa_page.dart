import 'package:flutter/material.dart';
import '../widgets/comum.dart';

// =====================================================
// GSA - Gabarito de Segurança do Armazém (espelho do GSA.tsx)
// =====================================================
const String kConforme = 'CONFORME';
const String kNaoConforme = 'NÃO CONFORME';

const Map<String, String> kFuncaoPorAvaliador = {
  'MATHEUS FREITAS CINTRA': 'SEGURANCA DO TRABALHO',
  'GABRIELE SILVA FERREIRA': 'SEGURANCA DO TRABALHO',
  'BRUNO FERNANDO PONTES ORTIZ': 'GOD',
  'JOSE AUGUSTO GUIRALDELI ANDRADE': 'SUP ARMAZEM',
};

const String kColunaObservacao = 'OUTROS (relatos de ato, condição e incidente no momento da inspeção)';

const List<String> kPerguntasGsa = [
  "EPI [LUVA ANTICORTE]",
  "GERAIS [Não permitir o trânsito de pessoas não autorizadas no armazém]",
  "GERAIS [Circulação de pedestres realizada em áreas demarcadas]",
  "GERAIS [Equipamentos de emergência (extintores e hidrantes) desobstruídos.]",
  "GERAIS [PTR emitida para trabalhos de risco (obras, reparos gerais, troca de lâmpadas, etc.)]",
  "GERAIS [Operação de carregamento realizada em área coberta]",
  "OPERAÇÃO DE EMPILHADEIRA [Transito de empilhadeira de ré carregadas]",
  "OPERAÇÃO DE EMPILHADEIRA [Trânsito de empilhadeiras acima ou no limite de velocidade permitido (20 km/h)]",
  "OPERAÇÃO DE EMPILHADEIRA [Operador de empilhadeira portando crachá de identificação com: exames médicos e treinamento de operador de empilhadeira em dia)]",
  "OPERAÇÃO DE EMPILHADEIRA [Distância mínima de 5m entre pedestres e empilhadeiras nas operações de carga e descarga]",
  "OPERAÇÃO DE EMPILHADEIRA [Sirene e luz de ré em perfeito estado de funcionamento]",
  "OPERAÇÃO DE EMPILHADEIRA [Utilização de cinto de segurança pelo operador]",
  "OPERAÇÃO DE EMPILHADEIRA [Empilhadeiras com proteção no teto (grade)]",
  "OPERAÇÃO DE CAMINHÃO [Durante o carregamento o motorista do caminhão e os ajudantes permanecem em local seguro (definido pela unidade), fora da cabine, a mais de 5 metros da operação.]",
  "ARMAZENAMENTO DE PRODUTOS [Produtos empilhados conforme padrão. Não permitir lotes inclinados, 3 de alta, etc.]",
  "ARMAZENAMENTO DE PRODUTOS [Palets empilhados com no máximo 2 metros de altura.]",
  "ARMAZENAMENTO DE PRODUTOS [Distância de empilhamento com no mínimo 50cm de distância de paredes e pilares]",
  "PENALIDADES ENCONTRADAS DURANTE A INSPEÇÃO [Permitir carona na empilhadeira]",
  "PENALIDADES ENCONTRADAS DURANTE A INSPEÇÃO [ Permitir a elevação de pessoas sobre os garfos de empilhadeiras]",
  "PENALIDADES ENCONTRADAS DURANTE A INSPEÇÃO [Subir, ou permitir que qualquer pessoa suba no caminhão para realizar qualquer tarefa durante o carregamento]",
  "CONDIÇÕES DO AMBIENTE [PLACAS DE SINALIZACAO]",
  "CONDIÇÕES DO AMBIENTE [FAIXA DE PEDESTRE]",
  "CONDIÇÕES DO AMBIENTE [SEM BURACOS NO PISO]",
  "CONDIÇÕES DO AMBIENTE [CONTEM ESPELHOS CONVEXOS]",
  "CONDIÇÕES DO AMBIENTE [CAIXA DE HIDRANTES EM BOM ESTADO]",
  "CONDIÇÕES DO AMBIENTE [SEM FIAÇÃO ELETRICA EXPOSTA]",
  "CONDIÇÕES DO AMBIENTE [Hidrantes quebrados]",
  "CONDIÇÕES DO AMBIENTE [SEM CACOS DE VIDROS ESPALHADOS]",
  "CONDIÇÕES DO AMBIENTE [EXTINTORES EM LOCAL CORRETO]",
  "EPI [OCULOS DE PROTECAO]",
  "EPI [BOTINA DE SEGURANCA]",
  "EPI [CINTA LOMBAR]",
  "EPI [UNIFORME / COLETE REFLETIVO]",
  "OPERAÇÃO DE CAMINHÃO [Chave do caminhão na porta]",
  "OPERAÇÃO DE CAMINHÃO [Freio de mão acionado]",
  "OPERAÇÃO DE CAMINHÃO [Pisca alerta acionado]",
  "PENALIDADES ENCONTRADAS DURANTE A INSPEÇÃO [Nenhuma empilhadeira parada ligada sem condutor com chave no comando]",
];

/// "GERAIS [Circulação...]" -> ('GERAIS', 'Circulação...')
(String, String) separarPerguntaGsa(String p) {
  final m = RegExp(r'^(.*?)\s*\[\s*(.*?)\s*\]\s*$').firstMatch(p);
  if (m == null) return ('OUTROS', p);
  return ((m.group(1) ?? '').trim(), m.group(2) ?? p);
}

/// Aceita "NAO CONFORME" (sem til) do histórico
String normalizarRespostaGsa(dynamic v) {
  final s = semAcento((v ?? '').toString()).toUpperCase().trim();
  if (s == 'CONFORME') return kConforme;
  if (s == 'NAO CONFORME') return kNaoConforme;
  return '';
}

class ResumoGsa {
  final int conformes;
  final int naoConformes;
  const ResumoGsa(this.conformes, this.naoConformes);
  int get total => conformes + naoConformes;
  double get pct => total == 0 ? 0.0 : conformes * 100 / total;
}

ResumoGsa resumoGsa(Map<String, dynamic> resp) {
  var c = 0;
  var nc = 0;
  for (final v in resp.values) {
    final r = normalizarRespostaGsa(v);
    if (r == kConforme) c++;
    if (r == kNaoConforme) nc++;
  }
  return ResumoGsa(c, nc);
}

Color corPct(double pct) =>
    pct >= 95 ? const Color(0xFF10B981) : (pct >= 85 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

class GsaPage extends StatefulWidget {
  const GsaPage({super.key});

  @override
  State<GsaPage> createState() => _GsaPageState();
}

class _GsaPageState extends State<GsaPage> {
  Sessao _sessao = Sessao.vazia;
  bool _carregandoSessao = true;

  List<Map<String, dynamic>> _historico = [];
  bool _carregandoHistorico = false;
  bool _historicoCarregado = false;
  String _erroHistorico = '';

  // Formulário
  DateTime _data = DateTime.now();
  String _horarioInicio = horaAgora();
  final Map<String, String> _respostas = {};
  final TextEditingController _obsCtrl = TextEditingController();
  final ScrollController _scrollForm = ScrollController();
  bool _tentouSalvar = false;
  bool _salvando = false;

  // Filtros
  String _busca = '';
  String _filtroAvaliador = '';
  String _filtroFuncao = '';
  DateTimeRange? _periodo;

  String get _avaliador => _sessao.nome.toUpperCase().trim();
  String get _funcao {
    final f = kFuncaoPorAvaliador[_avaliador];
    if (f != null) return f;
    return _sessao.cargo.isEmpty ? 'NÃO DEFINIDA' : _sessao.cargo;
  }

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
  }

  Future<void> _carregarHistorico() async {
    setState(() {
      _carregandoHistorico = true;
      _erroHistorico = '';
    });
    try {
      final r = await apiGet('/api/gsa/');
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

  void _marcarRestantesConforme() {
    setState(() {
      for (final p in kPerguntasGsa) {
        _respostas.putIfAbsent(p, () => kConforme);
      }
    });
  }

  Future<void> _limparRespostas() async {
    final ok = await confirmar(context, 'Limpar respostas', 'Deseja limpar todas as respostas?', ok: 'Limpar');
    if (ok) setState(() => _respostas.clear());
  }

  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();
    setState(() => _tentouSalvar = true);

    final faltam = kPerguntasGsa.where((p) => !_respostas.containsKey(p)).length;
    if (faltam > 0) return avisar(context, 'Faltam $faltam perguntas a serem respondidas (marcadas em vermelho).');

    final totalNc = _respostas.values.where((v) => v == kNaoConforme).length;
    if (totalNc > 0 && _obsCtrl.text.trim().isEmpty) {
      final continuar = await confirmar(
        context,
        'Observação vazia',
        'Foram marcados $totalNc itens como NÃO CONFORME e o campo de observações está vazio.\n\nDeseja salvar mesmo assim?',
        ok: 'Salvar mesmo assim',
        corOk: const Color(0xFF2563EB),
      );
      if (!continuar || !mounted) return;
    }

    final payload = {
      'data_gsa': dataIsoDe(_data),
      'avaliador': _avaliador,
      'funcao': _funcao,
      'respostas_dict': {for (final p in kPerguntasGsa) p: _respostas[p]},
      'observacao': _obsCtrl.text.trim(),
      'horario_inicio': _horarioInicio,
      'horario_final': horaAgora(),
    };

    setState(() => _salvando = true);
    try {
      final r = await apiPost('/api/gsa/', payload);
      if (!mounted) return;
      if (respostaOk(r)) {
        final prot = protocoloDe(decodificar(r), padrao: 'GSA-000000');
        avisar(context, 'GSA registrado com sucesso! Protocolo: $prot', erro: false);
        setState(() {
          _respostas.clear();
          _obsCtrl.clear();
          _tentouSalvar = false;
          _horarioInicio = horaAgora();
        });
        if (_scrollForm.hasClients) _scrollForm.jumpTo(0);
        _carregarHistorico();
      } else {
        avisar(context, mensagemErro(r, prefixo: 'Erro ao salvar GSA'));
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
      final resp = await apiDelete('/api/gsa/${Uri.encodeComponent(id)}');
      if (!mounted) return;
      if (respostaOk(resp)) {
        avisar(context, 'GSA excluído com sucesso!', erro: false);
        _carregarHistorico();
      } else {
        avisar(context, mensagemErro(resp, prefixo: 'Erro ao excluir'));
      }
    } catch (e) {
      if (mounted) avisar(context, 'Falha de conexão com o servidor.');
    }
  }

  List<String> _distintos(String campo) {
    final s = _historico.map((r) => (r[campo] ?? '').toString()).where((v) => v.isNotEmpty).toSet().toList();
    s.sort();
    return s;
  }

  List<Map<String, dynamic>> get _filtrados {
    final lista = _historico.where((r) {
      final matchBusca = contemTexto(r['avaliador'], _busca) ||
          contemTexto(r['protocolo'] ?? r['id'], _busca) ||
          contemTexto(r['observacao'], _busca);
      final matchAval = _filtroAvaliador.isEmpty || r['avaliador'] == _filtroAvaliador;
      final matchFunc = _filtroFuncao.isEmpty || r['funcao'] == _filtroFuncao;
      final matchData = dentroDoPeriodo(r['data_gsa'], _periodo);
      final matchPerfil = _sessao.podeExcluir || registroEhMeu(_sessao, kRegraGsa, r);
      return matchBusca && matchAval && matchFunc && matchData && matchPerfil;
    }).toList();
    lista.sort((a, b) => soDataIso(b['data_gsa']).compareTo(soDataIso(a['data_gsa'])));
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    const titulo = 'Gabarito do Armazém (GSA)';
    if (_carregandoSessao || (!_historicoCarregado && _erroHistorico.isEmpty)) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_historicoCarregado) {
      return TelaErro(titulo: titulo, mensagem: _erroHistorico, onTentarDeNovo: _carregarHistorico);
    }

    final nivel = calcularAcesso(_sessao, kRegraGsa, _historico);
    if (nivel == NivelAcesso.nenhum) {
      return const TelaSemAcesso(
        titulo: titulo,
        mensagem: 'O GSA é liberado para Gerente de Operações e Distribuição, Técnico e Analista de '
            'Segurança, Coordenador de Armazém e para quem já aplicou GSA.',
      );
    }
    final podeCriar = nivel == NivelAcesso.completo;

    final abas = <Tab>[
      if (podeCriar) const Tab(icon: Icon(Icons.add_circle_outline), text: 'Novo GSA'),
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
          title: const Text('Gabarito do Armazém (GSA)'),
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
    final respondidas = kPerguntasGsa.where((p) => _respostas.containsKey(p)).length;
    final nc = _respostas.values.where((v) => v == kNaoConforme).length;

    return SingleChildScrollView(
      controller: _scrollForm,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: CampoData(label: 'Data do Gabarito*', valor: _data, onChanged: (d) => setState(() => _data = d))),
          const SizedBox(width: 12),
          Expanded(child: CampoSomenteLeitura(label: 'Início (automático)', valor: _horarioInicio)),
        ]),
        const SizedBox(height: 14),
        CampoSomenteLeitura(label: 'Avaliador*', valor: _avaliador),
        const SizedBox(height: 14),
        CampoSomenteLeitura(label: 'Função*', valor: _funcao),
        const Divider(height: 36),
        Row(children: [
          const Expanded(child: Text('📋 Questionário GSA', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
          Text('$respondidas/${kPerguntasGsa.length}',
              style: TextStyle(fontWeight: FontWeight.bold, color: respondidas == kPerguntasGsa.length ? Colors.green : Colors.grey)),
          if (nc > 0) ...[const SizedBox(width: 8), Etiqueta('$nc NC', cor: Colors.red)],
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _marcarRestantesConforme,
              icon: const Icon(Icons.done_all, color: Color(0xFF10B981)),
              label: const Text('Restantes CONFORME', style: TextStyle(fontSize: 12.5)),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: _respostas.isEmpty ? null : _limparRespostas,
            icon: const Icon(Icons.cleaning_services_outlined),
            label: const Text('Limpar', style: TextStyle(fontSize: 12.5)),
          ),
        ]),
        const SizedBox(height: 12),
        ...List.generate(kPerguntasGsa.length, (i) {
          final p = kPerguntasGsa.elementAt(i);
          final (cat, item) = separarPerguntaGsa(p);
          return PerguntaBinaria(
            numero: i + 1,
            categoria: cat,
            pergunta: item,
            valor: _respostas[p],
            opcaoBoa: kConforme,
            opcaoRuim: kNaoConforme,
            destacarFalta: _tentouSalvar,
            onChanged: (v) => setState(() => _respostas[p] = v),
          );
        }),
        const SizedBox(height: 12),
        TextField(
          controller: _obsCtrl,
          maxLines: 4,
          decoration: decoracao(kColunaObservacao, hint: 'Descreva aqui atos, condições ou incidentes identificados...'),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _salvando ? null : _salvar,
            icon: _salvando
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: Text(_salvando ? 'Salvando...' : 'Finalizar e Salvar GSA', style: const TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _barraFiltros() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(children: [
        CampoBuscaTexto(
            hint: 'Buscar por avaliador, protocolo ou observação...', onChanged: (v) => setState(() => _busca = v)),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            FiltroPeriodo(periodo: _periodo, onChanged: (p) => setState(() => _periodo = p)),
            if (_sessao.podeExcluir) ...[
              const SizedBox(width: 8),
              FiltroMenu(
                  rotulo: 'Avaliador',
                  valor: _filtroAvaliador,
                  opcoes: _distintos('avaliador'),
                  onChanged: (v) => setState(() => _filtroAvaliador = v)),
              const SizedBox(width: 8),
              FiltroMenu(
                  rotulo: 'Função',
                  valor: _filtroFuncao,
                  opcoes: _distintos('funcao'),
                  onChanged: (v) => setState(() => _filtroFuncao = v)),
            ],
          ]),
        ),
      ]),
    );
  }

  /// Respostas agrupadas por categoria (igual ao detalhamento da web)
  List<Widget> _respostasAgrupadas(Map<String, dynamic> resp) {
    if (resp.isEmpty) {
      return [const Text('Nenhuma resposta de checklist registrada.', style: TextStyle(color: Colors.grey))];
    }
    final grupos = <String, Map<String, dynamic>>{};
    resp.forEach((k, v) {
      final (cat, item) = separarPerguntaGsa(k);
      grupos.putIfAbsent(cat, () => <String, dynamic>{})[item] = normalizarRespostaGsa(v).isEmpty ? v : normalizarRespostaGsa(v);
    });
    final out = <Widget>[];
    grupos.forEach((cat, itens) {
      out.add(Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 2),
        child: Text(cat, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
      ));
      out.add(ListaRespostas(respostas: itens, ehRuim: (v) => normalizarRespostaGsa(v) == kNaoConforme));
    });
    return out;
  }

  Widget _abaConsulta() {
    final lista = _filtrados;
    Widget corpo;
    if (_carregandoHistorico && _historico.isEmpty) {
      corpo = const Center(child: CircularProgressIndicator());
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
          final res = resumoGsa(resp);
          final obs = (r['observacao'] ?? '').toString().trim();
          return CardRegistro(
            fotoNome: (r['avaliador'] ?? '').toString(),
            titulo: (r['protocolo'] ?? r['id'] ?? '-').toString(),
            subtitulo: '${dataBr(r['data_gsa'])} • ${r['funcao'] ?? '-'}\nAvaliador: ${r['avaliador'] ?? '-'}',
            etiqueta: Etiqueta(res.total == 0 ? '-' : '${res.pct.toStringAsFixed(1)}%', cor: corPct(res.pct)),
            cor: const Color(0xFF7C3AED),
            onExcluir: _sessao.podeExcluir ? () => _excluir(r) : null,
            detalhes: [
              LinhaDetalhe('Horário', 'Início ${r['horario_inicio'] ?? '-'} | Fim ${r['horario_final'] ?? '-'}'),
              LinhaDetalhe('Conformes', '${res.conformes}'),
              LinhaDetalhe('Não conformes', '${res.naoConformes}'),
              if (obs.isNotEmpty) ...[const SizedBox(height: 8), CaixaObservacao(obs)],
              const SizedBox(height: 6),
              ..._respostasAgrupadas(resp),
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
    var totalC = 0;
    var totalNc = 0;
    final ncPorItem = <String, int>{};
    final porCategoria = <String, List<int>>{}; // [conformes, nc]
    final qtdPorData = <String, double>{};
    final cPorData = <String, int>{};
    final totPorData = <String, int>{};

    for (final g in lista) {
      final d = soDataIso(g['data_gsa']);
      qtdPorData[d] = (qtdPorData[d] ?? 0.0) + 1;
      respostasDe(g['respostas_dict']).forEach((pergunta, valor) {
        final r = normalizarRespostaGsa(valor);
        if (r.isEmpty) return;
        final (cat, item) = separarPerguntaGsa(pergunta);
        final par = porCategoria.putIfAbsent(cat, () => [0, 0]);
        totPorData[d] = (totPorData[d] ?? 0) + 1;
        if (r == kConforme) {
          totalC++;
          par.first++;
          cPorData[d] = (cPorData[d] ?? 0) + 1;
        } else {
          totalNc++;
          par.last++;
          ncPorItem[item] = (ncPorItem[item] ?? 0) + 1;
        }
      });
    }

    final totalResp = totalC + totalNc;
    final pctGeral = totalResp == 0 ? 0.0 : totalC * 100 / totalResp;
    final comObs = lista.where((g) => (g['observacao'] ?? '').toString().trim().isNotEmpty).length;
    final comNc = lista.where((g) => resumoGsa(respostasDe(g['respostas_dict'])).naoConformes > 0).length;

    // % por categoria: pior primeiro
    final cats = porCategoria.entries.map((e) {
      final c = e.value.first;
      final nc = e.value.last;
      final pct = (c + nc) == 0 ? 0.0 : c * 100 / (c + nc);
      return ItemBarra(e.key, pct, cor: corPct(pct), texto: '${pct.toStringAsFixed(1)}%');
    }).toList()
      ..sort((a, b) => a.valor.compareTo(b.valor));

    final pctPorData = <String, double>{};
    totPorData.forEach((d, t) {
      if (t > 0) pctPorData[d] = (cPorData[d] ?? 0) * 100 / t;
    });

    return Column(children: [
      _barraFiltros(),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _carregarHistorico,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            GradeKpis([
              KpiCard(titulo: 'Total de GSAs', valor: '${lista.length}', cor: const Color(0xFF3B82F6)),
              KpiCard(
                  titulo: '% Conformidade Geral',
                  valor: totalResp == 0 ? '-' : '${pctGeral.toStringAsFixed(1)}%',
                  cor: corPct(pctGeral)),
              KpiCard(titulo: 'Itens Não Conformes', valor: '$totalNc', cor: const Color(0xFFEF4444)),
              KpiCard(titulo: 'GSAs c/ Não Conformidade', valor: '$comNc', cor: const Color(0xFFF59E0B)),
              KpiCard(titulo: 'GSAs c/ Observação', valor: '$comObs', cor: const Color(0xFF8B5CF6)),
            ]),
            CartaoGrafico(titulo: '% Conformidade por Categoria', child: BarrasHorizontais(itens: cats, maximo: 100)),
            CartaoGrafico(
              titulo: 'Top 10 Itens Não Conformes',
              child: ncPorItem.isEmpty
                  ? const Text('Nenhuma não conformidade no período 🎉', style: TextStyle(color: Colors.grey))
                  : BarrasHorizontais(itens: topContagem(ncPorItem), cor: const Color(0xFFEF4444)),
            ),
            CartaoGrafico(titulo: 'GSAs por Avaliador', child: GraficoPizza(contagem: contar(lista, 'avaliador'))),
            CartaoGrafico(
              titulo: 'GSAs realizados por dia',
              child: GraficoLinhaTempo(porData: qtdPorData, cor: const Color(0xFF3B82F6)),
            ),
            CartaoGrafico(
              titulo: '% Conformidade por dia',
              child: GraficoLinhaTempo(porData: pctPorData, cor: const Color(0xFF10B981), maxY: 100),
            ),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    ]);
  }
}
