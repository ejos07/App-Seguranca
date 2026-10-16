import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api.dart';

// =====================================================
// Listas iguais às do Relatos.tsx (web)
// =====================================================
const List<String> kListaUnb = ["RIZATTI", "BEVALE", "MINASBEB"];
const List<String> kListaDepartamentos = ["ADMINISTRATIVO", "ARMAZÉM", "COMERCIAL", "DISTRIBUIÇÃO", "PUXADA", "SEGURANÇA"];
const List<String> kListaClassificacao = ["Ato inseguro", "Condição insegura", "Abordagem positiva (Reconhecimento)", "Incidente"];
const List<String> kListaArea = ["PUXADA", "ADMINISTRATIVO", "APOIO LOGÍSTICO", "VENDAS", "DISTRIBUIÇÃO URBANA"];
const List<String> kListaProcesso = ["PUXADA", "ADMINISTRATIVO", "ARMAZÉM", "VENDAS", "DISTRIBUIÇÃO"];
// Detalhe da classificação: opções vêm do histórico (por grupo) + "OUTRO" com texto livre
const String kDetalheOutro = "OUTRO (descrever)";
const List<String> kListaAcao = [
  "LIDERANÇA ACIONADA IMEDIATAMENTE",
  "ATIVIDADE INTERROMPIDA PARA AVALIAÇÃO",
  "ÁREA CONTROLADA APÓS O EVENTO",
  "OUTRO",
];
const String kNaoSeAplica = "NÃO SE APLICA (Ex: Condição Insegura)";

// Mesma regra do grupoClass() da web
String _semAcento(String s) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
  const para = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = de.indexOf(ch);
    b.write(i >= 0 ? para.substring(i, i + 1) : ch);
  }
  return b.toString().toLowerCase().trim();
}

String grupoClass(dynamic c) {
  final s = _semAcento((c ?? '').toString());
  if (s.contains('ato inseguro')) return 'ATO';
  if (s.contains('condic')) return 'CONDICAO';
  if (s.contains('positiva') || s.contains('comportamento seguro') || s.contains('reconhecimento')) return 'POSITIVA';
  if (s.contains('incidente')) return 'INCIDENTE';
  return 'OUTRO';
}

class RelatosFormPage extends StatefulWidget {
  const RelatosFormPage({super.key});

  @override
  State<RelatosFormPage> createState() => _RelatosFormPageState();
}

class _RelatosFormPageState extends State<RelatosFormPage> {
  // Identificação
  bool _identificar = true;
  String _nomeUsuario = 'A carregar...';

  // Campos (mesmos defaults da web)
  DateTime _dataRelato = DateTime.now();
  String _unb = kListaUnb.first;
  String _departamento = kListaDepartamentos.first;
  String? _relatado;
  String? _area;
  String? _acaoImediata;
  final Set<String> _processos = <String>{};
  String? _classificacao;
  String? _detalhe;
  final TextEditingController _detalheOutroController = TextEditingController();

  // Detalhes já usados no histórico, por grupo (ATO / CONDICAO / POSITIVA / INCIDENTE)
  Map<String, List<String>> _detalhesPorGrupo = {};
  final TextEditingController _descricaoController = TextEditingController();

  // Colaboradores
  List<String> _nomesColaboradores = [];
  bool _isLoadingColaboradores = true;
  Key _autocompleteKey = UniqueKey();

  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregarUsuarioLocal();
    _carregarColaboradores();
    _carregarDetalhes();
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _detalheOutroController.dispose();
    super.dispose();
  }

  Future<void> _carregarUsuarioLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final usuarioStr = prefs.getString('usuario');
    if (usuarioStr != null && mounted) {
      try {
        final usuarioJson = jsonDecode(usuarioStr);
        setState(() => _nomeUsuario = usuarioJson['nome'] ?? 'Usuário Desconhecido');
      } catch (e) {
        setState(() => _nomeUsuario = 'Usuário Desconhecido');
      }
    }
  }

  Future<void> _carregarColaboradores() async {
    try {
      final response = await Api.get('/api/usuarios');
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        Iterable lista = [];
        if (data is Map && data.containsKey('dados')) {
          lista = data['dados'] ?? [];
        } else if (data is List) {
          lista = data;
        }

        final nomes = lista
            .map((c) => (c['Nome'] ?? c['nome'])?.toString().trim() ?? '')
            .where((nome) => nome.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        nomes.insert(0, kNaoSeAplica);

        setState(() {
          _nomesColaboradores = nomes;
          _isLoadingColaboradores = false;
        });
      } else {
        setState(() => _isLoadingColaboradores = false);
      }
    } catch (e) {
      debugPrint('Erro ao carregar colaboradores: $e');
      if (mounted) setState(() => _isLoadingColaboradores = false);
    }
  }

  Future<void> _carregarDetalhes() async {
    try {
      final response = await Api.get('/api/relatos');
      if (!mounted || response.statusCode != 200) return;
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      Iterable lista = [];
      if (data is Map && data.containsKey('dados')) {
        lista = data['dados'] ?? [];
      } else if (data is List) {
        lista = data;
      }

      final mapa = <String, Set<String>>{};
      for (final r in lista) {
        if (r is! Map) continue;
        final det = (r['detalhe_classificacao'] ?? '').toString().trim();
        if (det.isEmpty || det == '-') continue;
        mapa.putIfAbsent(grupoClass(r['classificacao']), () => <String>{}).add(det);
      }

      setState(() {
        _detalhesPorGrupo = mapa.map((g, s) => MapEntry(g, s.toList()..sort()));
      });
    } catch (e) {
      debugPrint('Erro ao carregar detalhes: $e');
    }
  }

  List<String> get _opcoesDetalhe {
    if (_classificacao == null) return const [];
    final base = _detalhesPorGrupo[grupoClass(_classificacao)] ?? const <String>[];
    return [...base, kDetalheOutro];
  }

  // =====================================================
  // Helpers
  // =====================================================
  String _p2(int v) => v.toString().padLeft(2, '0');

  String _dataBr(DateTime d) => '${_p2(d.day)}/${_p2(d.month)}/${d.year}';

  // Mesmo formato da web: "AAAA-MM-DD HH:MM"
  String _dataPayload() {
    final agora = DateTime.now();
    return '${_dataRelato.year}-${_p2(_dataRelato.month)}-${_p2(_dataRelato.day)} '
        '${_p2(agora.hour)}:${_p2(agora.minute)}';
  }

  void _aviso(String msg, {Color cor = Colors.red}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: cor, duration: const Duration(seconds: 4)),
    );
  }

  String _resumirErro(int status, String corpo) {
    try {
      final json = jsonDecode(corpo);
      final detalhes = json is Map ? json['detail'] : null;
      if (detalhes is List) {
        final campos = detalhes.map((d) {
          final loc = d is Map ? d['loc'] : null;
          final campo = (loc is List && loc.isNotEmpty) ? loc.last.toString() : '?';
          final msg = d is Map ? (d['msg'] ?? '').toString() : '';
          return '$campo ($msg)';
        }).join(', ');
        return 'Erro ao salvar ($status): $campos';
      }
      if (detalhes != null) return 'Erro ao salvar ($status): $detalhes';
    } catch (_) {}
    return 'Erro ao salvar ($status)';
  }

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _dataRelato,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (escolhida != null) setState(() => _dataRelato = escolhida);
  }

  void _limparFormulario() {
    setState(() {
      _relatado = null;
      _processos.clear();
      _classificacao = null;
      _detalhe = null;
      _detalheOutroController.clear();
      _descricaoController.clear();
      _autocompleteKey = UniqueKey(); // limpa o campo de busca do colaborador
    });
  }

  // =====================================================
  // SALVAR (mesmas regras do handleSubmit da web)
  // =====================================================
  Future<void> _salvarRelato() async {
    FocusScope.of(context).unfocus();

    final faltando = <String>[];
    if (_relatado == null) faltando.add('Colaborador relatado');
    if (_area == null) faltando.add('Área relatada');
    if (_acaoImediata == null) faltando.add('Ação imediata');
    if (_processos.isEmpty) faltando.add('Processo (pelo menos um)');
    if (_classificacao == null) faltando.add('Classificação');
    if (_detalhe == null) faltando.add('Detalhe da classificação');
    if (_detalhe == kDetalheOutro && _detalheOutroController.text.trim().isEmpty) {
      faltando.add('Descrição do detalhe');
    }
    if (_descricaoController.text.trim().isEmpty) faltando.add('Descrição');

    if (faltando.isNotEmpty) {
      _aviso('Preencha: ${faltando.join(', ')}');
      return;
    }

    final payload = {
      'unb': _unb,
      'departamento': _departamento,
      'relator': _identificar ? _nomeUsuario : 'ANÔNIMO',
      'relatado': _relatado,
      'data_relato': _dataPayload(),
      'area_relatada': _area,
      'processo': _processos.toList(),
      'tarefa_atividade': '', // não é preenchida no app (vem só da importação da planilha)
      'classificacao': _classificacao,
      'detalhe_classificacao': _detalhe == kDetalheOutro
          ? _detalheOutroController.text.trim().toUpperCase()
          : _detalhe,
      'acao_imediata': _acaoImediata,
      'descricao': _descricaoController.text.trim(),
    };

    setState(() => _salvando = true);
    try {
      final response = await Api.post('/api/relatos', payload);
      final corpo = utf8.decode(response.bodyBytes);
      debugPrint('POST relato -> ${response.statusCode}: $corpo');
      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        String protocolo = '';
        try {
          final json = jsonDecode(corpo);
          if (json is Map && json['protocolo'] != null) protocolo = ' Protocolo: ${json['protocolo']}';
        } catch (_) {}
        _aviso('Relato registrado com sucesso!$protocolo', cor: Colors.green);
        _limparFormulario();
        Navigator.pop(context, true);
      } else {
        _aviso(_resumirErro(response.statusCode, corpo));
      }
    } catch (e) {
      debugPrint('Erro ao salvar relato: $e');
      if (mounted) _aviso('Falha de conexão com o servidor.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  // =====================================================
  // UI
  // =====================================================
  InputDecoration _decoracao(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        alignLabelWithHint: true,
      );

  Widget _dropdown({
    required String label,
    required List<String> opcoes,
    required String? valor,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      decoration: _decoracao(label),
      value: valor,
      isExpanded: true, // textos longos (tarefa/ação) quebram sem estourar a tela
      hint: const Text('Selecione uma opção...'),
      items: opcoes
          .map((o) => DropdownMenuItem<String>(
                value: o,
                child: Text(o, overflow: TextOverflow.ellipsis, maxLines: 2),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Novo Relato')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. DATA
            _buildSessao(
              "1. Data da Ocorrência",
              "Quando o evento aconteceu?",
              InkWell(
                onTap: _escolherData,
                child: InputDecorator(
                  decoration: _decoracao('Data').copyWith(suffixIcon: const Icon(Icons.calendar_month)),
                  child: Text(_dataBr(_dataRelato), style: const TextStyle(fontSize: 16)),
                ),
              ),
            ),

            // 2. IDENTIFICAÇÃO
            _buildSessao(
              "2. Identificação",
              "Como prefere registrar este relato?",
              Column(
                children: [
                  RadioListTile<bool>(
                    contentPadding: EdgeInsets.zero,
                    title: Text("Quero me identificar ($_nomeUsuario)", style: const TextStyle(fontWeight: FontWeight.bold)),
                    value: true,
                    groupValue: _identificar,
                    onChanged: (v) => setState(() => _identificar = v ?? true),
                  ),
                  RadioListTile<bool>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Não quero me identificar"),
                    value: false,
                    groupValue: _identificar,
                    onChanged: (v) => setState(() => _identificar = v ?? false),
                  ),
                  const SizedBox(height: 8),
                  _dropdown(
                    label: 'UNB*',
                    opcoes: kListaUnb,
                    valor: _unb,
                    onChanged: (v) => setState(() => _unb = v ?? _unb),
                  ),
                  const SizedBox(height: 16),
                  _dropdown(
                    label: 'Departamento*',
                    opcoes: kListaDepartamentos,
                    valor: _departamento,
                    onChanged: (v) => setState(() => _departamento = v ?? _departamento),
                  ),
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: _decoracao('Relator*').copyWith(filled: true, fillColor: Colors.grey.shade100),
                    child: Text(_identificar ? _nomeUsuario : 'ANÔNIMO', style: TextStyle(color: Colors.grey.shade700)),
                  ),
                  const SizedBox(height: 16),
                  _isLoadingColaboradores
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Row(
                            children: [
                              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                              SizedBox(width: 16),
                              Text('Carregando colaboradores...', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : Autocomplete<String>(
                          key: _autocompleteKey,
                          optionsBuilder: (TextEditingValue v) {
                            if (v.text.isEmpty) return _nomesColaboradores.take(15);
                            final termo = v.text.toLowerCase();
                            return _nomesColaboradores.where((o) => o.toLowerCase().contains(termo));
                          },
                          onSelected: (s) => setState(() => _relatado = s),
                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              // só vale nome escolhido na lista (igual ao select da web)
                              onChanged: (texto) {
                                final t = texto.trim();
                                _relatado = _nomesColaboradores.contains(t) ? t : null;
                              },
                              decoration: _decoracao('Colaborador relatado*', hint: 'Digite para buscar...')
                                  .copyWith(suffixIcon: const Icon(Icons.search)),
                            );
                          },
                        ),
                ],
              ),
            ),

            // 3. DETALHES E CLASSIFICAÇÃO
            _buildSessao(
              "3. Detalhes e Classificação",
              "Onde ocorreu e o que foi feito na hora.",
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dropdown(
                    label: 'Área relatada*',
                    opcoes: kListaArea,
                    valor: _area,
                    onChanged: (v) => setState(() => _area = v),
                  ),
                  const SizedBox(height: 16),
                  _dropdown(
                    label: 'Ação imediata*',
                    opcoes: kListaAcao,
                    valor: _acaoImediata,
                    onChanged: (v) => setState(() => _acaoImediata = v),
                  ),
                  const SizedBox(height: 20),
                  const Text('Processo* (selecione um ou mais)', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kListaProcesso.map((p) {
                      return FilterChip(
                        label: Text(p),
                        selected: _processos.contains(p),
                        onSelected: (sel) => setState(() => sel ? _processos.add(p) : _processos.remove(p)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text('Classificação*', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kListaClassificacao.map((c) {
                      return ChoiceChip(
                        label: Text(c),
                        selected: _classificacao == c,
                        onSelected: (sel) => setState(() {
                          _classificacao = sel ? c : null;
                          _detalhe = null;
                          _detalheOutroController.clear();
                        }),
                      );
                    }).toList(),
                  ),
                  if (_classificacao != null) ...[
                    const SizedBox(height: 16),
                    _dropdown(
                      label: 'Detalhe da classificação*',
                      opcoes: _opcoesDetalhe,
                      valor: _detalhe,
                      onChanged: (v) => setState(() => _detalhe = v),
                    ),
                  ],
                  if (_detalhe == kDetalheOutro) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _detalheOutroController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: _decoracao('Descreva o detalhe*', hint: 'Ex: USO INCORRETO DE EPI'),
                    ),
                  ],
                ],
              ),
            ),

            // 4. DESCRIÇÃO
            _buildSessao(
              "4. Descrição do Relato*",
              "Seja o mais detalhado possível para facilitar a análise.",
              TextFormField(
                controller: _descricaoController,
                maxLines: 4,
                decoration: _decoracao('Descrição', hint: 'Descreva os detalhes da ocorrência...'),
              ),
            ),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _salvando ? null : _salvarRelato,
                icon: _salvando
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: Text(_salvando ? 'Salvando...' : 'Salvar Relato', style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSessao(String titulo, String subtitulo, Widget conteudo) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text(subtitulo, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          conteudo,
        ],
      ),
    );
  }
}
