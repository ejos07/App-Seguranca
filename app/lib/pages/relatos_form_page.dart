import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api.dart'; 

class RelatosFormPage extends StatefulWidget {
  @override
  _RelatosFormPageState createState() => _RelatosFormPageState();
}

class _RelatosFormPageState extends State<RelatosFormPage> {
  // Constantes de Negócio
  final List<String> listaUnb = ["RIZATTI", "BEVALE", "MINASBEB"];
  final List<String> listaDepartamentos = ["ADMINISTRATIVO", "ARMAZÉM", "COMERCIAL", "DISTRIBUIÇÃO", "PUXADA", "SEGURANÇA"];
  final List<String> listaClassificacao = ["Ato inseguro", "Condição insegura", "Abordagem positiva", "Incidente"];
  final List<String> listaArea = ["PUXADA", "ADMINISTRATIVO", "APOIO LOGÍSTICO", "VENDAS", "DISTRIBUIÇÃO URBANA"];
  
  // Controle de Estado
  bool _identificar = true;
  String _nomeUsuario = 'A carregar...'; 
  String? _relatadoSelecionado;
  String? _unbSelecionada;
  String? _departamentoSelecionado;
  String? _areaSelecionada;
  String? _classificacaoSelecionada;
  final TextEditingController _descricaoController = TextEditingController();

  // NOVOS ESTADOS PARA A API DE COLABORADORES
  List<String> _nomesColaboradores = [];
  bool _isLoadingColaboradores = true;

  @override
  void initState() {
    super.initState();
    _carregarUsuarioLocal(); 
    _carregarColaboradores(); // Busca os colaboradores ao abrir a tela
  }

  Future<void> _carregarUsuarioLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final usuarioStr = prefs.getString('usuario');

    if (usuarioStr != null && mounted) {
      try {
        final usuarioJson = jsonDecode(usuarioStr);
        setState(() {
          _nomeUsuario = usuarioJson['nome'] ?? 'Utilizador Desconhecido';
        });
      } catch (e) {
        setState(() => _nomeUsuario = 'Utilizador Desconhecido');
      }
    }
  }

  // NOVO MÉTODO: Chamada à API para buscar utilizadores
  Future<void> _carregarColaboradores() async {
    try {
      final response = await Api.get('/usuarios/');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        
        setState(() {
          Iterable lista = [];
          if (data is Map && data.containsKey('dados')) {
            lista = data['dados'] ?? [];
          } else if (data is List) {
            lista = data;
          }
          
          // Processa a string, remove vazios e duplicados (toSet) fora da Árvore de Widgets
          _nomesColaboradores = lista
              .map((c) => c['Nome']?.toString() ?? '')
              .where((nome) => nome.isNotEmpty)
              .toSet()
              .toList();
              
          _nomesColaboradores.sort(); // Ordem alfabética
          
          // Injeta a opção de fuga obrigatória no topo
          _nomesColaboradores.insert(0, "NÃO SE APLICA (Ex: Condição Insegura)");

          _isLoadingColaboradores = false;
        });
      } else {
        setState(() => _isLoadingColaboradores = false);
      }
    } catch (e) {
      print('Erro ao carregar colaboradores: $e');
      setState(() => _isLoadingColaboradores = false);
    }
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registar Novo Relato'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSessaoPergunta(
              "1. Identificação do Relator",
              "Como prefere registrar este relato?",
              Column(
                children: [
                  RadioListTile<bool>(
                    title: Text("Identificar-me como: $_nomeUsuario", style: const TextStyle(fontWeight: FontWeight.bold)),
                    value: true,
                    groupValue: _identificar,
                    onChanged: (bool? value) => setState(() => _identificar = value!),
                  ),
                  RadioListTile<bool>(
                    title: const Text("Prefiro manter o anonimato"),
                    value: false,
                    groupValue: _identificar,
                    onChanged: (bool? value) => setState(() => _identificar = value!),
                  ),
                ],
              ),
            ),

            _buildSessaoPergunta(
              "2. Colaborador Relatado",
              "Quem está envolvido nesta ocorrência?",
              _isLoadingColaboradores 
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Row(
                      children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 16),
                        Text('A carregar base de colaboradores...', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                // Componente Mobile de Alto Desempenho para listas pesadas
                : Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        // Se o campo estiver vazio, mostra apenas os primeiros para não travar a UI
                        return _nomesColaboradores.take(15);
                      }
                      // Filtro reativo em tempo real
                      return _nomesColaboradores.where((String opcao) {
                        return opcao.toLowerCase().contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    onSelected: (String selecao) {
                      setState(() => _relatadoSelecionado = selecao);
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      // Construção do Input visual com ícone de lupa
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Digite para buscar o colaborador...',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.search),
                        ),
                      );
                    },
                  ),
            ),

            _buildSessaoPergunta(
              "3. Onde ocorreu o evento?",
              "Indique o local exato da ocorrência.",
              Column(
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: "Selecione a UNB",
                      border: OutlineInputBorder(),
                    ),
                    value: _unbSelecionada,
                    items: listaUnb.map((String unb) {
                      return DropdownMenuItem<String>(value: unb, child: Text(unb));
                    }).toList(),
                    onChanged: (value) => setState(() => _unbSelecionada = value),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: "Selecione o Departamento",
                      border: OutlineInputBorder(),
                    ),
                    value: _departamentoSelecionado,
                    items: listaDepartamentos.map((String dep) {
                      return DropdownMenuItem<String>(value: dep, child: Text(dep));
                    }).toList(),
                    onChanged: (value) => setState(() => _departamentoSelecionado = value),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: "Selecione a Área Relatada",
                      border: OutlineInputBorder(),
                    ),
                    value: _areaSelecionada,
                    items: listaArea.map((String area) {
                      return DropdownMenuItem<String>(value: area, child: Text(area));
                    }).toList(),
                    onChanged: (value) => setState(() => _areaSelecionada = value),
                  ),
                ],
              ),
            ),

            _buildSessaoPergunta(
              "4. Como classifica esta ocorrência?",
              "Escolha a categoria que melhor descreve a situação.",
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: listaClassificacao.map((String c) {
                  return ChoiceChip(
                    label: Text(c),
                    selected: _classificacaoSelecionada == c,
                    onSelected: (bool selected) {
                      setState(() => _classificacaoSelecionada = selected ? c : null);
                    },
                  );
                }).toList(),
              ),
            ),

            _buildSessaoPergunta(
              "5. Descreva o que aconteceu",
              "Seja o mais detalhado possível para facilitar a análise.",
              TextFormField(
                controller: _descricaoController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: "Descreva os detalhes da ocorrência...",
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Lógica de POST...
                },
                icon: const Icon(Icons.save),
                label: const Text('Salvar Relato', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSessaoPergunta(String pergunta, String subtitulo, Widget conteudo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pergunta, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text(subtitulo, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          conteudo,
        ],
      ),
    );
  }
}