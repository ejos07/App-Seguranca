import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api.dart';
import '../widgets/comum.dart';

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
  int get _camposPreenchidos {
    var n = 0;
    if (_relatado != null) n++;
    if (_area != null) n++;
    if (_acaoImediata != null) n++;
    if (_processos.isNotEmpty) n++;
    if (_classificacao != null) n++;
    if (_detalhe != null && (_detalhe != kDetalheOutro || _detalheOutroController.text.trim().isNotEmpty)) n++;
    if (_descricaoController.text.trim().isNotEmpty) n++;
    return n;
  }

  Widget _dropdown({
    required String label,
    required List<String> opcoes,
    required String? valor,
    required ValueChanged<String?> onChanged,
    IconData? icone,
  }) {
    return CampoDropdown(
      label: label,
      opcoes: opcoes,
      valor: valor,
      onChanged: onChanged,
      hint: 'Selecione uma opção...',
      icone: icone,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo Relato')),
      bottomNavigationBar: BarraAcaoInferior(
        rotulo: 'Salvar Relato',
        icone: Icons.send_rounded,
        carregando: _salvando,
        onPressed: _salvarRelato,
        topo: ProgressoChecklist(respondidas: _camposPreenchidos, total: 7, sufixo: 'campos preenchidos'),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.all(AppEspaco.l),
          children: [
            // 1. QUANDO
            SecaoForm(
              titulo: 'Quando aconteceu?',
              icone: Icons.event_outlined,
              child: CampoData(
                label: 'Data da ocorrência',
                valor: _dataRelato,
                onChanged: (d) => setState(() => _dataRelato = d),
              ),
            ),

            // 2. IDENTIFICAÇÃO
            SecaoForm(
              titulo: 'Identificação',
              subtitulo: 'Como prefere registrar este relato?',
              icone: Icons.badge_outlined,
              child: Column(children: [
                SeletorCartoes<bool>(
                  valor: _identificar,
                  onChanged: (v) => setState(() => _identificar = v),
                  opcoes: [
                    OpcaoCartao(
                      valor: true,
                      titulo: 'Me identificar',
                      subtitulo: _nomeUsuario,
                      icone: Icons.person_outline,
                    ),
                    const OpcaoCartao(
                      valor: false,
                      titulo: 'Anônimo',
                      subtitulo: 'Seu nome não aparece',
                      icone: Icons.visibility_off_outlined,
                      cor: AppCores.cabecalho2,
                    ),
                  ],
                ),
                const SizedBox(height: AppEspaco.l),
                Row(children: [
                  Expanded(
                    child: _dropdown(
                      label: 'UNB*',
                      opcoes: kListaUnb,
                      valor: _unb,
                      onChanged: (v) => setState(() => _unb = v ?? _unb),
                    ),
                  ),
                ]),
                const SizedBox(height: AppEspaco.m),
                _dropdown(
                  label: 'Departamento*',
                  opcoes: kListaDepartamentos,
                  valor: _departamento,
                  onChanged: (v) => setState(() => _departamento = v ?? _departamento),
                ),
              ]),
            ),

            // 3. QUEM
            SecaoForm(
              titulo: 'Quem está envolvido?',
              subtitulo: 'Use "NÃO SE APLICA" para condições inseguras sem pessoa envolvida.',
              icone: Icons.groups_2_outlined,
              child: CampoBuscaPessoa(
                key: _autocompleteKey,
                label: 'Colaborador relatado*',
                opcoes: _nomesColaboradores,
                carregando: _isLoadingColaboradores,
                onChanged: (v) => setState(() => _relatado = v),
              ),
            ),

            // 4. ONDE / O QUE
            SecaoForm(
              titulo: 'Onde e o que foi feito',
              icone: Icons.place_outlined,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _dropdown(
                  label: 'Área relatada*',
                  opcoes: kListaArea,
                  valor: _area,
                  icone: Icons.map_outlined,
                  onChanged: (v) => setState(() => _area = v),
                ),
                const SizedBox(height: AppEspaco.m),
                _dropdown(
                  label: 'Ação imediata*',
                  opcoes: kListaAcao,
                  valor: _acaoImediata,
                  icone: Icons.bolt_outlined,
                  onChanged: (v) => setState(() => _acaoImediata = v),
                ),
                const SizedBox(height: AppEspaco.l),
                const RotuloCampo('Processo* (um ou mais)'),
                Wrap(
                  spacing: AppEspaco.s,
                  runSpacing: AppEspaco.s,
                  children: kListaProcesso.map((p) {
                    final sel = _processos.contains(p);
                    return FilterChip(
                      label: Text(p),
                      selected: sel,
                      showCheckmark: true,
                      checkmarkColor: AppCores.primaria,
                      onSelected: (s) => setState(() => s ? _processos.add(p) : _processos.remove(p)),
                    );
                  }).toList(),
                ),
              ]),
            ),

            // 5. CLASSIFICAÇÃO
            SecaoForm(
              titulo: 'Classificação',
              icone: Icons.category_outlined,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ...kListaClassificacao.map((c) {
                  final (cor, icone) = _estiloClassificacao(c);
                  final sel = _classificacao == c;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppEspaco.s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      decoration: BoxDecoration(
                        color: sel ? cor.withOpacity(0.08) : AppCores.superficie,
                        borderRadius: BorderRadius.circular(AppRaio.m),
                        border: Border.all(color: sel ? cor : AppCores.borda, width: sel ? 1.6 : 1),
                      ),
                      child: ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRaio.m)),
                        leading: Icon(icone, color: cor),
                        title: Text(c,
                            style: TextStyle(fontWeight: FontWeight.w600, color: sel ? cor : AppCores.texto)),
                        trailing: Icon(sel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            color: sel ? cor : AppCores.textoSuave),
                        onTap: () => setState(() {
                          _classificacao = c;
                          _detalhe = null;
                          _detalheOutroController.clear();
                        }),
                      ),
                    ),
                  );
                }),
                if (_classificacao != null) ...[
                  const SizedBox(height: AppEspaco.s),
                  _dropdown(
                    label: 'Detalhe da classificação*',
                    opcoes: _opcoesDetalhe,
                    valor: _detalhe,
                    icone: Icons.list_alt_outlined,
                    onChanged: (v) => setState(() => _detalhe = v),
                  ),
                ],
                if (_detalhe == kDetalheOutro) ...[
                  const SizedBox(height: AppEspaco.m),
                  TextFormField(
                    controller: _detalheOutroController,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => setState(() {}),
                    decoration: decoracao('Descreva o detalhe*', hint: 'Ex: USO INCORRETO DE EPI'),
                  ),
                ],
              ]),
            ),

            // 6. DESCRIÇÃO
            SecaoForm(
              titulo: 'O que aconteceu?',
              subtitulo: 'Seja o mais detalhado possível para facilitar a análise.',
              icone: Icons.notes_outlined,
              child: TextFormField(
                controller: _descricaoController,
                minLines: 4,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: decoracao('Descrição*', hint: 'Descreva os detalhes da ocorrência...'),
              ),
            ),
            const SizedBox(height: AppEspaco.s),
          ],
        ),
      ),
    );
  }

  (Color, IconData) _estiloClassificacao(String c) {
    final s = _semAcento(c).toLowerCase();
    if (s.contains('ato inseguro')) return (AppCores.perigo, Icons.back_hand_outlined);
    if (s.contains('condic')) return (AppCores.alerta, Icons.warning_amber_rounded);
    if (s.contains('positiva')) return (AppCores.sucesso, Icons.thumb_up_alt_outlined);
    return (AppCores.info, Icons.report_outlined);
  }
}
