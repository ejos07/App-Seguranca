import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api.dart';
import '../widgets/comum.dart';

// =====================================================
// Normalização (igual ao normalizarChave/padronizar do DTO.tsx):
// sem acento, MAIÚSCULO, só A-Z e 0-9
// =====================================================
const String _comAcento = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
const String _semAcentoMap = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';

String _tirarAcento(String s) {
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = _comAcento.indexOf(ch);
    b.write(i >= 0 ? _semAcentoMap.substring(i, i + 1) : ch);
  }
  return b.toString();
}

String chaveLimpa(dynamic v) =>
    _tirarAcento((v ?? '').toString()).toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

List<String> _comoLista(dynamic v) {
  if (v is List) {
    return v.map((e) => (e ?? '').toString().trim()).where((e) => e.isNotEmpty).toList();
  }
  if (v is String) {
    return v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
  return <String>[];
}

// =====================================================
// MATRIZ DE PERGUNTAS (cópia da MATRIZ_PERGUNTAS do DTO.tsx)
// Ao alterar no web, altere aqui também.
// =====================================================
const Map<String, List<String>> kMatrizPerguntas = {
  "Direção Segura": [
    "Você respeita as leis de trânsito durante toda a condução, bem como o limite de velocidade?",
    "Você utiliza cinto de segurança durante todo o percurso?",
    "Você mantém distância segura?",
    "Você pratica direção defensiva?",
    "Você conduz mantendo desempenho adequado conforme prontuário do condutor?",
  ],
  "Uso de Equipamento de Elevação": [
    "Você realiza a operação de equipamentos de elevação conforme o procedimento estabelecido (Padrão/LUP)?",
    "Você verifica as condições do equipamento antes do uso (inspeção visual e funcionamento)?",
    "Você empura a paleteria ao inves de puxa-la? Em rampa sempre está na parte alta?",
    "Você respeita a capacidade máxima de carga e utiliza o equipamento somente dentro dos limites seguros?",
    "Você garante que a área está isolada e sem presença de pessoas na zona de risco durante a operação?",
  ],
  "Des (Carga)": [
    "Você realiza a atividade apenas em área designada (RED ZONE)?",
    "Você utiliza trava-rodas, realiza o controle de chaves do veículo durante a operação e aguarda o condutor se retirar do local para iniciar operação?",
    "Você respeita a segregação e mantém ausência de pedestres na área?",
    "No caso de vans, você segue o procedimento seguro de (des) carregamento conforme padrão da empresa?",
    "Você interrompe a atividade ao identificar qualquer situação de risco?",
  ],
  "Equipamentos motorizados/paleteiras": [
    "Você opera equipamentos motorizados e paleteiras conforme o procedimento estabelecido (Padrão/LUP)?",
    "Você realiza a operação com segurança, utilizando buzina, respeitando limites de velocidade e adotando cautela em cruzamentos e áreas de circulação?",
    "Você respeita a segregação entre pedestres e equipamentos, evitando circulação em áreas não autorizadas?",
    "Você mantém controle do equipamento durante toda a operação, garantindo estabilidade da carga e uso adequado do equipamento?",
    "Ao identificar qualquer risco, falha ou condição insegura, você interrompe a operação e comunica imediatamente a liderança?",
  ],
  "CheckList Pré-Uso": [
    "Você realiza a inspeção pré-uso antes de operar o equipamento/veículo?",
    "Você verifica as condições gerais do equipamento, como freios, direção, pneus/rodas, sinalização e dispositivos de segurança?",
    "Você confere se existem danos, falhas ou irregularidades antes da operação?",
    "Ao identificar alguma anomalia, você interrompe o uso do equipamento e comunica imediatamente a liderança?",
    "Você registra a inspeção conforme procedimento ou checklist estabelecido pela empresa?",
  ],
  "Trabalho Altura": [
    "Você utiliza a plataforma do caminhão conforme procedimento estabelecido (Padrão/LUP), sem improvisar meios de acesso?",
    "Você respeita o limite seguro de altura, não acessando locais acima de 2 metros durante a atividade?",
    "Você realiza a atividade na plataforma mantendo estabilidade e posição segura, evitando riscos de queda?",
    "Você evita improvisações para ganho de altura (ex.: subir em caixa, pallet, estrutura do caminhão)?",
    "Ao identificar qualquer condição insegura na atividade, você interrompe a operação e comunica imediatamente a liderança?",
  ],
  "Abastecimento Diesel": [
    "A portaria comunicou a chegada do combustivel?",
    "O terceiro passou por integração de visitantes, para conhecer as regras da empresa?",
    "Conferiu e validou documentação, realizando a abertura da PT?",
    "Área de descarga devidamente sinalizada conforme a LUP?",
    "Atividade realizada sem intercorrências, finalizando PT?",
  ],
  "Carregamento Bateria": [
    "Você realiza o carregamento da bateria em área designada, organizada e adequada para a atividade?",
    "Você verifica se os cabos, conectores e fios estão em boas condições antes de iniciar o carregamento?",
    "Você segue as orientações da LUP (Lição de Um Ponto) disponível no local durante a execução do carregamento?",
    "Você realiza a conexão e desconexão da bateria de forma segura, evitando danos, mau contato ou risco elétrico?",
    "Você comunica imediatamente qualquer anormalidade identificada no equipamento, bateria ou local de carregamento?",
  ],
  "SAM": [
    "A equipe tranca/fecha o caminhão em todos os PDVs? Realizando o controle de chaves.",
    "O motorista garante a utilização do trava rodas antes das empilhadeiras iniciarem o processo de descarregamento?",
    "O motorista remove a chave da ignição e mantem sobre seu poder no caso da entrega, ou em caso de (des) carga no poder operador?",
  ],
  "Relatos": [
    "Você realiza o registro de todos os desvios, atos, condições, incidentes e acidentes identificados?",
    "Você sabe como registrar corretamente um relato no sistema?",
    "Ao identificar um desvio ou risco, você realiza o registro imediato no sistema e comunica a liderança?",
    "Os relatos são utilizados na sua área para análise e prevenção de acidentes graves (SIF-Possibilidade de lesão grave ou morte)?",
    "Você participa ou acompanha as ações corretivas geradas a partir dos relatos?",
  ],
  "Segurança Trajeto": [
    "Você realiza seu deslocamento casa–trabalho seguindo as orientações de segurança definidas pela empresa?",
    "Você utiliza os EPIs obrigatórios conforme o meio de transporte (ex.: capacete, jaqueta, refletivo)?",
    "Você respeita as leis de trânsito e adota comportamento seguro durante todo o trajeto?",
    "Você evita distrações durante o deslocamento (ex.: uso de celular, fones, desatenção)?",
    "Você adota medidas preventivas para reduzir riscos no trajeto e comunica situações perigosas identificadas?",
  ],
  "Trans. Seguro Local de Trabalho": [
    "Você utiliza sempre a faixa de pedestres e os caminhos sinalizados dentro da unidade?",
    "Não utiliza celular, fones de ouvido ou outros dispositivos enquanto caminho nas áreas operacionais?",
    "Mantém a distância mínima de 5 metros de empilhadeiras e equipamentos em movimento?",
    "Conhece e segue as regras do Plano de Tráfego da unidade para pedestres e veículos?",
    "Você interrompe a atividade ao identificar qualquer situação de risco?",
  ],
};

// Nomes alternativos (como pode estar no banco) -> nome oficial
const Map<String, String> kApelidosDto = {
  "Equipamentos motorizados-palete": "Equipamentos motorizados/paleteiras",
};

// Mesmos textos do web (o dashboard procura "INSEGURO")
const String kSeguro = 'Seguro (Reforço Positivo)';
const String kInseguro = 'INSEGURO (CORREÇÃO NECESSÁRIA)';

class DtoFormPage extends StatefulWidget {
  const DtoFormPage({super.key});

  @override
  State<DtoFormPage> createState() => _DtoFormPageState();
}

class _DtoFormPageState extends State<DtoFormPage> {
  final List<String> _listaUnb = ["RIZATTI", "BEVALE", "MINASBEB"];

  // Identidade / RBAC (mesma regra do DTO.tsx)
  String _nomeUsuario = '';
  String _perfil = '';
  String _cargo = '';
  bool _ehAdminOuSeguranca = false;
  bool _podeCriarDTO = false;
  bool _isLoadingPerfil = true;

  // Dados da API
  Map<String, dynamic> _equipe = {};
  bool _isLoadingEquipe = false;
  bool _isLoadingInteligencia = true;
  String _erroInteligencia = '';
  Map<String, List<String>> _mapaCargos = {};
  Set<String> _whitelist = {};
  Map<String, List<String>> _perguntasApi = {};

  // Perguntas locais por chave limpa (+ apelidos)
  late final Map<String, List<String>> _perguntasLocais = _montarPerguntasLocais();

  // Formulário
  DateTime _dataDto = DateTime.now();
  String _unbSelecionada = "RIZATTI";
  String? _relatadoSelecionado;
  String? _tipoDtoSelecionado;
  String _tipoComportamento = kSeguro;
  Key _autocompleteKey = UniqueKey();
  bool _salvando = false;

  final TextEditingController _descricaoCtrl = TextEditingController();
  final TextEditingController _acaoCtrl = TextEditingController();
  final Map<String, String> _respostas = {};

  static Map<String, List<String>> _montarPerguntasLocais() {
    final m = <String, List<String>>{};
    kMatrizPerguntas.forEach((tipo, perguntas) {
      m[chaveLimpa(tipo)] = perguntas.where((p) => p.trim().isNotEmpty).toList();
    });
    kApelidosDto.forEach((apelido, oficial) {
      final p = m[chaveLimpa(oficial)];
      if (p != null) m[chaveLimpa(apelido)] = p;
    });
    return m;
  }

  @override
  void initState() {
    super.initState();
    _inicializarTela();
  }

  @override
  void dispose() {
    _descricaoCtrl.dispose();
    _acaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _inicializarTela() async {
    await _carregarUsuarioLocal();
    if (_podeCriarDTO) {
      await Future.wait([
        _carregarInteligencia(),
        _carregarEquipe(_unbSelecionada),
      ]);
    }
  }

  Future<void> _carregarUsuarioLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final usuarioStr = prefs.getString('usuario');
    if (!mounted) return;

    if (usuarioStr != null) {
      final user = jsonDecode(usuarioStr);
      _nomeUsuario = user['nome'] ?? 'Usuário Desconhecido';
      _perfil = user['perfil'] ?? 'colaborador';
      _cargo = (user['cargo'] ?? '').toString().toUpperCase();

      _ehAdminOuSeguranca = _perfil == 'admin' ||
          _perfil == 'tecnico' ||
          _cargo.contains('SEGURANÇA') ||
          _cargo.contains('SEGURANCA');
      _podeCriarDTO = _ehAdminOuSeguranca ||
          ['SUPERVISOR', 'COORDENADOR', 'GERENTE'].any((p) => _cargo.contains(p));
    }

    setState(() => _isLoadingPerfil = false);

    if (!_podeCriarDTO && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sem permissão para criar DTOs.')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _carregarInteligencia() async {
    setState(() {
      _isLoadingInteligencia = true;
      _erroInteligencia = '';
    });
    try {
      final response = await Api.get('/api/dto/inteligencia');
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        final mapa = <String, List<String>>{};
        final mapaBruto = data is Map ? data['mapa_cargos'] : null;
        if (mapaBruto is Map) {
          mapaBruto.forEach((k, v) {
            mapa.putIfAbsent(chaveLimpa(k), () => <String>[]).addAll(_comoLista(v));
          });
        }

        final white = _comoLista(data is Map ? data['whitelist'] : null).map(chaveLimpa).toSet();

        final perg = <String, List<String>>{};
        final pergBruto = data is Map ? data['perguntas'] : null;
        if (pergBruto is Map) {
          pergBruto.forEach((k, v) => perg[chaveLimpa(k)] = _comoLista(v));
        }

        final avisos = data is Map ? data['avisos'] : null;
        if (avisos != null) debugPrint('DTO inteligencia - avisos: $avisos');

        setState(() {
          _mapaCargos = mapa;
          _whitelist = white;
          _perguntasApi = perg;
          _isLoadingInteligencia = false;
        });
      } else {
        setState(() {
          _erroInteligencia = 'Erro ao carregar tipos de DTO (${response.statusCode}).';
          _isLoadingInteligencia = false;
        });
      }
    } catch (e) {
      debugPrint('Erro inteligencia DTO: $e');
      if (mounted) {
        setState(() {
          _erroInteligencia = 'Falha de conexão ao carregar tipos de DTO.';
          _isLoadingInteligencia = false;
        });
      }
    }
  }

  Future<void> _carregarEquipe(String unb) async {
    setState(() => _isLoadingEquipe = true);
    try {
      // Igual ao web: admin/técnico/segurança veem todos -> perfil 'admin'
      final perfilParaApi = _ehAdminOuSeguranca ? 'admin' : _perfil;
      final query = 'unb=${Uri.encodeQueryComponent(unb)}'
          '&lider=${Uri.encodeQueryComponent(_nomeUsuario)}'
          '&perfil=${Uri.encodeQueryComponent(perfilParaApi)}';
      final response = await Api.get('/api/dto/equipe?$query');
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final eq = data is Map ? data['equipe'] : null;
        setState(() {
          _equipe = eq is Map ? Map<String, dynamic>.from(eq) : {};
          _limparSelecao();
          _isLoadingEquipe = false;
        });
      } else {
        setState(() => _isLoadingEquipe = false);
      }
    } catch (e) {
      debugPrint('Erro equipe DTO: $e');
      if (mounted) setState(() => _isLoadingEquipe = false);
    }
  }

  void _limparSelecao() {
    _relatadoSelecionado = null;
    _tipoDtoSelecionado = null;
    _respostas.clear();
    _autocompleteKey = UniqueKey();
  }

  String _cargoDe(String? nome) {
    if (nome == null) return '';
    final v = _equipe[nome];
    if (v is Map) return (v['cargo'] ?? v['Cargo'] ?? '').toString();
    return (v ?? '').toString();
  }

  // =====================================================
  // Tipos de DTO permitidos (mesma regra do obterDTOsPermitidas do web)
  // =====================================================
  (List<String>, String?) _obterDTOsPermitidas() {
    if (_relatadoSelecionado == null) return (<String>[], null);

    final cargo = _cargoDe(_relatadoSelecionado);
    final doCargo = _mapaCargos[chaveLimpa(cargo)] ?? const <String>[];

    // Whitelist só vale se NÃO apagar tudo
    final filtradas = doCargo.where((d) => _whitelist.contains(chaveLimpa(d))).toList();
    final base = filtradas.isNotEmpty ? filtradas : doCargo;

    // Únicas (comparando pela chave limpa)
    final vistas = <String>{};
    final unicas = <String>[];
    for (final d in base) {
      if (vistas.add(chaveLimpa(d))) unicas.add(d);
    }
    if (unicas.isNotEmpty) return (unicas, null);

    debugPrint('DTO: cargo "$cargo" (chave ${chaveLimpa(cargo)}) sem DTOs no mapa_cargos');
    final aviso = cargo.isEmpty
        ? 'Colaborador sem cargo cadastrado. Exibindo todas as DTOs.'
        : 'O cargo "$cargo" não tem DTOs cadastradas. Exibindo todas as DTOs.';
    return (kMatrizPerguntas.keys.toList(), aviso);
  }

  // Prioridade: matriz local; se não tiver, usa a da API (igual ao web)
  List<String> _obterPerguntasDoTipo() {
    if (_tipoDtoSelecionado == null) return const [];
    final chave = chaveLimpa(_tipoDtoSelecionado);
    return _perguntasLocais[chave] ?? _perguntasApi[chave] ?? const <String>[];
  }

  // =====================================================
  // Salvar (mesmo payload do handleSubmit do DTO.tsx)
  // =====================================================
  String _p2(int v) => v.toString().padLeft(2, '0');
  String _dataBr(DateTime d) => '${_p2(d.day)}/${_p2(d.month)}/${d.year}';

  String _dataPayload() {
    final agora = DateTime.now();
    return '${_dataDto.year}-${_p2(_dataDto.month)}-${_p2(_dataDto.day)} '
        '${_p2(agora.hour)}:${_p2(agora.minute)}';
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
        return 'Erro ao salvar DTO ($status): $campos';
      }
      if (detalhes != null) return 'Erro ao salvar DTO ($status): $detalhes';
    } catch (_) {}
    return 'Erro ao salvar DTO ($status)';
  }

  Future<void> _salvarDTO() async {
    FocusScope.of(context).unfocus();
    if (_relatadoSelecionado == null) return _mostrarErro("Selecione um Colaborador da lista.");
    if (_tipoDtoSelecionado == null) return _mostrarErro("Selecione o Tipo de DTO.");

    final perguntas = _obterPerguntasDoTipo();
    if (perguntas.any((p) => !_respostas.containsKey(p))) {
      return _mostrarErro("Por favor, responda a todas as perguntas do checklist.");
    }

    final payload = {
      'unb': _unbSelecionada,
      'relatado': _relatadoSelecionado,
      'data_relato': _dataPayload(),
      'tipo_dto': _tipoDtoSelecionado,
      'tipo_comportamento': _tipoComportamento,
      'descricao': _descricaoCtrl.text.trim(),
      'acao_tomada': _acaoCtrl.text.trim(),
      'relator': _nomeUsuario,
      // chave = texto da pergunta, valor = OK/NOK (igual ao web)
      'respostas_dict': {for (final p in perguntas) p: _respostas[p]},
    };

    setState(() => _salvando = true);
    try {
      var response = await Api.post('/api/dto', payload);
      // Se o FastAPI pedir a barra no final (307/308), tenta de novo com '/'
      if (response.statusCode == 307 || response.statusCode == 308) {
        response = await Api.post('/api/dto/', payload);
      }
      final corpo = utf8.decode(response.bodyBytes);
      debugPrint('POST DTO -> ${response.statusCode}: $corpo');
      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        String protocolo = '';
        try {
          final json = jsonDecode(corpo);
          if (json is Map && json['protocolo'] != null) protocolo = ' Protocolo: ${json['protocolo']}';
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('DTO registrada com sucesso!$protocolo'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      } else {
        _mostrarErro(_resumirErro(response.statusCode, corpo));
      }
    } catch (e) {
      debugPrint('Erro ao salvar DTO: $e');
      if (mounted) _mostrarErro('Falha de conexão com o servidor.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> _escolherData() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dataDto,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _dataDto = d);
  }

  // =====================================================
  // UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    if (_isLoadingPerfil) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final (dtosPermitidas, avisoDto) = _obterDTOsPermitidas();
    final perguntasAtuais = _obterPerguntasDoTipo();
    final respondidas = perguntasAtuais.where((p) => _respostas.containsKey(p)).length;
    final nok = perguntasAtuais.where((p) => _respostas[p] == 'NOK').length;

    String hintTipo;
    if (_isLoadingInteligencia) {
      hintTipo = 'Carregando tipos de DTO...';
    } else if (_relatadoSelecionado == null) {
      hintTipo = 'Selecione primeiro o colaborador';
    } else if (dtosPermitidas.isEmpty) {
      hintTipo = 'Nenhum tipo de DTO disponível';
    } else {
      hintTipo = 'Selecione o tipo...';
    }
    final cargo = _cargoDe(_relatadoSelecionado);

    return Scaffold(
      appBar: AppBar(title: const Text('Nova DTO')),
      bottomNavigationBar: BarraAcaoInferior(
        rotulo: 'Salvar DTO',
        icone: Icons.send_rounded,
        carregando: _salvando,
        onPressed: _salvarDTO,
        topo: perguntasAtuais.isEmpty
            ? null
            : ProgressoChecklist(respondidas: respondidas, total: perguntasAtuais.length, ruins: nok),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.all(AppEspaco.l),
          children: [
            // 1. DADOS GERAIS
            SecaoForm(
              titulo: 'Dados gerais',
              icone: Icons.event_note_outlined,
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: CampoData(label: 'Data', valor: _dataDto, onChanged: (d) => setState(() => _dataDto = d)),
                  ),
                  const SizedBox(width: AppEspaco.m),
                  Expanded(
                    child: CampoDropdown(
                      label: 'UNB*',
                      opcoes: _listaUnb,
                      valor: _unbSelecionada,
                      onChanged: (val) {
                        if (val != null && val != _unbSelecionada) {
                          setState(() => _unbSelecionada = val);
                          _carregarEquipe(val);
                        }
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: AppEspaco.m),
                CampoSomenteLeitura(label: 'Executor (você)', valor: _nomeUsuario, icone: Icons.person_outline),
              ]),
            ),

            // 2. COLABORADOR
            SecaoForm(
              titulo: 'Colaborador observado',
              icone: Icons.person_search_outlined,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CampoBuscaPessoa(
                  key: _autocompleteKey,
                  label: 'Colaborador observado*',
                  opcoes: _equipe.keys.toList()..sort(),
                  carregando: _isLoadingEquipe,
                  onChanged: (v) {
                    if (v != _relatadoSelecionado) {
                      setState(() {
                        _relatadoSelecionado = v;
                        _tipoDtoSelecionado = null;
                        _respostas.clear();
                      });
                    }
                  },
                ),
                if (_relatadoSelecionado != null) ...[
                  const SizedBox(height: AppEspaco.m),
                  Container(
                    padding: const EdgeInsets.all(AppEspaco.m),
                    decoration: BoxDecoration(
                      color: AppCores.superficieSuave,
                      borderRadius: BorderRadius.circular(AppRaio.m),
                      border: Border.all(color: AppCores.borda),
                    ),
                    child: Row(children: [
                      FotoPerfil(nome: _relatadoSelecionado!, raio: 22),
                      const SizedBox(width: AppEspaco.m),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_relatadoSelecionado!,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          const SizedBox(height: 2),
                          Text(cargo.isEmpty ? 'Cargo não informado' : cargo, style: AppTexto.legenda),
                        ]),
                      ),
                    ]),
                  ),
                ],
              ]),
            ),

            // 3. TIPO DE DTO
            SecaoForm(
              titulo: 'Tipo de DTO',
              icone: Icons.fact_check_outlined,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                DropdownButtonFormField<String>(
                  key: ValueKey('tipo-$_relatadoSelecionado'),
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(AppRaio.m),
                  icon: const Icon(Icons.expand_more),
                  decoration: decoracao('Tipo de DTO a ser aplicada*', prefixo: Icons.assignment_outlined),
                  value: dtosPermitidas.contains(_tipoDtoSelecionado) ? _tipoDtoSelecionado : null,
                  hint: Text(hintTipo, overflow: TextOverflow.ellipsis),
                  disabledHint: Text(hintTipo, overflow: TextOverflow.ellipsis),
                  items: dtosPermitidas
                      .map((dto) => DropdownMenuItem(value: dto, child: Text(dto, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: dtosPermitidas.isEmpty
                      ? null
                      : (val) => setState(() {
                            _tipoDtoSelecionado = val;
                            _respostas.clear();
                          }),
                ),
                if (avisoDto != null) ...[
                  const SizedBox(height: AppEspaco.s),
                  FaixaInfo(avisoDto, icone: Icons.info_outline, cor: AppCores.alerta),
                ],
                if (_erroInteligencia.isNotEmpty) ...[
                  const SizedBox(height: AppEspaco.s),
                  Row(children: [
                    Expanded(
                        child: Text(_erroInteligencia, style: const TextStyle(color: AppCores.perigo, fontSize: 12))),
                    TextButton.icon(
                      onPressed: _carregarInteligencia,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ]),
                ],
              ]),
            ),

            if (_tipoDtoSelecionado != null) ...[
              // 4. COMPORTAMENTO
              SecaoForm(
                titulo: 'Comportamento geral',
                icone: Icons.psychology_alt_outlined,
                child: SeletorCartoes<String>(
                  valor: _tipoComportamento,
                  onChanged: (v) => setState(() => _tipoComportamento = v),
                  opcoes: const [
                    OpcaoCartao(
                      valor: kSeguro,
                      titulo: 'Seguro',
                      subtitulo: 'Reforço positivo',
                      icone: Icons.verified_outlined,
                      cor: AppCores.sucesso,
                    ),
                    OpcaoCartao(
                      valor: kInseguro,
                      titulo: 'Inseguro',
                      subtitulo: 'Correção necessária',
                      icone: Icons.warning_amber_rounded,
                      cor: AppCores.perigo,
                    ),
                  ],
                ),
              ),

              // 5. CHECKLIST
              Padding(
                padding: const EdgeInsets.fromLTRB(AppEspaco.xs, AppEspaco.xs, AppEspaco.xs, AppEspaco.m),
                child: Text('CHECKLIST • ${_tipoDtoSelecionado!.toUpperCase()}', style: AppTexto.rotulo),
              ),
              if (perguntasAtuais.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: AppEspaco.l),
                  child: FaixaInfo('Este tipo de DTO não tem perguntas cadastradas.'),
                ),
              ...List.generate(perguntasAtuais.length, (i) {
                final p = perguntasAtuais.elementAt(i);
                return PerguntaBinaria(
                  numero: i + 1,
                  pergunta: p,
                  valor: _respostas[p],
                  onChanged: (v) => setState(() => _respostas[p] = v),
                );
              }),
              const SizedBox(height: AppEspaco.s),

              // 6. OBSERVAÇÕES
              SecaoForm(
                titulo: 'Observações',
                icone: Icons.notes_outlined,
                child: Column(children: [
                  TextFormField(
                    controller: _descricaoCtrl,
                    minLines: 3,
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: decoracao('Descrição / observações adicionais'),
                  ),
                  const SizedBox(height: AppEspaco.m),
                  TextFormField(
                    controller: _acaoCtrl,
                    minLines: 3,
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: decoracao('Ação tomada / recomendação'),
                  ),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
