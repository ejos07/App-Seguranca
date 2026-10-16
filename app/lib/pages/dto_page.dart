import 'package:flutter/material.dart';
import '../widgets/comum.dart';
import 'dto_form_page.dart';

// =====================================================
// DTO: Consultar + Dashboard
// =====================================================

/// "Seguro (Reforço Positivo)" / "SEGURO" -> true | "INSEGURO (...)" -> false
bool ehComportamentoSeguro(dynamic v) {
  final s = semAcento((v ?? '').toString()).toUpperCase();
  return s.contains('SEGURO') && !s.contains('INSEGURO');
}

class DtoPage extends StatefulWidget {
  const DtoPage({super.key});

  @override
  State<DtoPage> createState() => _DtoPageState();
}

class _DtoPageState extends State<DtoPage> {
  Sessao _sessao = Sessao.vazia;
  List<Map<String, dynamic>> _dtosGerais = [];
  bool _isLoading = true;
  String _erro = '';

  // Filtros
  String _busca = '';
  DateTimeRange? _periodo;
  String _comportamento = ''; // '' | 'Seguro' | 'Inseguro'
  String _tipoDto = '';

  @override
  void initState() {
    super.initState();
    _inicializarTela();
  }

  Future<void> _inicializarTela() async {
    final s = await Sessao.carregar();
    if (!mounted) return;
    setState(() => _sessao = s);
    await _carregarDTOs();
  }

  Future<void> _carregarDTOs() async {
    setState(() {
      _isLoading = true;
      _erro = '';
    });
    try {
      final r = await apiGet('/api/dto');
      if (!mounted) return;
      if (respostaOk(r)) {
        setState(() => _dtosGerais = listaDados(decodificar(r)));
      } else {
        setState(() => _erro = mensagemErro(r, prefixo: 'Erro do servidor'));
      }
    } catch (e) {
      if (mounted) setState(() => _erro = 'Falha de conexão com o servidor.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Igual ao DTO.tsx: admin, técnico e segurança veem tudo
  bool get _veTudo => _sessao.ehAdminOuSeguranca;

  List<String> get _tiposDisponiveis {
    final s = _dtosGerais.map((d) => (d['tipo_dto'] ?? '').toString()).where((t) => t.isNotEmpty).toSet().toList();
    s.sort();
    return s;
  }

  List<Map<String, dynamic>> get _dtosFiltrados {
    final eu = chaveNome(_sessao.nome);
    final lista = _dtosGerais.where((d) {
      final matchPerfil = _veTudo || chaveNome(d['relator']) == eu || chaveNome(d['relatado']) == eu;
      final matchData = dentroDoPeriodo(d['data_relato'], _periodo);
      final matchBusca = _busca.trim().isEmpty ||
          contemTexto(d['relator'], _busca) ||
          contemTexto(d['relatado'], _busca) ||
          contemTexto(d['protocolo'], _busca);
      final seguro = ehComportamentoSeguro(d['tipo_comportamento']);
      final matchComp = _comportamento.isEmpty || (_comportamento == 'Seguro' ? seguro : !seguro);
      final matchTipo = _tipoDto.isEmpty || d['tipo_dto'] == _tipoDto;
      return matchPerfil && matchData && matchBusca && matchComp && matchTipo;
    }).toList();
    lista.sort((a, b) => soDataIso(b['data_relato']).compareTo(soDataIso(a['data_relato'])));
    return lista;
  }

  // Formulário embutido na aba "Nova DTO": nova chave = formulário limpo
  Key _chaveForm = UniqueKey();
  BuildContext? _ctxAbas;

  void _aposSalvar() {
    setState(() => _chaveForm = UniqueKey());
    _carregarDTOs();
    final c = _ctxAbas;
    if (c != null && c.mounted) DefaultTabController.of(c).animateTo(1); // vai para a Consulta
  }

  Widget _filtros() {
    return BarraFiltros(
      hint: 'Buscar observador, avaliado ou protocolo...',
      onBusca: (v) => setState(() => _busca = v),
      filtros: [
        FiltroPeriodo(periodo: _periodo, onChanged: (p) => setState(() => _periodo = p)),
        FiltroMenu(
          rotulo: 'Comportamento',
          valor: _comportamento,
          opcoes: const ['Seguro', 'Inseguro'],
          onChanged: (v) => setState(() => _comportamento = v),
        ),
        FiltroMenu(
          rotulo: 'Tipo',
          valor: _tipoDto,
          opcoes: _tiposDisponiveis,
          onChanged: (v) => setState(() => _tipoDto = v),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _dtosFiltrados;
    final podeCriar = _sessao.podeCriarDTO;

    // Mesmo padrão de GSD / GSA / GSP: Nova | Consulta | Dashboard
    // (a aba "Nova DTO" só aparece para quem pode criar)
    final abas = <Tab>[
      if (podeCriar) const Tab(icon: Icon(Icons.add_circle_outline), text: 'Nova DTO'),
      Tab(icon: const Icon(Icons.search), text: _veTudo ? 'Consulta' : 'Minhas DTOs'),
      const Tab(icon: Icon(Icons.pie_chart_outline), text: 'Dashboard'),
    ];

    return DefaultTabController(
      key: ValueKey('abas-dto-${abas.length}'),
      length: abas.length,
      child: Builder(builder: (ctxAbas) {
        _ctxAbas = ctxAbas;
        return Scaffold(
          appBar: AppBar(
            title: const Text('DTO'),
            actions: [
              IconButton(
                tooltip: 'Atualizar',
                icon: const Icon(Icons.refresh),
                onPressed: _isLoading ? null : _carregarDTOs,
              ),
            ],
            bottom: TabBar(tabs: abas),
          ),
          body: TabBarView(children: [
            if (podeCriar) DtoFormPage(key: _chaveForm, embutido: true, onSalvo: _aposSalvar),
            Column(children: [
              _filtros(),
              Expanded(child: _buildAbaLista(filtrados)),
            ]),
            Column(children: [
              _filtros(),
              Expanded(
                child: _isLoading && _dtosGerais.isEmpty
                    ? const ListaCarregando(itens: 3)
                    : _DtoDashboardView(dtos: filtrados),
              ),
            ]),
          ]),
        );
      }),
    );
  }

  Widget _buildAbaLista(List<Map<String, dynamic>> lista) {
    Widget corpo;
    if (_isLoading && _dtosGerais.isEmpty) {
      corpo = const ListaCarregando();
    } else if (_erro.isNotEmpty) {
      corpo = EstadoVazio(_erro, icone: Icons.cloud_off_rounded, onAcao: _carregarDTOs);
    } else if (lista.isEmpty) {
      corpo = EstadoVazio(
        'Nenhuma DTO encontrada',
        icone: Icons.fact_check_outlined,
        subtitulo: _veTudo ? 'Ajuste os filtros acima.' : 'Aqui aparecem as DTOs aplicadas por você ou em você.',
      );
    } else {
      corpo = ListView.builder(
        padding: const EdgeInsets.fromLTRB(AppEspaco.m, AppEspaco.s, AppEspaco.m, 96),
        itemCount: lista.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(AppEspaco.xs, AppEspaco.xs, 0, AppEspaco.s),
              child: Text('${lista.length} ${lista.length == 1 ? 'DTO' : 'DTOS'}', style: AppTexto.rotulo),
            );
          }
          return _buildDtoCard(lista.elementAt(i - 1));
        },
      );
    }
    return RefreshIndicator(onRefresh: _carregarDTOs, child: corpo);
  }

  Widget _buildDtoCard(Map<String, dynamic> d) {
    final seguro = ehComportamentoSeguro(d['tipo_comportamento']);
    final cor = seguro ? AppCores.sucesso : AppCores.perigo;
    final resp = respostasDe(d['respostas_dict']);
    final nok = resp.values.where((v) => v.toString().toUpperCase().contains('NOK')).length;
    final desc = (d['descricao'] ?? '').toString().trim();
    final acao = (d['acao_tomada'] ?? '').toString().trim();

    return CardRegistro(
      cor: cor,
      fotoNome: (d['relatado'] ?? '').toString(),
      titulo: (d['tipo_dto'] ?? 'DTO').toString(),
      subtitulo: '${dataBr(d['data_relato'])} • ${d['protocolo'] ?? '-'}\n${d['relatado'] ?? '-'}',
      etiqueta: Etiqueta(seguro ? 'Seguro' : 'Inseguro',
          cor: cor, icone: seguro ? Icons.verified_outlined : Icons.warning_amber_rounded),
      detalhes: [
        LinhaDetalhe('Observador', d['relator']),
        LinhaDetalhe('Avaliado', d['relatado']),
        LinhaDetalhe('UNB', d['unb']),
        LinhaDetalhe('Comportamento', d['tipo_comportamento']),
        if (resp.isNotEmpty) LinhaDetalhe('Checklist', nok == 0 ? 'Tudo OK' : '$nok item(ns) NOK'),
        if (desc.isNotEmpty) ...[const SizedBox(height: AppEspaco.s), CaixaObservacao(desc, titulo: 'Descrição')],
        if (acao.isNotEmpty) ...[const SizedBox(height: AppEspaco.s), CaixaObservacao(acao, titulo: 'Ação tomada')],
        if (resp.isNotEmpty) ...[
          const SizedBox(height: AppEspaco.m),
          Text('RESPOSTAS DO CHECKLIST', style: AppTexto.rotulo),
          const SizedBox(height: AppEspaco.s),
          ListaRespostas(respostas: resp, ehRuim: (v) => v.toUpperCase().contains('NOK')),
        ],
      ],
    );
  }
}

// ==========================================
// ABA 2: DASHBOARD DTO
// ==========================================
class _DtoDashboardView extends StatelessWidget {
  final List<dynamic> dtos;

  const _DtoDashboardView({required this.dtos});

  @override
  Widget build(BuildContext context) {
    final lista = dtos.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    if (lista.isEmpty) {
      return const EstadoVazio('Sem dados para o dashboard.',
          icone: Icons.insights_outlined, subtitulo: 'Ajuste os filtros ou o período para ver os indicadores.');
    }

    final total = lista.length;
    final seguros = lista.where((d) => ehComportamentoSeguro(d['tipo_comportamento'])).length;
    final inseguros = total - seguros;
    final taxa = total == 0 ? 0.0 : seguros * 100 / total;
    final pessoas = lista.map((d) => (d['relatado'] ?? '').toString()).where((s) => s.isNotEmpty).toSet().length;
    final observadores = lista.map((d) => (d['relator'] ?? '').toString()).where((s) => s.isNotEmpty).toSet().length;

    final (status, corStatus) = taxa >= 80
        ? ('Cultura preventiva forte', AppCores.sucesso)
        : (taxa >= 60 ? ('Atenção', AppCores.alerta) : ('Risco comportamental', AppCores.perigo));

    final desvios = lista.where((d) => !ehComportamentoSeguro(d['tipo_comportamento'])).toList();
    final pessoasDesvio = contar(desvios, 'relatado')..remove('NÃO INFORMADO');
    final tiposDesvio = contar(desvios, 'tipo_dto');
    final observ = contar(lista, 'relator')..remove('NÃO INFORMADO');

    final mensal = empilharPorMes(lista,
        campoData: 'data_relato', qtdSeries: 2, serieDe: (d) => ehComportamentoSeguro(d['tipo_comportamento']) ? 0 : 1);
    final porDia = <String, double>{};
    for (final d in lista) {
      final k = soDataIso(d['data_relato']);
      if (k.isNotEmpty) porDia[k] = (porDia[k] ?? 0) + 1;
    }

    // % de comportamento seguro por tipo de DTO (pior primeiro)
    final porTipo = <String, List<int>>{};
    for (final d in lista) {
      final t = (d['tipo_dto'] ?? '').toString().trim();
      if (t.isEmpty) continue;
      final par = porTipo.putIfAbsent(t, () => [0, 0]);
      if (ehComportamentoSeguro(d['tipo_comportamento'])) {
        par.first++;
      } else {
        par.last++;
      }
    }
    final pctTipos = porTipo.entries.map((e) {
      final t = e.value.first + e.value.last;
      final p = t == 0 ? 0.0 : e.value.first * 100 / t;
      final cor = p >= 80 ? AppCores.sucesso : (p >= 60 ? AppCores.alerta : AppCores.perigo);
      return ItemBarra(e.key, p, cor: cor, texto: '${p.toStringAsFixed(0)}%  ($t)');
    }).toList()
      ..sort((a, b) => a.valor.compareTo(b.valor));

    final topPessoa = topContagem(pessoasDesvio, n: 1);
    final topTipo = topContagem(tiposDesvio, n: 1);

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppEspaco.l, AppEspaco.l, AppEspaco.l, 96),
      children: [
        PainelIndice(
          titulo: 'Comportamento seguro',
          percentual: taxa,
          status: status,
          corStatus: corStatus,
          descricao: 'DTOs com comportamento seguro sobre o total do período.',
          numeros: [
            ('$total', 'DTOs'),
            ('$seguros', 'seguros'),
            ('$inseguros', 'desvios'),
            ('$pessoas', 'pessoas'),
          ],
          gradiente: const LinearGradient(
            colors: [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF10B981)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          rotuloAcao: 'Plano de ação',
          onAcao: () => _mostrarAnaliseDTO(context, taxa, seguros, inseguros),
        ),
        const TituloDash('Indicadores'),
        GradeKpis([
          KpiCard(
              titulo: 'Colaboradores avaliados',
              valor: '$pessoas',
              cor: AppCores.info,
              icone: Icons.groups_outlined,
              subtitulo: pessoas == 0 ? null : '${(total / pessoas).toStringAsFixed(1)} DTO por pessoa'),
          KpiCard(
              titulo: 'Observadores ativos',
              valor: '$observadores',
              cor: AppCores.roxo,
              icone: Icons.visibility_outlined,
              subtitulo: observadores == 0 ? null : '${(total / observadores).toStringAsFixed(1)} DTO por observador'),
          KpiCard(
              titulo: 'Comportamentos seguros',
              valor: '$seguros',
              cor: AppCores.sucesso,
              icone: Icons.verified_user_outlined,
              fracao: total == 0 ? 0 : seguros / total),
          KpiCard(
              titulo: 'Desvios',
              valor: '$inseguros',
              cor: AppCores.perigo,
              icone: Icons.gpp_maybe_outlined,
              fracao: total == 0 ? 0 : inseguros / total),
        ]),
        if (topTipo.isNotEmpty)
          CartaoInsight(
            icone: Icons.assignment_late_outlined,
            titulo: 'PROCESSO MAIS CRÍTICO',
            texto: '${topTipo.first.rotulo} concentra ${topTipo.first.valor.toInt()} desvio(s) '
                '(${inseguros == 0 ? 0 : (topTipo.first.valor * 100 / inseguros).round()}% do total de desvios).',
            cor: AppCores.alerta,
          ),
        if (topPessoa.isNotEmpty && topPessoa.first.valor > 1)
          CartaoInsight(
            icone: Icons.person_search_outlined,
            titulo: 'ATENÇÃO',
            texto: '${topPessoa.first.rotulo} teve ${topPessoa.first.valor.toInt()} desvios no período — '
                'priorize um feedback individual.',
            cor: AppCores.perigo,
          ),
        const TituloDash('Evolução'),
        CartaoGrafico(
          titulo: 'DTOs por mês',
          subtitulo: 'Seguro x desvio, últimos 6 meses',
          icone: Icons.stacked_bar_chart,
          child: GraficoBarrasEmpilhadas(
            rotulos: mensal.rotulos,
            valores: mensal.valores,
            series: const [
              SerieEmpilhada('Seguro', AppCores.sucesso),
              SerieEmpilhada('Desvio', AppCores.perigo),
            ],
          ),
        ),
        CartaoGrafico(
          titulo: 'Atividade',
          subtitulo: 'Quantidade de DTOs aplicadas',
          icone: Icons.show_chart,
          child: GraficoLinhaTempo(porData: porDia, cor: AppCores.sucesso),
        ),
        const TituloDash('Análise de risco'),
        CartaoGrafico(
          titulo: '% seguro por tipo de DTO',
          subtitulo: 'Piores primeiro (entre parênteses: qtd. aplicada)',
          icone: Icons.fact_check_outlined,
          child: BarrasHorizontais(itens: pctTipos.take(8).toList(), maximo: 100, ranking: false),
        ),
        CartaoGrafico(
          titulo: 'Colaboradores com mais desvios',
          icone: Icons.person_outline,
          child: BarrasHorizontais(
              itens: topContagem(pessoasDesvio, n: 5), cor: AppCores.perigo, sufixo: 'desvio(s)'),
        ),
        CartaoGrafico(
          titulo: 'Desvios por tipo de DTO',
          icone: Icons.assignment_late_outlined,
          child: GraficoPizza(contagem: tiposDesvio, rotuloCentro: 'desvios'),
        ),
        CartaoGrafico(
          titulo: 'Top observadores',
          subtitulo: 'Quem mais aplicou DTO',
          icone: Icons.emoji_events_outlined,
          child: BarrasHorizontais(itens: topContagem(observ, n: 5), cor: AppCores.roxo),
        ),
      ],
    );
  }

  void _mostrarAnaliseDTO(BuildContext context, double taxa, int seguros, int inseguros) {
    final critico = taxa < 70;
    mostrarAnalise(
      context,
      titulo: critico ? 'Risco comportamental elevado' : 'Cultura de segurança madura',
      cor: critico ? AppCores.perigo : AppCores.sucesso,
      icone: critico ? Icons.warning_amber_rounded : Icons.psychology_alt,
      numeros: [
        ('Atitudes seguras', '$seguros', AppCores.sucesso),
        ('Desvios', '$inseguros', AppCores.perigo),
      ],
      tituloTexto: 'Plano de ação',
      itens: critico
          ? [
              'Agendar feedback corretivo com os $inseguros desvio(s) identificados.',
              'Usar "% seguro por tipo de DTO" para direcionar o próximo DDS.',
              'Aumentar a quantidade de DTOs nas áreas dos colaboradores com mais desvios.',
            ]
          : [
              'Reconhecer publicamente os colaboradores avaliados como seguros.',
              'Usar os observadores mais ativos como multiplicadores na operação.',
              'Manter a rotina atual de observações.',
            ],
    );
  }
}
