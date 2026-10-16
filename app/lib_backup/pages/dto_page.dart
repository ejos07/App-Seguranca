import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api.dart';
import 'dto_form_page.dart';

class DtoPage extends StatefulWidget {
  const DtoPage({super.key});

  @override
  State<DtoPage> createState() => _DtoPageState();
}

class _DtoPageState extends State<DtoPage> {
  // Estado Centralizado
  List<dynamic> _dtosGerais = [];
  List<dynamic> _dtosFiltrados = [];
  
  bool _isLoading = true;
  String _erro = '';
  String _termoBusca = '';
  DateTimeRange? _periodoSelecionado;

  String _perfil = 'colaborador';
  String _nomeUsuario = 'Desconhecido';

  @override
  void initState() {
    super.initState();
    _inicializarTela();
  }

  Future<void> _inicializarTela() async {
    await _carregarUsuarioLocal();
    await _carregarDTOs();
  }

  Future<void> _carregarUsuarioLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final usuarioStr = prefs.getString('usuario');

    if (usuarioStr != null && mounted) {
      final user = jsonDecode(usuarioStr);
      setState(() {
        _nomeUsuario = user['nome'] ?? 'Desconhecido';
        _perfil = user['perfil'] ?? 'colaborador';
      });
    }
  }

  Future<void> _carregarDTOs() async {
    setState(() {
      _isLoading = true;
      _erro = '';
    });

    try {
      final response = await Api.get('/api/dto');
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        
        setState(() {
          if (data is Map && data.containsKey('dados')) {
            _dtosGerais = data['dados'] ?? [];
          } else if (data is List) {
            _dtosGerais = data;
          }
          _aplicarFiltros();
          _isLoading = false;
        });
      } else {
        setState(() {
          _erro = 'Erro do servidor: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _erro = 'Falha de conexão com o servidor local.';
        _isLoading = false;
      });
    }
  }

  void _aplicarFiltros() {
    setState(() {
      _dtosFiltrados = _dtosGerais.where((dto) {
        bool matchData = true;
        bool matchPerfil = false;
        bool matchBusca = true;

        // 1. Filtro de Data
        if (_periodoSelecionado != null) {
          final dataCrua = dto['data_relato']?.toString() ?? '';
          if (dataCrua.isNotEmpty) {
            final apenasData = dataCrua.split(' ')[0];
            DateTime? dataObj = _converterDataFlexivel(apenasData);
            if (dataObj != null) {
              final inicio = DateTime(_periodoSelecionado!.start.year, _periodoSelecionado!.start.month, _periodoSelecionado!.start.day);
              final fim = DateTime(_periodoSelecionado!.end.year, _periodoSelecionado!.end.month, _periodoSelecionado!.end.day);
              final dataComparacao = DateTime(dataObj.year, dataObj.month, dataObj.day);

              matchData = (dataComparacao.isAtSameMomentAs(inicio) || dataComparacao.isAfter(inicio)) &&
                          (dataComparacao.isAtSameMomentAs(fim) || dataComparacao.isBefore(fim));
            } else {
              matchData = false;
            }
          } else {
            matchData = false;
          }
        }

        // 2. Filtro RBAC
        if (_perfil == 'admin' || _perfil == 'tecnico') {
          matchPerfil = true;
        } else {
          final relator = dto['relator']?.toString() ?? '';
          final relatado = dto['relatado']?.toString() ?? '';
          matchPerfil = (relator == _nomeUsuario || relatado == _nomeUsuario);
        }

        // 3. Filtro de Texto
        if (_termoBusca.isNotEmpty) {
          final termo = _termoBusca.toLowerCase();
          final relator = (dto['relator']?.toString() ?? '').toLowerCase();
          final relatado = (dto['relatado']?.toString() ?? '').toLowerCase();
          matchBusca = relator.contains(termo) || relatado.contains(termo);
        }

        return matchData && matchPerfil && matchBusca;
      }).toList();
    });
  }

  DateTime? _converterDataFlexivel(String dataString) {
    DateTime? data = DateTime.tryParse(dataString);
    if (data != null) return data;
    if (dataString.contains('/') || dataString.contains('-')) {
      final separador = dataString.contains('/') ? '/' : '-';
      final partes = dataString.split(separador);
      if (partes.length == 3) {
        final dia = int.tryParse(partes[0]);
        final mes = int.tryParse(partes[1]);
        final ano = int.tryParse(partes[2]);
        if (dia != null && mes != null && ano != null) {
          final anoFormatado = ano < 100 ? 2000 + ano : ano;
          return DateTime(anoFormatado, mes, dia);
        }
      }
    }
    return null; 
  }

  void _selecionarPeriodo(BuildContext context) {
    final maskInicio = MaskTextInputFormatter(mask: '##/##/####', filter: { "#": RegExp(r'[0-9]') });
    final maskFim = MaskTextInputFormatter(mask: '##/##/####', filter: { "#": RegExp(r'[0-9]') });
    final ctrlInicio = TextEditingController();
    final ctrlFim = TextEditingController();

    if (_periodoSelecionado != null) {
      ctrlInicio.text = '${_periodoSelecionado!.start.day.toString().padLeft(2, '0')}/${_periodoSelecionado!.start.month.toString().padLeft(2, '0')}/${_periodoSelecionado!.start.year}';
      ctrlFim.text = '${_periodoSelecionado!.end.day.toString().padLeft(2, '0')}/${_periodoSelecionado!.end.month.toString().padLeft(2, '0')}/${_periodoSelecionado!.end.year}';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (BuildContext ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 16, left: 16, right: 16, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filtrar Período', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: TextField(controller: ctrlInicio, inputFormatters: [maskInicio], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Data Inicial', hintText: 'DD/MM/AAAA', border: OutlineInputBorder()))),
                  const SizedBox(width: 16),
                  Expanded(child: TextField(controller: ctrlFim, inputFormatters: [maskFim], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Data Final', hintText: 'DD/MM/AAAA', border: OutlineInputBorder()))),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    final inicio = _converterDataFlexivel(ctrlInicio.text);
                    final fim = _converterDataFlexivel(ctrlFim.text);
                    if (inicio != null && fim != null) {
                      setState(() => _periodoSelecionado = DateTimeRange(start: inicio, end: fim));
                      _aplicarFiltros();
                      Navigator.pop(ctx);
                    } else {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Formato de data inválido.'), backgroundColor: Colors.red));
                    }
                  },
                  child: const Text('Aplicar Filtro', style: TextStyle(fontSize: 16)),
                ),
              )
            ],
          ),
        );
      }
    );
  }

  Future<void> _handleRefresh() async {
    await _carregarDTOs();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Módulo DTO'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3.0,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.list_alt), text: 'Consultar'),
              Tab(icon: Icon(Icons.pie_chart), text: 'Dashboard'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAbaLista(),
            _DtoDashboardView(dtos: _dtosFiltrados),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const DtoFormPage())).then((_) => _carregarDTOs());
          },
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Novo DTO', style: TextStyle(color: Colors.white)),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  // ==========================================
  // CONSTRUÇÃO DA ABA DE LISTA
  // ==========================================
  Widget _buildAbaLista() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12.0),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar por nome...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (valor) {
                    _termoBusca = valor;
                    _aplicarFiltros();
                  },
                ),
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: const Icon(Icons.filter_list, size: 16),
                label: const Text('Data'),
                backgroundColor: _periodoSelecionado != null ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.grey[100],
                onPressed: () => _selecionarPeriodo(context),
              ),
              if (_periodoSelecionado != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: Colors.red),
                  onPressed: () {
                    setState(() => _periodoSelecionado = null);
                    _aplicarFiltros();
                  },
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            child: _buildConteudoLista(),
          ),
        ),
      ],
    );
  }

  Widget _buildConteudoLista() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_erro.isNotEmpty) return Center(child: Text(_erro, style: const TextStyle(color: Colors.red)));
    if (_dtosFiltrados.isEmpty) return const Center(child: Text('Nenhuma DTO encontrada.', style: TextStyle(color: Colors.grey)));

    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: _dtosFiltrados.length,
      itemBuilder: (context, index) {
        return _buildDtoCard(_dtosFiltrados[index]);
      },
    );
  }

  Widget _buildDtoCard(Map<String, dynamic> dto) {
    final dataCrua = dto['data_relato']?.toString() ?? '';
    final dataFormatada = dataCrua.contains(' ') ? dataCrua.split(' ')[0] : dataCrua;
    final comportamento = dto['tipo_comportamento']?.toString() ?? '';
    
    final bool isSeguro = comportamento.contains('Seguro') && !comportamento.contains('Inseguro');
    final Color corStatus = isSeguro ? Colors.green : Colors.red;
    final IconData iconeStatus = isSeguro ? Icons.check_circle : Icons.warning;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(backgroundColor: corStatus.withOpacity(0.1), child: Icon(iconeStatus, color: corStatus)),
        title: Text('Protocolo: ${dto['protocolo'] ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${dataFormatada.split('-').reversed.join('/')} • Avaliado: ${dto['relatado'] ?? ''}'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detalheLinha('Observador', dto['relator']),
                _detalheLinha('Comportamento', comportamento),
                const Divider(),
                const Text('Ação Tomada:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(dto['acao_tomada']?.toString().isNotEmpty == true ? dto['acao_tomada'] : 'Sem ação.', style: TextStyle(color: Colors.grey[700])),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _detalheLinha(String label, dynamic valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: RichText(text: TextSpan(style: const TextStyle(color: Colors.black87, fontSize: 14), children: [
        TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        TextSpan(text: valor?.toString() ?? 'N/A'),
      ])),
    );
  }
}

// ==========================================
// ABA 2: DASHBOARD DTO (Com Análises Profundas e Rankings)
// ==========================================
class _DtoDashboardView extends StatelessWidget {
  final List<dynamic> dtos;

  const _DtoDashboardView({required this.dtos});

  @override
  Widget build(BuildContext context) {
    if (dtos.isEmpty) {
      return const Center(child: Text('Sem dados para gerar o dashboard.', style: TextStyle(color: Colors.grey)));
    }

    final int total = dtos.length;
    final int totalSeguros = dtos.where((d) {
      final comp = d['tipo_comportamento']?.toString() ?? '';
      return comp.contains('Seguro') && !comp.contains('Inseguro');
    }).length;
    
    final int totalInseguros = total - totalSeguros;
    final double taxaSeguranca = total > 0 ? (totalSeguros / total) * 100 : 0;

    // Processamento de Dados: Filtrar apenas os desvios
    final List<dynamic> apenasDesvios = dtos.where((d) {
      final comp = d['tipo_comportamento']?.toString() ?? '';
      return !comp.contains('Seguro') || comp.contains('Inseguro');
    }).toList();

    // Motores de Rank (Top 3)
    final List<MapEntry<String, int>> rankPessoas = _calcularTop(apenasDesvios, 'relatado', 3);
    final List<MapEntry<String, int>> rankTiposDto = _calcularTop(apenasDesvios, 'tipo_dto', 3);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. CARTÃO DE DESTAQUE: Índice de Comportamento
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF34D399), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: const Color(0xFF059669).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Comportamento Seguro', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
                        taxaSeguranca >= 80 ? 'Cultura Preventiva Forte' : 'Necessita Treinamento',
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _mostrarAnaliseDTO(context, taxaSeguranca, totalSeguros, totalInseguros),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(20)),
                            child: const Text('Plano de Ação Estratégico', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 0,
                          centerSpaceRadius: 30,
                          sections: [
                            PieChartSectionData(color: Colors.white, value: taxaSeguranca, title: '', radius: 10),
                            PieChartSectionData(color: Colors.white.withOpacity(0.3), value: 100 - taxaSeguranca, title: '', radius: 10),
                          ],
                        ),
                      ),
                      Text('${taxaSeguranca.toInt()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                )
              ],
            ),
          ),

          const SizedBox(height: 32),
          const Text('Evolução das Abordagens', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 16),

          // 2. GRÁFICO DE LINHAS (Evolução Temporal)
          Container(
            height: 200,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total de DTOs', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(total.toString(), style: const TextStyle(color: Color(0xFF059669), fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(child: _buildGraficoEvolucaoDTO(dtos)),
              ],
            ),
          ),

          const SizedBox(height: 32),
          const Text('Análise de Risco (Desvios)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 16),

          // 3. RANKING: Colaboradores com mais desvios
          _buildRankingList(
            titulo: 'Top Colaboradores em Desvio',
            dadosRank: rankPessoas,
            totalReferencia: totalInseguros,
            corDestaque: const Color(0xFFF43F5E), // Vermelho Rosado
            icone: Icons.person_outline,
            vazioMsg: 'Nenhum desvio registado neste período.',
          ),

          const SizedBox(height: 16),

          // 4. RANKING: Tipos de DTO com mais desvios
          _buildRankingList(
            titulo: 'Processos Mais Críticos (Tipos de DTO)',
            dadosRank: rankTiposDto,
            totalReferencia: totalInseguros,
            corDestaque: const Color(0xFFF59E0B), // Laranja
            icone: Icons.assignment_late_outlined,
            vazioMsg: 'Nenhum desvio registado neste período.',
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ==========================================
  // MOTORES DE PROCESSAMENTO DE DADOS
  // ==========================================
  
  // Calcula o ranking ordenado de qualquer chave do JSON
  List<MapEntry<String, int>> _calcularTop(List<dynamic> dados, String chave, int limite) {
    Map<String, int> contagem = {};
    for (var item in dados) {
      String valor = item[chave]?.toString() ?? 'Não Informado';
      if (valor.trim().isEmpty) valor = 'Não Informado';
      contagem[valor] = (contagem[valor] ?? 0) + 1;
    }
    
    // Converte o mapa numa lista e ordena do maior para o menor
    var listaOrdenada = contagem.entries.toList();
    listaOrdenada.sort((a, b) => b.value.compareTo(a.value));
    
    // Retorna apenas a quantidade estipulada no limite
    if (listaOrdenada.length > limite) {
      return listaOrdenada.sublist(0, limite);
    }
    return listaOrdenada;
  }

  // ==========================================
  // COMPONENTES VISUAIS (UI/UX MOBILE)
  // ==========================================

  // Constrói um painel de ranking com barras de progresso horizontais
  Widget _buildRankingList({
    required String titulo, 
    required List<MapEntry<String, int>> dadosRank, 
    required int totalReferencia,
    required Color corDestaque,
    required IconData icone,
    required String vazioMsg,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, color: Colors.grey.shade400, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(titulo, style: const TextStyle(color: Color(0xFF1E293B), fontSize: 14, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 20),
          if (dadosRank.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(vazioMsg, style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
            )
          else
            ...dadosRank.asMap().entries.map((entry) {
              int index = entry.key;
              MapEntry<String, int> dado = entry.value;
              double percentual = totalReferencia > 0 ? (dado.value / totalReferencia) : 0;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${index + 1}. ${dado.key}', 
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${dado.value} ocorr.', 
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: corDestaque),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Barra de progresso customizada (Glanceability)
                    Stack(
                      children: [
                        Container(
                          height: 6,
                          width: double.infinity,
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(3)),
                        ),
                        FractionallySizedBox(
                          widthFactor: percentual,
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(color: corDestaque, borderRadius: BorderRadius.circular(3)),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildGraficoEvolucaoDTO(List<dynamic> dtosData) {
    Map<String, int> contagemPorData = {};
    for (var d in dtosData) {
      String dataCrua = d['data_relato']?.toString() ?? '';
      String dataCurta = dataCrua.contains(' ') ? dataCrua.split(' ')[0] : dataCrua;
      contagemPorData[dataCurta] = (contagemPorData[dataCurta] ?? 0) + 1;
    }

    List<String> datasOrdenadas = contagemPorData.keys.toList()..sort();
    if (datasOrdenadas.length > 6) datasOrdenadas = datasOrdenadas.sublist(datasOrdenadas.length - 6);

    List<FlSpot> spots = [];
    for (int i = 0; i < datasOrdenadas.length; i++) {
      spots.add(FlSpot(i.toDouble(), contagemPorData[datasOrdenadas[i]]!.toDouble()));
    }

    if (spots.isEmpty) spots = [const FlSpot(0, 0)];
    if (spots.length == 1) spots.add(FlSpot(1, spots.first.y)); 

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false), 
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24, 
              interval: 1, 
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (index >= 0 && index < datasOrdenadas.length) {
                  String d = datasOrdenadas[index];
                  String label = d;
                  if (d.contains('-')) { 
                    var p = d.split('-');
                    if (p.length == 3) label = '${p[2]}/${p[1]}';
                  } else if (d.contains('/')) { 
                    var p = d.split('/');
                    if (p.length >= 2) label = '${p[0]}/${p[1]}';
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF059669),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true), 
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [const Color(0xFF059669).withOpacity(0.3), Colors.transparent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // BOTTOM SHEET: PLANO DE AÇÃO
  // ==========================================
  void _mostrarAnaliseDTO(BuildContext context, double taxa, int seguros, int inseguros) {
    final bool isCritico = taxa < 70; 
    final Color corStatus = isCritico ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    
    final String diagnostico = isCritico 
        ? 'Risco Comportamental Elevado' 
        : 'Cultura de Segurança Madura';
    
    final List<String> planoDeAcao = isCritico
        ? [
            '1. Agendar feedback corretivo imediato com os $inseguros colaboradores identificados em desvio.',
            '2. Analisar o quadro de "Processos Mais Críticos" para direcionar o próximo Diálogo Diário de Segurança (DDS).',
            '3. Aumentar a cota de DTOs dos técnicos nas áreas onde atuam os colaboradores do Top 3 de desvios.',
          ]
        : [
            '1. Reconhecer publicamente os colaboradores avaliados como "Seguros" neste período.',
            '2. Mapear os líderes das observações para atuarem como multiplicadores na operação.',
            '3. Manter a rotina atual de inspeções sem alterações estruturais no quadro de horas.',
          ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (BuildContext ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom + 24, top: 24, left: 24, right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
              ),
              
              Row(
                children: [
                  Icon(isCritico ? Icons.warning_amber_rounded : Icons.psychology_alt, color: corStatus, size: 28),
                  const SizedBox(width: 12),
                  Expanded(child: Text(diagnostico, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: corStatus))),
                ],
              ),
              const SizedBox(height: 24),
              
              Row(
                children: [
                  Expanded(child: _buildBlocoDadoAnalise('Atitudes Seguras', seguros.toString(), Colors.green)),
                  Container(width: 1, height: 40, color: Colors.grey.shade200),
                  Expanded(child: _buildBlocoDadoAnalise('Desvios Ativos', inseguros.toString(), Colors.red)),
                ],
              ),
              
              const SizedBox(height: 24),
              const Text('Plano de Ação Estratégico', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(height: 12),
              
              ...planoDeAcao.map((passo) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.arrow_right, color: corStatus),
                    const SizedBox(width: 8),
                    Expanded(child: Text(passo, style: TextStyle(color: Colors.grey.shade800, fontSize: 13, height: 1.4))),
                  ],
                ),
              )).toList(),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Entendido', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildBlocoDadoAnalise(String titulo, String valor, Color cor) {
    return Column(
      children: [
        Text(valor, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: cor)),
        const SizedBox(height: 4),
        Text(titulo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}