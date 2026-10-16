import 'package:flutter/material.dart';
import '../widgets/comum.dart';

// =====================================================
// Relatos: Consultar + Dashboard
// =====================================================
const List<String> kTiposRelato = ['Ato inseguro', 'Condição insegura', 'Abordagem positiva', 'Incidente'];

/// Cor e ícone de cada classificação (usado na lista e no dashboard)
(Color, IconData) estiloClassificacao(dynamic classificacao) {
  final s = semAcento((classificacao ?? '').toString()).toLowerCase();
  if (s.contains('ato inseguro')) return (AppCores.perigo, Icons.back_hand_outlined);
  if (s.contains('condic')) return (AppCores.alerta, Icons.warning_amber_rounded);
  if (s.contains('positiva') || s.contains('reconhecimento')) return (AppCores.sucesso, Icons.thumb_up_alt_outlined);
  if (s.contains('incidente')) return (AppCores.info, Icons.report_outlined);
  return (AppCores.textoSuave, Icons.assignment_outlined);
}

class RelatosPage extends StatefulWidget {
  const RelatosPage({super.key});

  @override
  State<RelatosPage> createState() => _RelatosPageState();
}

class _RelatosPageState extends State<RelatosPage> {
  Sessao _sessao = Sessao.vazia;
  List<Map<String, dynamic>> _relatosGerais = [];
  bool _isLoading = true;
  String _erro = '';

  // Filtros
  String _busca = '';
  DateTimeRange? _periodo;
  String _tipo = '';

  @override
  void initState() {
    super.initState();
    _inicializarTela();
  }

  Future<void> _inicializarTela() async {
    final s = await Sessao.carregar();
    if (!mounted) return;
    setState(() => _sessao = s);
    await _carregarRelatos();
  }

  Future<void> _carregarRelatos() async {
    setState(() {
      _isLoading = true;
      _erro = '';
    });
    try {
      final r = await apiGet('/api/relatos');
      if (!mounted) return;
      if (respostaOk(r)) {
        setState(() => _relatosGerais = listaDados(decodificar(r)));
      } else {
        setState(() => _erro = mensagemErro(r, prefixo: 'Erro do servidor'));
      }
    } catch (e) {
      if (mounted) setState(() => _erro = 'Falha de conexão com o servidor.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _veTudo => _sessao.perfil == 'admin' || _sessao.perfil == 'tecnico';

  List<Map<String, dynamic>> get _relatosFiltrados {
    final eu = chaveNome(_sessao.nome);
    final lista = _relatosGerais.where((r) {
      final matchPerfil = _veTudo || chaveNome(r['relator']) == eu || chaveNome(r['relatado']) == eu;
      final matchData = dentroDoPeriodo(r['data_relato'], _periodo);
      final matchTipo = _tipo.isEmpty || contemTexto(r['classificacao'], _tipo);
      final matchBusca = _busca.trim().isEmpty ||
          contemTexto(r['protocolo'], _busca) ||
          contemTexto(r['relator'], _busca) ||
          contemTexto(r['relatado'], _busca) ||
          contemTexto(r['area_relatada'], _busca) ||
          contemTexto(r['descricao'], _busca);
      return matchPerfil && matchData && matchTipo && matchBusca;
    }).toList();
    lista.sort((a, b) => soDataIso(b['data_relato']).compareTo(soDataIso(a['data_relato'])));
    return lista;
  }

  Future<void> _novoRelato() async {
    await Navigator.pushNamed(context, '/novo_relato');
    if (mounted) _carregarRelatos();
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _relatosFiltrados;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Relatos'),
          actions: [
            IconButton(
              tooltip: 'Atualizar',
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : _carregarRelatos,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.view_list_rounded), text: 'Consultar'),
              Tab(icon: Icon(Icons.insights_rounded), text: 'Dashboard'),
            ],
          ),
        ),
        body: Column(children: [
          BarraFiltros(
            hint: 'Buscar protocolo, pessoa, área...',
            onBusca: (v) => setState(() => _busca = v),
            filtros: [
              FiltroPeriodo(periodo: _periodo, onChanged: (p) => setState(() => _periodo = p)),
            ],
          ),
          Container(
            color: AppCores.superficie,
            padding: const EdgeInsets.fromLTRB(AppEspaco.m, 0, AppEspaco.m, AppEspaco.s),
            child: FiltroOpcoes(
              opcoes: kTiposRelato,
              valor: _tipo,
              onChanged: (v) => setState(() => _tipo = v),
            ),
          ),
          Expanded(
            child: TabBarView(children: [
              _buildAbaLista(filtrados),
              _isLoading && _relatosGerais.isEmpty
                  ? const ListaCarregando(itens: 3)
                  : _RelatosDashboardView(relatos: filtrados),
            ]),
          ),
        ]),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'fab_novo_relato',
          onPressed: _novoRelato,
          icon: const Icon(Icons.add),
          label: const Text('Novo Relato', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _buildAbaLista(List<Map<String, dynamic>> lista) {
    Widget corpo;
    if (_isLoading && _relatosGerais.isEmpty) {
      corpo = const ListaCarregando();
    } else if (_erro.isNotEmpty) {
      corpo = EstadoVazio(_erro, icone: Icons.cloud_off_rounded, onAcao: _carregarRelatos);
    } else if (lista.isEmpty) {
      corpo = EstadoVazio(
        'Nenhum relato encontrado',
        icone: Icons.search_off_rounded,
        subtitulo: _veTudo ? 'Ajuste os filtros acima.' : 'Aqui aparecem os relatos feitos por você ou sobre você.',
      );
    } else {
      corpo = ListView.builder(
        padding: const EdgeInsets.fromLTRB(AppEspaco.m, AppEspaco.s, AppEspaco.m, 96),
        itemCount: lista.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(AppEspaco.xs, AppEspaco.xs, 0, AppEspaco.s),
              child: Text('${lista.length} ${lista.length == 1 ? 'RELATO' : 'RELATOS'}', style: AppTexto.rotulo),
            );
          }
          return _buildRelatoCard(lista.elementAt(i - 1));
        },
      );
    }
    return RefreshIndicator(onRefresh: _carregarRelatos, child: corpo);
  }

  Widget _buildRelatoCard(Map<String, dynamic> r) {
    final (cor, icone) = estiloClassificacao(r['classificacao']);
    final classif = (r['classificacao'] ?? '').toString();
    final processo = r['processo'];
    final processoTxt = processo is List ? processo.join(', ') : (processo ?? '').toString();
    final relatado = (r['relatado'] ?? '').toString();
    final temPessoa = relatado.isNotEmpty && !relatado.toUpperCase().startsWith('NÃO SE APLICA');
    final desc = (r['descricao'] ?? '').toString().trim();

    return CardRegistro(
      cor: cor,
      icone: icone,
      fotoNome: temPessoa ? relatado : null,
      titulo: (r['protocolo'] ?? 'Sem protocolo').toString(),
      subtitulo: '${dataBr(r['data_relato'])} • ${r['area_relatada'] ?? '-'}'
          '${temPessoa ? '\n$relatado' : ''}',
      etiqueta: Etiqueta(classif.isEmpty ? '-' : classif.split(' (').first, cor: cor),
      detalhes: [
        LinhaDetalhe('Relator', r['relator']),
        LinhaDetalhe('Envolvido', relatado),
        LinhaDetalhe('UNB', r['unb']),
        LinhaDetalhe('Departamento', r['departamento']),
        LinhaDetalhe('Detalhe', r['detalhe_classificacao']),
        LinhaDetalhe('Processo', processoTxt),
        LinhaDetalhe('Ação imediata', r['acao_imediata']),
        if (desc.isNotEmpty) ...[
          const SizedBox(height: AppEspaco.s),
          CaixaObservacao(desc, titulo: 'Descrição'),
        ],
      ],
    );
  }
}

// ==========================================
// ABA 2: DASHBOARD DE RELATOS
// ==========================================
const List<String> _kSeriesRelato = ['Ato inseguro', 'Condição insegura', 'Abordagem positiva', 'Incidente'];
const List<Color> _kCoresRelato = [AppCores.perigo, AppCores.alerta, AppCores.sucesso, AppCores.info];

/// 0 = ato, 1 = condição, 2 = positiva, 3 = incidente, -1 = outro
int indiceTipoRelato(dynamic classificacao) {
  final s = semAcento((classificacao ?? '').toString()).toLowerCase();
  if (s.contains('ato inseguro')) return 0;
  if (s.contains('condic')) return 1;
  if (s.contains('positiva') || s.contains('reconhecimento')) return 2;
  if (s.contains('incidente')) return 3;
  return -1;
}

class _RelatosDashboardView extends StatelessWidget {
  final List<dynamic> relatos;

  const _RelatosDashboardView({required this.relatos});

  @override
  Widget build(BuildContext context) {
    final lista = relatos.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    if (lista.isEmpty) {
      return const EstadoVazio('Sem dados para o dashboard.',
          icone: Icons.insights_outlined, subtitulo: 'Ajuste os filtros ou o período para ver os indicadores.');
    }

    final total = lista.length;
    final porTipo = List<int>.filled(4, 0);
    for (final r in lista) {
      final i = indiceTipoRelato(r['classificacao']);
      if (i >= 0) porTipo[i] = porTipo.elementAt(i) + 1;
    }
    final atos = porTipo.elementAt(0);
    final condicoes = porTipo.elementAt(1);
    final positivos = porTipo.elementAt(2);
    final incidentes = porTipo.elementAt(3);
    final desvios = atos + condicoes;
    final indice = total == 0 ? 0.0 : positivos * 100 / total;

    final (status, corStatus) = indice >= 50
        ? ('Bom desempenho', AppCores.sucesso)
        : (indice >= 30 ? ('Atenção', AppCores.alerta) : ('Situação crítica', AppCores.perigo));

    // Séries e rankings
    final mensal = empilharPorMes(lista, campoData: 'data_relato', qtdSeries: 4, serieDe: (r) => indiceTipoRelato(r['classificacao']));
    final porDia = <String, double>{};
    for (final r in lista) {
      final d = soDataIso(r['data_relato']);
      if (d.isNotEmpty) porDia[d] = (porDia[d] ?? 0) + 1;
    }
    String areaDe(Map<String, dynamic> r) {
      final a = (r['area_relatada'] ?? '').toString().trim();
      if (a.isNotEmpty && a != '-') return a;
      final d = (r['departamento'] ?? '').toString().trim();
      return d.isEmpty ? 'NÃO INFORMADO' : d;
    }

    final listaDesvios = lista.where((r) {
      final i = indiceTipoRelato(r['classificacao']);
      return i == 0 || i == 1;
    }).toList();
    final desviosPorArea = <String, int>{};
    for (final r in listaDesvios) {
      final a = areaDe(r);
      desviosPorArea[a] = (desviosPorArea[a] ?? 0) + 1;
    }
    Map<String, int> detalhesDe(int tipo) {
      final m = <String, int>{};
      for (final r in lista.where((r) => indiceTipoRelato(r['classificacao']) == tipo)) {
        final d = (r['detalhe_classificacao'] ?? '').toString().trim();
        if (d.isEmpty || d == '-') continue;
        m[d] = (m[d] ?? 0) + 1;
      }
      return m;
    }

    final relatores = contar(lista, 'relator')..remove('NÃO INFORMADO');
    final topArea = topContagem(desviosPorArea, n: 1);
    final topRelator = topContagem(relatores, n: 1);

    String pct(int v) => total == 0 ? '0%' : '${(v * 100 / total).toStringAsFixed(0)}% do total';

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppEspaco.l, AppEspaco.l, AppEspaco.l, 96),
      children: [
        PainelIndice(
          titulo: 'Índice de reconhecimento',
          percentual: indice,
          status: status,
          corStatus: corStatus,
          descricao: 'Abordagens positivas sobre o total de relatos do período.',
          numeros: [
            ('$total', 'relatos'),
            ('$desvios', 'desvios'),
            ('$positivos', 'positivas'),
            ('$incidentes', 'incidentes'),
          ],
          rotuloAcao: 'Ver análise e recomendação',
          onAcao: () => _mostrarAnaliseIndice(context, indice, positivos, desvios),
        ),
        const TituloDash('Por classificação'),
        GradeKpis([
          KpiCard(
              titulo: 'Atos inseguros',
              valor: '$atos',
              cor: AppCores.perigo,
              icone: Icons.back_hand_outlined,
              subtitulo: pct(atos),
              fracao: total == 0 ? 0 : atos / total),
          KpiCard(
              titulo: 'Condições inseguras',
              valor: '$condicoes',
              cor: AppCores.alerta,
              icone: Icons.warning_amber_rounded,
              subtitulo: pct(condicoes),
              fracao: total == 0 ? 0 : condicoes / total),
          KpiCard(
              titulo: 'Abordagens positivas',
              valor: '$positivos',
              cor: AppCores.sucesso,
              icone: Icons.thumb_up_alt_outlined,
              subtitulo: pct(positivos),
              fracao: total == 0 ? 0 : positivos / total),
          KpiCard(
              titulo: 'Incidentes',
              valor: '$incidentes',
              cor: AppCores.info,
              icone: Icons.report_outlined,
              subtitulo: pct(incidentes),
              fracao: total == 0 ? 0 : incidentes / total),
        ]),
        if (topArea.isNotEmpty)
          CartaoInsight(
            icone: Icons.place_outlined,
            titulo: 'ÁREA COM MAIS DESVIOS',
            texto: '${topArea.first.rotulo} — ${topArea.first.valor.toInt()} desvio(s) '
                '(${desvios == 0 ? 0 : (topArea.first.valor * 100 / desvios).round()}% dos atos e condições).',
            cor: AppCores.perigo,
          ),
        if (topRelator.isNotEmpty)
          CartaoInsight(
            icone: Icons.emoji_events_outlined,
            titulo: 'MAIOR RELATOR',
            texto: '${topRelator.first.rotulo} — ${topRelator.first.valor.toInt()} relato(s).',
            cor: AppCores.sucesso,
          ),
        const TituloDash('Evolução'),
        CartaoGrafico(
          titulo: 'Relatos por mês',
          subtitulo: 'Últimos 6 meses, por classificação',
          icone: Icons.stacked_bar_chart,
          child: GraficoBarrasEmpilhadas(
            rotulos: mensal.rotulos,
            valores: mensal.valores,
            series: List.generate(4, (i) => SerieEmpilhada(_kSeriesRelato.elementAt(i), _kCoresRelato.elementAt(i))),
          ),
        ),
        CartaoGrafico(
          titulo: 'Atividade',
          subtitulo: 'Quantidade de relatos registrados',
          icone: Icons.show_chart,
          child: GraficoLinhaTempo(porData: porDia, cor: AppCores.primaria),
        ),
        const TituloDash('Onde e o quê'),
        CartaoGrafico(
          titulo: 'Desvios por área',
          subtitulo: 'Atos + condições inseguras',
          icone: Icons.place_outlined,
          child: BarrasHorizontais(itens: topContagem(desviosPorArea, n: 8), cor: AppCores.perigo),
        ),
        CartaoGrafico(
          titulo: 'Principais atos inseguros',
          icone: Icons.back_hand_outlined,
          child: BarrasHorizontais(itens: topContagem(detalhesDe(0), n: 5), cor: AppCores.perigo),
        ),
        CartaoGrafico(
          titulo: 'Principais condições inseguras',
          icone: Icons.warning_amber_rounded,
          child: BarrasHorizontais(itens: topContagem(detalhesDe(1), n: 5), cor: AppCores.alerta),
        ),
        CartaoGrafico(
          titulo: 'Relatos por UNB',
          icone: Icons.business_outlined,
          child: GraficoPizza(contagem: contar(lista, 'unb'), rotuloCentro: 'relatos'),
        ),
        const TituloDash('Pessoas'),
        CartaoGrafico(
          titulo: 'Top relatores',
          subtitulo: 'Quem mais contribui com relatos',
          icone: Icons.emoji_events_outlined,
          child: BarrasHorizontais(itens: topContagem(relatores, n: 5), cor: AppCores.sucesso),
        ),
      ],
    );
  }

  void _mostrarAnaliseIndice(BuildContext context, double taxa, int positivos, int negativos) {
    final critico = taxa < 50;
    mostrarAnalise(
      context,
      titulo: critico ? 'Alerta de segurança' : 'Conformidade operacional saudável',
      cor: critico ? AppCores.perigo : AppCores.sucesso,
      icone: critico ? Icons.warning_amber_rounded : Icons.verified_outlined,
      numeros: [
        ('Reconhecimentos', '$positivos', AppCores.sucesso),
        ('Desvios (ato/condição)', '$negativos', AppCores.perigo),
      ],
      tituloTexto: 'Recomendação',
      itens: critico
          ? [
              'O volume de desvios supera as abordagens de reconhecimento.',
              'Realize um DDS focado nas áreas com mais atos inseguros (veja "Desvios por área").',
              'Reforce a abordagem positiva com as lideranças para equilibrar o índice.',
            ]
          : [
              'A operação demonstra maturidade: mantenha o reforço positivo.',
              'Foque na eliminação das condições inseguras residuais no ambiente.',
              'Reconheça publicamente os maiores relatores do período.',
            ],
      rotuloFechar: 'Fechar análise',
    );
  }
}
