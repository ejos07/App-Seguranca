import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Novo DTO')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Data + UNB
            InkWell(
              onTap: _escolherData,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_month),
                ),
                child: Text(_dataBr(_dataDto), style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'UNB*', border: OutlineInputBorder()),
              value: _unbSelecionada,
              items: _listaUnb.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
              onChanged: (val) {
                if (val != null && val != _unbSelecionada) {
                  setState(() => _unbSelecionada = val);
                  _carregarEquipe(val);
                }
              },
            ),
            const SizedBox(height: 16),

            // Executor (você)
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'EXECUTOR (Você)*',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              child: Text(_nomeUsuario, style: TextStyle(color: Colors.grey.shade700)),
            ),
            const SizedBox(height: 16),

            // Colaborador observado
            Autocomplete<String>(
              key: _autocompleteKey,
              optionsBuilder: (TextEditingValue v) {
                final opcoes = _equipe.keys.toList()..sort();
                if (v.text.isEmpty) return opcoes.take(15);
                final termo = _tirarAcento(v.text).toLowerCase();
                return opcoes.where((nome) => _tirarAcento(nome).toLowerCase().contains(termo));
              },
              onSelected: (String selecao) {
                setState(() {
                  _relatadoSelecionado = selecao;
                  _tipoDtoSelecionado = null;
                  _respostas.clear();
                });
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: (texto) {
                    final t = texto.trim();
                    final achado = _equipe.containsKey(t) ? t : null;
                    if (achado != _relatadoSelecionado) {
                      setState(() {
                        _relatadoSelecionado = achado;
                        _tipoDtoSelecionado = null;
                        _respostas.clear();
                      });
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'COLABORADOR OBSERVADO*',
                    hintText: _isLoadingEquipe
                        ? 'Carregando equipe...'
                        : (_equipe.isEmpty ? 'Nenhum colaborador nesta UNB' : 'Digite o nome...'),
                    border: const OutlineInputBorder(),
                    suffixIcon: _isLoadingEquipe
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : const Icon(Icons.search),
                  ),
                );
              },
            ),
            if (_relatadoSelecionado != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Cargo identificado: ${_cargoDe(_relatadoSelecionado).isEmpty ? "N/A" : _cargoDe(_relatadoSelecionado)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),

            const Divider(height: 32),

            // Tipo de DTO
            DropdownButtonFormField<String>(
              key: ValueKey('tipo-$_relatadoSelecionado'),
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'TIPO DE DTO A SER APLICADA*', border: OutlineInputBorder()),
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
            if (avisoDto != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('⚠ $avisoDto', style: TextStyle(color: Colors.orange.shade800, fontSize: 12)),
              ),
            if (_erroInteligencia.isNotEmpty)
              Row(
                children: [
                  Expanded(child: Text(_erroInteligencia, style: const TextStyle(color: Colors.red, fontSize: 12))),
                  TextButton.icon(
                    onPressed: _carregarInteligencia,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                  ),
                ],
              ),

            if (_tipoDtoSelecionado != null) ...[
              const SizedBox(height: 24),
              const Text('Tipo de Comportamento Geral', style: TextStyle(fontWeight: FontWeight.bold)),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: const Text(kSeguro),
                value: kSeguro,
                groupValue: _tipoComportamento,
                onChanged: (val) => setState(() => _tipoComportamento = val ?? _tipoComportamento),
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: const Text(kInseguro),
                value: kInseguro,
                groupValue: _tipoComportamento,
                onChanged: (val) => setState(() => _tipoComportamento = val ?? _tipoComportamento),
              ),

              // Checklist
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(vertical: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Perguntas: $_tipoDtoSelecionado', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (perguntasAtuais.isEmpty)
                      const Text('Este tipo de DTO não tem perguntas cadastradas.', style: TextStyle(color: Colors.grey)),
                    ...perguntasAtuais.map((pergunta) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(pergunta, style: const TextStyle(fontWeight: FontWeight.w500)),
                            Row(
                              children: [
                                Expanded(
                                  child: RadioListTile<String>(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('OK'),
                                    value: 'OK',
                                    groupValue: _respostas[pergunta],
                                    onChanged: (val) => setState(() => _respostas[pergunta] = val ?? 'OK'),
                                  ),
                                ),
                                Expanded(
                                  child: RadioListTile<String>(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('NOK'),
                                    value: 'NOK',
                                    groupValue: _respostas[pergunta],
                                    onChanged: (val) => setState(() => _respostas[pergunta] = val ?? 'NOK'),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 1),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              TextFormField(
                controller: _descricaoCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descrição / Observações Adicionais',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _acaoCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Ação Tomada / Recomendação',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ],

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _salvando ? null : _salvarDTO,
                icon: _salvando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(_salvando ? 'Salvando...' : 'Salvar DTO', style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
