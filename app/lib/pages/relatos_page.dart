import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api.dart';

class RelatosPage extends StatefulWidget {
  const RelatosPage({super.key});

  @override
  State<RelatosPage> createState() => _RelatosPageState();
}

class _RelatosPageState extends State<RelatosPage> {
  // Estado Centralizado para partilha entre Lista e Dashboard
  List<dynamic> _relatosGerais = []; 
  List<dynamic> _relatosFiltrados = []; 
  
  bool _isLoading = true;
  String _erro = '';
  
  String _perfil = 'colaborador';
  String _nomeUsuario = 'Desconhecido';
  
  DateTimeRange? _periodoSelecionado;
  String _tipoSelecionado = 'Todos';
  
  final List<String> _opcoesTipo = [
    'Todos',
    'Ato inseguro',
    'Condição insegura',
    'Abordagem positiva',
    'Incidente'
  ];

  @override
  void initState() {
    super.initState();
    _inicializarTela(); 
  }

  Future<void> _inicializarTela() async {
    await _carregarUsuarioLocal();
    await _carregarRelatos();
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

  Future<void> _carregarRelatos() async {
    setState(() => _isLoading = true);
    try {
      final response = await Api.get('/relatos/');
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        
        setState(() {
          if (data is Map && data.containsKey('dados')) {
            _relatosGerais = data['dados'] ?? [];
          } else if (data is List) {
            _relatosGerais = data;
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
      _relatosFiltrados = _relatosGerais.where((relato) {
        bool matchData = true;
        bool matchTipo = true;
        bool matchPerfil = false;

        // Filtro de Data
        if (_periodoSelecionado != null) {
          final dataCrua = relato['data_relato']?.toString() ?? '';
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

        // Filtro de Tipo
        if (_tipoSelecionado != 'Todos') {
          // Converte o valor da API para minúsculas
          final classif = relato['classificacao']?.toString().toLowerCase() ?? '';
          // Converte a seleção para minúsculas e compara
          matchTipo = classif.contains(_tipoSelecionado.toLowerCase());
        }

        // Regra de Controlo de Acessos (RBAC)
        if (_perfil == 'admin' || _perfil == 'tecnico') {
          matchPerfil = true;
        } else {
          final relator = relato['relator']?.toString() ?? '';
          final relatado = relato['relatado']?.toString() ?? '';
          matchPerfil = (relator == _nomeUsuario || relatado == _nomeUsuario);
        }

        return matchData && matchTipo && matchPerfil;
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
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16, 
            left: 16, right: 16, top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filtrar Período', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ctrlInicio,
                      inputFormatters: [maskInicio],
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Data Inicial', hintText: 'DD/MM/AAAA', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: ctrlFim,
                      inputFormatters: [maskFim],
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Data Final', hintText: 'DD/MM/AAAA', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Ou selecionar no calendário'),
                  onPressed: () async {
                    final DateTimeRange? periodoTatil = await showDateRangePicker(
                      context: context,
                      initialDateRange: _periodoSelecionado,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialEntryMode: DatePickerEntryMode.calendarOnly, 
                    );
                    if (periodoTatil != null) {
                      setState(() => _periodoSelecionado = periodoTatil);
                      _aplicarFiltros();
                      Navigator.pop(ctx); 
                    }
                  },
                ),
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
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Formato de data inválido.'), backgroundColor: Colors.red),
                      );
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
    await _carregarRelatos();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sistema de Relatos'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sair da conta',
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('usuario');
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
            ),
          ],
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
            _RelatosDashboardView(relatos: _relatosFiltrados),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.pushNamed(context, '/novo_relato').then((_) {
              _carregarRelatos();
            });
          },
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Novo Relato', style: TextStyle(color: Colors.white)),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildAbaLista() {
    return Column(
      children: [
        _buildBarraDeFiltros(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            child: _buildListaRelatos(),
          ),
        ),
      ],
    );
  }

  Widget _buildBarraDeFiltros() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ActionChip(
              avatar: const Icon(Icons.date_range, size: 16),
              label: Text(
                _periodoSelecionado == null 
                  ? 'Filtrar Período' 
                  : '${_periodoSelecionado!.start.day.toString().padLeft(2, '0')}/${_periodoSelecionado!.start.month.toString().padLeft(2, '0')} a ${_periodoSelecionado!.end.day.toString().padLeft(2, '0')}/${_periodoSelecionado!.end.month.toString().padLeft(2, '0')}'
              ),
              backgroundColor: _periodoSelecionado != null 
                  ? Theme.of(context).primaryColor.withOpacity(0.1) 
                  : Colors.grey[100],
              side: BorderSide(color: Colors.grey.shade300),
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
            const SizedBox(width: 12),
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _tipoSelecionado,
                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                  onChanged: (String? novoValor) {
                    if (novoValor != null) {
                      setState(() => _tipoSelecionado = novoValor);
                      _aplicarFiltros();
                    }
                  },
                  items: _opcoesTipo.map<DropdownMenuItem<String>>((String valor) {
                    return DropdownMenuItem<String>(value: valor, child: Text(valor));
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaRelatos() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_erro.isNotEmpty) return Center(child: Text(_erro, style: const TextStyle(color: Colors.red)));
    if (_relatosFiltrados.isEmpty) return const Center(child: Text('Nenhum relato encontrado para estes filtros.', style: TextStyle(color: Colors.grey)));

    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: _relatosFiltrados.length,
      itemBuilder: (context, index) {
        return _buildRelatoCard(_relatosFiltrados[index]);
      },
    );
  }

  Widget _buildRelatoCard(Map<String, dynamic> relato) {
    final dataCrua = relato['data_relato']?.toString() ?? '';
    final dataFormatada = dataCrua.contains(' ') ? dataCrua.split(' ')[0] : dataCrua;

    Color corClassificacao = Colors.grey;
    // Converte a classificação para minúsculas para garantir a correspondência
    final classif = relato['classificacao']?.toString().toLowerCase() ?? '';
    
    if (classif.contains('ato inseguro')) corClassificacao = Colors.red;
    if (classif.contains('condição insegura')) corClassificacao = Colors.orange;
    if (classif.contains('abordagem positiva')) corClassificacao = Colors.green;
    if (classif.contains('incidente')) corClassificacao = Colors.blue;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: corClassificacao.withOpacity(0.2),
          child: Icon(Icons.assignment_late, color: corClassificacao),
        ),
        title: Text('Protocolo: ${relato['protocolo'] ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${dataFormatada.split('-').reversed.join('/')} • ${relato['area_relatada'] ?? ''}'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detalheLinha('Relator', relato['relator']),
                _detalheLinha('Envolvido', relato['relatado']),
                _detalheLinha('Classificação', relato['classificacao']),
                const Divider(),
                const Text('Descrição:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(relato['descricao'] ?? 'Sem descrição.', style: TextStyle(color: Colors.grey[700])),
                const SizedBox(height: 12),
                _detalheLinha('Ação Imediata', relato['acao_imediata']),
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
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: valor?.toString() ?? 'N/A'),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// ABA 2: DASHBOARD DE RELATOS (Estilo Moderno e Analítico)
// ==========================================
class _RelatosDashboardView extends StatelessWidget {
  final List<dynamic> relatos;

  const _RelatosDashboardView({required this.relatos});

  @override
  Widget build(BuildContext context) {
    if (relatos.isEmpty) {
      return const Center(
        child: Text('Sem dados para gerar o dashboard.', style: TextStyle(color: Colors.grey)),
      );
    }

    final int total = relatos.length;
    
    // Convertendo tudo para minúsculas para garantir a contagem correta
    final int totalAtos = relatos.where((r) => 
      (r['classificacao'] ?? '').toString().toLowerCase().contains('ato inseguro')).length;
      
    final int totalCondicoes = relatos.where((r) => 
      (r['classificacao'] ?? '').toString().toLowerCase().contains('condição insegura')).length;
      
    final int totalPositivos = relatos.where((r) => 
      (r['classificacao'] ?? '').toString().toLowerCase().contains('abordagem positiva')).length;
      
    final int totalIncidentes = relatos.where((r) => 
      (r['classificacao'] ?? '').toString().toLowerCase().contains('incidente')).length;

    final double taxaConformidade = total > 0 ? (totalPositivos / total) * 100 : 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. CARTÃO DE DESTAQUE COM BOTTOM SHEET INTERATIVO
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8BA4F9), Color(0xFFC0A6F9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: const Color(0xFF8BA4F9).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Índice de Segurança', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
                        taxaConformidade >= 50 ? 'Bom desempenho geral' : 'Atenção necessária',
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _mostrarAnaliseIndice(context, taxaConformidade, totalPositivos, (totalAtos + totalCondicoes)),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('Ver Análise', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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
                            PieChartSectionData(color: Colors.white, value: taxaConformidade, title: '', radius: 10),
                            PieChartSectionData(color: Colors.white.withOpacity(0.3), value: 100 - taxaConformidade, title: '', radius: 10),
                          ],
                        ),
                      ),
                      Text('${taxaConformidade.toInt()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                )
              ],
            ),
          ),

          const SizedBox(height: 32),
          const Text('Atividade Recente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 16),

          // 2. GRÁFICO DE LINHAS FLUIDO COM EIXO X INTELIGENTE
          Container(
            height: 200,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total de Relatos', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(total.toString(), style: const TextStyle(color: Color(0xFF8BA4F9), fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: _buildGraficoLinha(relatos), // Chamada do método auxiliar
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 3. GRELHA DE INDICADORES MODERNOS
          Row(
            children: [
              Expanded(child: _buildModernKpiCard('Atos Inseguros', totalAtos.toString(), 'Condutas', const Color(0xFF8BA4F9))),
              const SizedBox(width: 16),
              Expanded(child: _buildModernKpiCard('Condições', totalCondicoes.toString(), 'Ambiente', const Color(0xFFC0A6F9))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildModernKpiCard('Abord. Positiva', totalPositivos.toString(), 'Boas Práticas', const Color(0xFF86E3CE))),
              const SizedBox(width: 16),
              Expanded(child: _buildModernKpiCard('Incidentes', totalIncidentes.toString(), 'Ocorrências', const Color(0xFFFCA5A5))),
            ],
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ==========================================
  // MÉTODOS AUXILIARES DE CONSTRUÇÃO (HELPER WIDGETS)
  // ==========================================

  Widget _buildModernKpiCard(String titulo, String valor, String subtitulo, Color corDestaque) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(color: Color(0xFF1E293B), fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(valor, style: TextStyle(color: corDestaque, fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: corDestaque.withOpacity(0.5), shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(subtitulo, style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGraficoLinha(List<dynamic> relatosData) {
    Map<String, int> contagemPorData = {};
    for (var relato in relatosData) {
      String dataCrua = relato['data_relato']?.toString() ?? '';
      String dataCurta = dataCrua.contains(' ') ? dataCrua.split(' ')[0] : dataCrua;
      contagemPorData[dataCurta] = (contagemPorData[dataCurta] ?? 0) + 1;
    }

    List<String> datasOrdenadas = contagemPorData.keys.toList()..sort();

    if (datasOrdenadas.length > 6) {
      datasOrdenadas = datasOrdenadas.sublist(datasOrdenadas.length - 6);
    }

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
                    child: Text(
                      label, 
                      style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)
                    ),
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
            color: const Color(0xFF8BA4F9),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true), 
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [const Color(0xFF8BA4F9).withOpacity(0.3), Colors.transparent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarAnaliseIndice(BuildContext context, double taxa, int positivos, int negativos) {
    final bool isCritico = taxa < 50;
    final Color corStatus = isCritico ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    final String diagnostico = isCritico 
        ? 'Alerta Crítico de Segurança' 
        : 'Conformidade Operacional Saudável';
    
    final String recomendacao = isCritico
        ? 'O volume de desvios supera as abordagens de reconhecimento. Recomenda-se paralisação para Diálogo Diário de Segurança (DDS) focado nas Áreas com mais atos inseguros.'
        : 'A operação demonstra maturidade. Mantenha o reforço positivo e foque na mitigação das condições inseguras residuais no ambiente.';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).padding.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              
              Row(
                children: [
                  Icon(isCritico ? Icons.warning_amber_rounded : Icons.check_circle_outline, color: corStatus, size: 28),
                  const SizedBox(width: 12),
                  Expanded(child: Text(diagnostico, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: corStatus))),
                ],
              ),
              const SizedBox(height: 24),
              
              Row(
                children: [
                  Expanded(child: _buildBlocoDadoAnalise('Reconhecimentos', positivos.toString(), Colors.green)),
                  Container(width: 1, height: 40, color: Colors.grey.shade200),
                  Expanded(child: _buildBlocoDadoAnalise('Desvios (Ato/Condição)', negativos.toString(), Colors.red)),
                ],
              ),
              
              const SizedBox(height: 24),
              const Text('Recomendação do Sistema', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: corStatus.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: corStatus.withOpacity(0.2)),
                ),
                child: Text(recomendacao, style: TextStyle(color: Colors.grey.shade800, fontSize: 13, height: 1.5)),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fechar Análise', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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