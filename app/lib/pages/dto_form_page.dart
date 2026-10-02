import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api.dart';

class DtoFormPage extends StatefulWidget {
  const DtoFormPage({super.key});

  @override
  State<DtoFormPage> createState() => _DtoFormPageState();
}

class _DtoFormPageState extends State<DtoFormPage> {
  final List<String> _listaUnb = ["RIZATTI", "BEVALE", "MINASBEB"];
  
  // Identidade do Utilizador (RBAC)
  String _nomeUsuario = '';
  String _perfil = '';
  String _cargo = '';
  bool _podeCriarDTO = false;
  bool _isLoadingPerfil = true;

  // Estados dos Dados da API
  Map<String, dynamic> _equipe = {};
  Map<String, dynamic> _inteligencia = {
    'whitelist': [],
    'perguntas': {},
    'mapa_cargos': {}
  };

  // Estado do Formulário
  String _unbSelecionada = "RIZATTI";
  String? _relatadoSelecionado;
  String? _tipoDtoSelecionado;
  String _tipoComportamento = 'Seguro (Reforço Positivo)';
  
  final TextEditingController _descricaoCtrl = TextEditingController();
  final TextEditingController _acaoCtrl = TextEditingController();
  
  // Guarda as respostas dinâmicas do checklist
  Map<String, String> _respostas = {};

  @override
  void initState() {
    super.initState();
    _inicializarTela();
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

  // Equivalente a JSON.parse(localStorage.getItem('usuario'))
  Future<void> _carregarUsuarioLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final usuarioStr = prefs.getString('usuario');

    if (usuarioStr != null && mounted) {
      final user = jsonDecode(usuarioStr);
      _nomeUsuario = user['nome'] ?? 'Desconhecido';
      _perfil = user['perfil'] ?? 'colaborador';
      _cargo = (user['cargo'] ?? '').toUpperCase();

      // Validação de Acesso (RBAC)
      final cargosPermitidos = ['SUPERVISOR', 'COORDENADOR', 'GERENTE', 'SEGURANÇA'];
      _podeCriarDTO = _perfil == 'admin' || cargosPermitidos.any((p) => _cargo.contains(p));
      
      setState(() => _isLoadingPerfil = false);
      
      if (!_podeCriarDTO && mounted) {
        // Expulsa da tela se não tiver permissão
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sem permissão para criar DTOs.')),
        );
      }
    }
  }

  Future<void> _carregarInteligencia() async {
    try {
      final response = await Api.get('/dto/inteligencia');
      if (response.statusCode == 200) {
        setState(() {
          _inteligencia = jsonDecode(utf8.decode(response.bodyBytes));
        });
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _carregarEquipe(String unb) async {
    try {
      final response = await Api.get('/dto/equipe?unb=$unb&lider=$_nomeUsuario&perfil=$_perfil');
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _equipe = data['equipe'] ?? {};
          _relatadoSelecionado = null;
          _tipoDtoSelecionado = null;
          _respostas.clear();
        });
      }
    } catch (e) {
      print(e);
    }
  }

  // Motor de cruzamento de Cargos vs Whitelist (Equivalente ao seu TSX)
  List<String> _obterDTOsPermitidas() {
    if (_relatadoSelecionado == null) return [];
    
    final cargoColaborador = _equipe[_relatadoSelecionado] ?? '';
    final cargoLimpo = cargoColaborador.replaceAll(RegExp(r'[^\w\s]+'), '').toUpperCase().trim();
    
    final todasDTOsDoCargo = _inteligencia['mapa_cargos']?[cargoLimpo] ?? [];
    final whitelist = List<String>.from(_inteligencia['whitelist'] ?? []);

    return List<String>.from(todasDTOsDoCargo.where((dto) {
      final superLimpo = dto.replaceAll(RegExp(r'[^A-Z0-9]', caseSensitive: false), '').toUpperCase();
      return whitelist.contains(superLimpo);
    }));
  }

  Future<void> _salvarDTO() async {
    if (_relatadoSelecionado == null) return _mostrarErro("Selecione um Colaborador.");
    if (_tipoDtoSelecionado == null) return _mostrarErro("Selecione o Tipo de DTO.");

    final perguntasAtuais = List<String>.from(_obterPerguntasDoTipo());
    final perguntasNaoRespondidas = perguntasAtuais.where((p) => !_respostas.containsKey(p)).toList();
    
    if (perguntasNaoRespondidas.isNotEmpty) {
      return _mostrarErro("Responda a todas as perguntas do checklist.");
    }

    // Lógica de POST API entraria aqui...
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('DTO enviada com sucesso!'), backgroundColor: Colors.green),
    );
    Navigator.pop(context); // Volta para a tela anterior
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  List<String> _obterPerguntasDoTipo() {
    if (_tipoDtoSelecionado == null) return [];
    final chave = _tipoDtoSelecionado!.replaceAll(RegExp(r'[^A-Z0-9]', caseSensitive: false), '').toUpperCase();
    return List<String>.from(_inteligencia['perguntas']?[chave] ?? []);
  }

  @override
  void dispose() {
    _descricaoCtrl.dispose();
    _acaoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPerfil) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final dtosPermitidas = _obterDTOsPermitidas();
    final perguntasAtuais = _obterPerguntasDoTipo();

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Novo DTO')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. UNB e Data
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'UNB*', border: OutlineInputBorder()),
              value: _unbSelecionada,
              items: _listaUnb.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _unbSelecionada = val);
                  _carregarEquipe(val); // Atualiza equipe ao trocar a UNB
                }
              },
            ),
            const SizedBox(height: 16),

            // 2. Colaborador Observado (Autocomplete de Alta Performance)
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                final opcoes = _equipe.keys.toList();
                if (textEditingValue.text.isEmpty) return opcoes.take(10);
                return opcoes.where((nome) => nome.toLowerCase().contains(textEditingValue.text.toLowerCase()));
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
                  decoration: InputDecoration(
                    labelText: 'Colaborador Observado*',
                    hintText: 'Digite o nome...',
                    border: const OutlineInputBorder(),
                    suffixIcon: _equipe.isEmpty ? const CircularProgressIndicator() : const Icon(Icons.search),
                  ),
                );
              },
            ),
            if (_relatadoSelecionado != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                child: Text('Cargo: ${_equipe[_relatadoSelecionado] ?? "N/A"}', style: const TextStyle(color: Colors.grey)),
              ),
            
            const Divider(height: 32),

            // 3. Seleção do Tipo de DTO
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'TIPO DE DTO*', border: OutlineInputBorder()),
              value: _tipoDtoSelecionado,
              items: dtosPermitidas.map((dto) => DropdownMenuItem(value: dto, child: Text(dto, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (val) {
                setState(() {
                  _tipoDtoSelecionado = val;
                  _respostas.clear();
                });
              },
            ),

            if (_tipoDtoSelecionado != null) ...[
              const SizedBox(height: 24),
              const Text('Tipo de Comportamento Geral', style: TextStyle(fontWeight: FontWeight.bold)),
              RadioListTile<String>(
                title: const Text('Seguro (Reforço Positivo)'),
                value: 'Seguro (Reforço Positivo)',
                groupValue: _tipoComportamento,
                onChanged: (val) => setState(() => _tipoComportamento = val!),
              ),
              RadioListTile<String>(
                title: const Text('Inseguro (Correção necessária)'),
                value: 'Inseguro (Correção necessária)',
                groupValue: _tipoComportamento,
                onChanged: (val) => setState(() => _tipoComportamento = val!),
              ),

              // 4. Checklist Dinâmico
              Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: perguntasAtuais.map((pergunta) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pergunta, style: const TextStyle(fontWeight: FontWeight.w500)),
                          Row(
                            children: [
                              Expanded(
                                child: RadioListTile<String>(
                                  title: const Text('OK'),
                                  value: 'OK',
                                  groupValue: _respostas[pergunta],
                                  onChanged: (val) => setState(() => _respostas[pergunta] = val!),
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<String>(
                                  title: const Text('NOK'),
                                  value: 'NOK',
                                  groupValue: _respostas[pergunta],
                                  onChanged: (val) => setState(() => _respostas[pergunta] = val!),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

              TextFormField(
                controller: _descricaoCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Descrição / Observações', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _acaoCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Ação Tomada', border: OutlineInputBorder()),
              ),
            ],

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _salvarDTO,
                icon: const Icon(Icons.save),
                label: const Text('Salvar DTO', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}