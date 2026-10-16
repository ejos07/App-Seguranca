import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api.dart';

// =====================================================
// LISTAS COMPARTILHADAS
// =====================================================
const List<String> kListaUnbs = ["RIZATTI", "BEVALE", "MINASBEB"];

// =====================================================
// SESSÃO DO USUÁRIO (equivale ao localStorage 'usuario' da web)
// =====================================================
class Sessao {
  final String nome;
  final String perfil; // admin | tecnico | colaborador
  final String cargo;
  final bool acessoAdmin;
  final Map<String, dynamic> bruto;

  const Sessao({
    required this.nome,
    required this.perfil,
    required this.cargo,
    required this.acessoAdmin,
    required this.bruto,
  });

  static const vazia = Sessao(nome: '', perfil: 'colaborador', cargo: '', acessoAdmin: false, bruto: {});

  static Future<Sessao> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('usuario');
    if (s == null || s.isEmpty) return vazia;
    try {
      final j = jsonDecode(s);
      if (j is! Map) return vazia;
      final acesso = j['acesso_admin'];
      return Sessao(
        nome: (j['nome'] ?? 'Usuário Desconhecido').toString(),
        perfil: (j['perfil'] ?? 'colaborador').toString(),
        cargo: (j['cargo'] ?? '').toString().toUpperCase(),
        acessoAdmin: acesso == true || acesso.toString().toLowerCase() == 'true',
        bruto: Map<String, dynamic>.from(j),
      );
    } catch (_) {
      return vazia;
    }
  }

  static Future<void> sair() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('usuario');
  }

  bool get ehAdmin => perfil == 'admin';
  bool get ehTST => cargo.contains('SEGURANÇA') || cargo.contains('SEGURANCA') || cargo.contains('TST');

  // Regra do GSD/GSA/GSP: admin, ou técnico com acesso_admin
  bool get podeExcluir => perfil == 'admin' || (perfil == 'tecnico' && acessoAdmin);

  // Regra do DTO.tsx
  bool get ehAdminOuSeguranca =>
      perfil == 'admin' || perfil == 'tecnico' || cargo.contains('SEGURANÇA') || cargo.contains('SEGURANCA');
  bool get podeCriarDTO =>
      ehAdminOuSeguranca || ['SUPERVISOR', 'COORDENADOR', 'GERENTE'].any((p) => cargo.contains(p));
}

// =====================================================
// REGRAS DE ACESSO DOS MÓDULOS (GSD / GSP / GSA)
// - Admin: acesso completo a tudo
// - Quem já APLICOU o módulo: completo (Novo + Consulta)
// - Quem já FOI AVALIADO no módulo ou tem cargo liberado: só Consulta (Meus Registros)
// - Demais: sem acesso (módulo nem aparece no menu)
// =====================================================
enum NivelAcesso { nenhum, consulta, completo }

/// Nome comparável: sem acento, maiúsculo, espaços simples
String chaveNome(dynamic v) =>
    semAcento((v ?? '').toString()).toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();

class RegraModulo {
  final String id;
  final String endpoint;
  final String campoAplicador;
  final String? campoAvaliado;
  final List<String> cargosConsulta; // cargo que é AVALIADO -> vê "Meus Registros"
  final List<String> cargosCompleto; // cargo que APLICA -> pode criar
  const RegraModulo({
    required this.id,
    required this.endpoint,
    required this.campoAplicador,
    this.campoAvaliado,
    this.cargosConsulta = const [],
    this.cargosCompleto = const [],
  });
}

/// Cargo comparável: sem acento, maiúsculo, sem espaços
String cargoCompacto(dynamic v) => chaveNome(v).replaceAll(' ', '');

bool cargoContem(String cargo, List<String> lista) {
  final c = cargoCompacto(cargo);
  return lista.any((x) => c.contains(cargoCompacto(x)));
}

// Cargos definidos em 16/10/2026
const List<String> kCargosGsd = ['MOTORISTA CAMINHAO DISTRIBUICAO', 'AJUDANTE DISTRIBUICAO'];
const List<String> kCargosGsp = ['MOTORISTA CARRETA PUXADA'];
const List<String> kCargosGsa = [
  'GERENTE DE OPERACOES E DISTRIBUICAO',
  'TECNICO DE SEGURANCA',
  'ANALISTA DE SEGURANCA',
  'COORDENADOR DE ARMAZEM',
];

const RegraModulo kRegraGsd = RegraModulo(
  id: 'gsd',
  endpoint: '/api/gsd/',
  campoAplicador: 'relator',
  campoAvaliado: 'relatado',
  cargosConsulta: kCargosGsd,
);
const RegraModulo kRegraGsp = RegraModulo(
  id: 'gsp',
  endpoint: '/api/gsp/',
  campoAplicador: 'avaliador',
  campoAvaliado: 'motorista',
  cargosConsulta: kCargosGsp,
);
const RegraModulo kRegraGsa = RegraModulo(
  id: 'gsa',
  endpoint: '/api/gsa/',
  campoAplicador: 'avaliador',
  cargosCompleto: kCargosGsa,
);

NivelAcesso calcularAcesso(Sessao s, RegraModulo regra, List<Map<String, dynamic>> historico) {
  if (s.ehAdmin) return NivelAcesso.completo;
  final eu = chaveNome(s.nome);
  if (eu.isEmpty) return NivelAcesso.nenhum;

  // Quem aplica (pelo cargo ou porque já aplicou) pode criar
  if (cargoContem(s.cargo, regra.cargosCompleto)) return NivelAcesso.completo;
  final aplicou = historico.any((h) => chaveNome(h[regra.campoAplicador]) == eu);
  if (aplicou) return NivelAcesso.completo;

  // Quem é avaliado (pelo cargo ou porque já foi avaliado) só consulta
  final campoAv = regra.campoAvaliado;
  final foiAvaliado = campoAv != null && historico.any((h) => chaveNome(h[campoAv]) == eu);
  if (foiAvaliado || cargoContem(s.cargo, regra.cargosConsulta)) return NivelAcesso.consulta;

  return NivelAcesso.nenhum;
}

/// O registro é "meu"? (aplicador ou avaliado)
bool registroEhMeu(Sessao s, RegraModulo regra, Map<String, dynamic> r) {
  final eu = chaveNome(s.nome);
  if (chaveNome(r[regra.campoAplicador]) == eu) return true;
  final campoAv = regra.campoAvaliado;
  return campoAv != null && chaveNome(r[campoAv]) == eu;
}

// =====================================================
// API com tolerância à barra final (FastAPI: /api/gsd x /api/gsd/)
// =====================================================
String _alternarBarra(String endpoint) {
  final i = endpoint.indexOf('?');
  var caminho = i >= 0 ? endpoint.substring(0, i) : endpoint;
  final query = i >= 0 ? endpoint.substring(i) : '';
  caminho = caminho.endsWith('/') ? caminho.substring(0, caminho.length - 1) : '$caminho/';
  return '$caminho$query';
}

bool _precisaTentarDeNovo(int s) => s == 307 || s == 308 || s == 404 || s == 405;

Future<http.Response> apiGet(String endpoint) async {
  final r = await Api.get(endpoint);
  if (_precisaTentarDeNovo(r.statusCode)) return Api.get(_alternarBarra(endpoint));
  return r;
}

Future<http.Response> apiPost(String endpoint, Map<String, dynamic> body) async {
  final r = await Api.post(endpoint, body);
  if (_precisaTentarDeNovo(r.statusCode)) return Api.post(_alternarBarra(endpoint), body);
  return r;
}

Future<http.Response> apiDelete(String endpoint) async {
  final r = await Api.delete(endpoint);
  if (_precisaTentarDeNovo(r.statusCode)) return Api.delete(_alternarBarra(endpoint));
  return r;
}

bool respostaOk(http.Response r) => r.statusCode >= 200 && r.statusCode < 300;

dynamic decodificar(http.Response r) {
  try {
    return jsonDecode(utf8.decode(r.bodyBytes));
  } catch (_) {
    return null;
  }
}

/// Lê {dados: [...]} ou [...] e devolve lista de mapas
List<Map<String, dynamic>> listaDados(dynamic data, {String chave = 'dados'}) {
  dynamic lista = data;
  if (data is Map) lista = data[chave];
  if (lista is! List) return [];
  return lista.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

String protocoloDe(dynamic json, {String padrao = ''}) {
  if (json is Map && json['protocolo'] != null) return json['protocolo'].toString();
  return padrao;
}

/// Mensagem amigável para erros (inclusive 422 do FastAPI)
String mensagemErro(http.Response r, {String prefixo = 'Erro'}) {
  final json = decodificar(r);
  final detalhes = json is Map ? json['detail'] : null;
  if (detalhes is List) {
    final campos = detalhes.map((d) {
      final loc = d is Map ? d['loc'] : null;
      final campo = (loc is List && loc.isNotEmpty) ? loc.last.toString() : '?';
      final msg = d is Map ? (d['msg'] ?? '').toString() : '';
      return '$campo ($msg)';
    }).join(', ');
    return '$prefixo (${r.statusCode}): $campos';
  }
  if (detalhes != null) return '$prefixo (${r.statusCode}): $detalhes';
  return '$prefixo (${r.statusCode})';
}

// =====================================================
// TEXTO / DATAS
// =====================================================
const String _comAcento = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
const String _semAcentoMap = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';

String semAcento(String s) {
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = _comAcento.indexOf(ch);
    b.write(i >= 0 ? _semAcentoMap.substring(i, i + 1) : ch);
  }
  return b.toString();
}

bool contemTexto(dynamic campo, String termo) {
  if (termo.trim().isEmpty) return true;
  return semAcento((campo ?? '').toString()).toLowerCase().contains(semAcento(termo).toLowerCase().trim());
}

String p2(int v) => v.toString().padLeft(2, '0');

String dataIsoDe(DateTime d) => '${d.year}-${p2(d.month)}-${p2(d.day)}';
String dataBrDe(DateTime d) => '${p2(d.day)}/${p2(d.month)}/${d.year}';
String horaAgora() {
  final n = DateTime.now();
  return '${p2(n.hour)}:${p2(n.minute)}';
}

/// "2026-10-15 10:20" ou "2026-10-15T..." ou "15/10/2026" -> "2026-10-15"
String soDataIso(dynamic v) {
  final s = (v ?? '').toString().trim();
  if (s.isEmpty) return '';
  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
  if (iso != null) return '${iso.group(1)}-${iso.group(2)}-${iso.group(3)}';
  final br = RegExp(r'^(\d{2})/(\d{2})/(\d{4})').firstMatch(s);
  if (br != null) return '${br.group(3)}-${br.group(2)}-${br.group(1)}';
  return s.split(RegExp(r'[ T]')).first;
}

/// Qualquer formato -> "DD/MM/AAAA"
String dataBr(dynamic v) {
  final iso = soDataIso(v);
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(iso);
  if (m == null) return iso.isEmpty ? '-' : iso;
  return '${m.group(3)}/${m.group(2)}/${m.group(1)}';
}

/// respostas_dict pode vir como Map ou como String JSON
Map<String, dynamic> respostasDe(dynamic v) {
  if (v is Map) return Map<String, dynamic>.from(v);
  if (v is String && v.trim().isNotEmpty) {
    try {
      final j = jsonDecode(v);
      if (j is Map) return Map<String, dynamic>.from(j);
    } catch (_) {}
  }
  return {};
}

// =====================================================
// DIÁLOGOS / AVISOS
// =====================================================
void avisar(BuildContext context, String msg, {bool erro = true}) {
  final sm = ScaffoldMessenger.of(context);
  sm.hideCurrentSnackBar();
  sm.showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: erro ? Colors.red.shade700 : Colors.green.shade700,
    duration: const Duration(seconds: 4),
  ));
}

Future<bool> confirmar(BuildContext context, String titulo, String mensagem,
    {String ok = 'Confirmar', Color corOk = Colors.red}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(mensagem),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ok, style: TextStyle(color: corOk, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
  return r ?? false;
}

Future<DateTime?> escolherData(BuildContext context, DateTime inicial) {
  return showDatePicker(
    context: context,
    initialDate: inicial,
    firstDate: DateTime(2020),
    lastDate: DateTime.now(),
  );
}

// =====================================================
// WIDGETS DE FORMULÁRIO
// =====================================================
InputDecoration decoracao(String label, {String? hint, Widget? sufixo}) => InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
      alignLabelWithHint: true,
      suffixIcon: sufixo,
    );

class CampoSomenteLeitura extends StatelessWidget {
  final String label;
  final String valor;
  const CampoSomenteLeitura({super.key, required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: decoracao(label).copyWith(filled: true, fillColor: Colors.grey.shade100),
      child: Text(valor.isEmpty ? '-' : valor, style: TextStyle(color: Colors.grey.shade700)),
    );
  }
}

class CampoData extends StatelessWidget {
  final String label;
  final DateTime valor;
  final ValueChanged<DateTime> onChanged;
  const CampoData({super.key, required this.label, required this.valor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final d = await escolherData(context, valor);
        if (d != null) onChanged(d);
      },
      child: InputDecorator(
        decoration: decoracao(label, sufixo: const Icon(Icons.calendar_month)),
        child: Text(dataBrDe(valor), style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

class CampoDropdown extends StatelessWidget {
  final String label;
  final List<String> opcoes;
  final String? valor;
  final ValueChanged<String?>? onChanged;
  final String? hint;
  const CampoDropdown({
    super.key,
    required this.label,
    required this.opcoes,
    required this.valor,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      decoration: decoracao(label),
      value: opcoes.contains(valor) ? valor : null,
      isExpanded: true,
      hint: hint == null ? null : Text(hint!),
      items: opcoes
          .map((o) => DropdownMenuItem<String>(value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

/// Busca de pessoa com autocomplete. Só aceita nome que exista na lista.
/// Use uma Key nova para limpar o campo (ex.: depois de salvar ou trocar a UNB).
class CampoBuscaPessoa extends StatelessWidget {
  final String label;
  final List<String> opcoes;
  final bool carregando;
  final ValueChanged<String?> onChanged;
  const CampoBuscaPessoa({
    super.key,
    required this.label,
    required this.opcoes,
    required this.onChanged,
    this.carregando = false,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (v) {
        if (v.text.isEmpty) return opcoes.take(20);
        return opcoes.where((o) => contemTexto(o, v.text));
      },
      onSelected: (s) => onChanged(s),
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          onChanged: (t) {
            final txt = t.trim();
            onChanged(opcoes.contains(txt) ? txt : null);
          },
          decoration: decoracao(
            label,
            hint: carregando ? 'Carregando...' : (opcoes.isEmpty ? 'Nenhum nome disponível' : 'Digite para buscar...'),
            sufixo: carregando
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : const Icon(Icons.search),
          ),
        );
      },
    );
  }
}

/// Pergunta com 2 opções (OK/NOK ou CONFORME/NÃO CONFORME)
class PerguntaBinaria extends StatelessWidget {
  final int numero;
  final String pergunta;
  final String? categoria;
  final String? valor;
  final String opcaoBoa;
  final String opcaoRuim;
  final bool destacarFalta;
  final ValueChanged<String> onChanged;

  const PerguntaBinaria({
    super.key,
    required this.numero,
    required this.pergunta,
    required this.valor,
    required this.onChanged,
    this.categoria,
    this.opcaoBoa = 'OK',
    this.opcaoRuim = 'NOK',
    this.destacarFalta = false,
  });

  @override
  Widget build(BuildContext context) {
    final faltando = destacarFalta && valor == null;

    Widget botao(String op, Color cor) {
      final sel = valor == op;
      return Expanded(
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: sel ? cor.withOpacity(0.12) : Colors.white,
            side: BorderSide(color: sel ? cor : Colors.grey.shade300, width: sel ? 2 : 1),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onPressed: () => onChanged(op),
          child: Text(op,
              textAlign: TextAlign.center,
              style: TextStyle(color: sel ? cor : Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: valor == opcaoRuim ? const Color(0xFFFEF2F2) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: faltando ? Colors.red : const Color(0xFFE2E8F0), width: faltando ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (categoria != null && categoria!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(categoria!,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
            ),
          Text('$numero. $pergunta', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(children: [
            botao(opcaoBoa, const Color(0xFF10B981)),
            const SizedBox(width: 10),
            botao(opcaoRuim, const Color(0xFFEF4444)),
          ]),
        ],
      ),
    );
  }
}

/// Lista de respostas de um registro: [OK] 1. Pergunta
class ListaRespostas extends StatelessWidget {
  final Map<String, dynamic> respostas;
  final bool Function(String resposta) ehRuim;
  const ListaRespostas({super.key, required this.respostas, required this.ehRuim});

  @override
  Widget build(BuildContext context) {
    if (respostas.isEmpty) {
      return const Text('Nenhuma resposta de checklist registrada.', style: TextStyle(color: Colors.grey));
    }
    final linhas = <Widget>[];
    var i = 0;
    for (final e in respostas.entries) {
      i++;
      final r = (e.value ?? '').toString();
      final ruim = ehRuim(r);
      linhas.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 44),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: ruim ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(r.isEmpty ? '-' : r,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: ruim ? const Color(0xFFEF4444) : const Color(0xFF10B981))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('$i. ${e.key}',
                  style: TextStyle(fontSize: 13, color: ruim ? const Color(0xFFB91C1C) : const Color(0xFF334155))),
            ),
          ],
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: linhas);
  }
}

class CaixaObservacao extends StatelessWidget {
  final String texto;
  const CaixaObservacao(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Observação:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
        const SizedBox(height: 4),
        Text(texto, style: const TextStyle(fontSize: 13, color: Color(0xFF92400E))),
      ]),
    );
  }
}

class Etiqueta extends StatelessWidget {
  final String texto;
  final Color cor;
  const Etiqueta(this.texto, {super.key, this.cor = const Color(0xFF475569)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: cor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
      child: Text(texto, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cor)),
    );
  }
}

class EstadoVazio extends StatelessWidget {
  final String texto;
  final IconData icone;
  const EstadoVazio(this.texto, {super.key, this.icone = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    // ListView para o "puxar para atualizar" funcionar mesmo com a lista vazia
    return ListView(
      children: [
        const SizedBox(height: 80),
        Icon(icone, size: 48, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Center(child: Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey))),
      ],
    );
  }
}

/// Faixa de aviso verde/vermelha usada nas abas de consulta
class FaixaInfo extends StatelessWidget {
  final String texto;
  final IconData icone;
  final Color cor;
  const FaixaInfo(this.texto, {super.key, this.icone = Icons.info_outline, this.cor = const Color(0xFF0369A1)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cor.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(icone, color: cor, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(texto, style: TextStyle(color: cor, fontSize: 13))),
      ]),
    );
  }
}

// =====================================================
// DASHBOARD: KPI, barras, linha, pizza
// =====================================================
class KpiCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final Color cor;
  const KpiCard({super.key, required this.titulo, required this.valor, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 4, color: cor),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titulo.toUpperCase(),
                    maxLines: 2,
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                Text(valor, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class GradeKpis extends StatelessWidget {
  final List<KpiCard> kpis;
  const GradeKpis(this.kpis, {super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final largura = (c.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: kpis.map((k) => SizedBox(width: largura, child: k)).toList(),
      );
    });
  }
}

class CartaoGrafico extends StatelessWidget {
  final String titulo;
  final Widget child;
  const CartaoGrafico({super.key, required this.titulo, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

class ItemBarra {
  final String rotulo;
  final double valor;
  final Color? cor;
  final String? texto; // texto à direita (ex.: "95.0%")
  const ItemBarra(this.rotulo, this.valor, {this.cor, this.texto});
}

/// Barras horizontais (melhor leitura no celular para nomes longos)
class BarrasHorizontais extends StatelessWidget {
  final List<ItemBarra> itens;
  final Color cor;
  final double? maximo;
  const BarrasHorizontais({super.key, required this.itens, this.cor = const Color(0xFF3B82F6), this.maximo});

  @override
  Widget build(BuildContext context) {
    if (itens.isEmpty) return const Text('Sem dados.', style: TextStyle(color: Colors.grey));
    final maxV = maximo ?? itens.map((e) => e.valor).fold<double>(0, (a, b) => b > a ? b : a);
    return Column(
      children: itens.map((it) {
        final frac = maxV <= 0 ? 0.0 : (it.valor / maxV).clamp(0.0, 1.0).toDouble();
        final inteiro = it.valor == it.valor.roundToDouble();
        final valorTxt = it.texto ?? (inteiro ? it.valor.toInt().toString() : it.valor.toStringAsFixed(1));
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(it.rotulo, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
              ),
              const SizedBox(width: 8),
              Text(valorTxt, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 8,
                backgroundColor: const Color(0xFFF1F5F9),
                valueColor: AlwaysStoppedAnimation<Color>(it.cor ?? cor),
              ),
            ),
          ]),
        );
      }).toList(),
    );
  }
}

/// Top N de uma contagem {nome: qtd}, do maior para o menor
List<ItemBarra> topContagem(Map<String, int> contagem, {int n = 10}) {
  final lista = contagem.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return lista.take(n).map((e) => ItemBarra(e.key, e.value.toDouble())).toList();
}

Map<String, int> contar(Iterable<Map<String, dynamic>> registros, String campo) {
  final m = <String, int>{};
  for (final r in registros) {
    final v = (r[campo] ?? '').toString().trim();
    final k = v.isEmpty ? 'NÃO INFORMADO' : v;
    m[k] = (m[k] ?? 0) + 1;
  }
  return m;
}

/// Linha do tempo: {AAAA-MM-DD: valor}. Mostra os últimos [ultimos] dias com registro.
class GraficoLinhaTempo extends StatelessWidget {
  final Map<String, double> porData;
  final Color cor;
  final int ultimos;
  final double? maxY;
  const GraficoLinhaTempo({
    super.key,
    required this.porData,
    this.cor = const Color(0xFF10B981),
    this.ultimos = 15,
    this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    var datas = porData.keys.where((d) => d.isNotEmpty).toList()..sort();
    if (datas.isEmpty) return const Text('Sem dados.', style: TextStyle(color: Colors.grey));
    if (datas.length > ultimos) datas = datas.sublist(datas.length - ultimos);

    final spots = <FlSpot>[];
    for (var i = 0; i < datas.length; i++) {
      spots.add(FlSpot(i.toDouble(), porData[datas.elementAt(i)] ?? 0.0));
    }
    if (spots.length == 1) spots.add(FlSpot(1, spots.first.y));

    final passo = datas.length <= 6 ? 1 : (datas.length / 5).ceil();

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= datas.length || i % passo != 0) return const SizedBox.shrink();
                  final partes = datas.elementAt(i).split('-');
                  final rot = partes.length == 3 ? '${partes.last}/${partes.elementAt(1)}' : datas.elementAt(i);
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(rot, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: cor,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: cor.withOpacity(0.15)),
            ),
          ],
        ),
      ),
    );
  }
}

const List<Color> kPaleta = [
  Color(0xFF3B82F6),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
  Color(0xFF8B5CF6),
  Color(0xFF06B6D4),
  Color(0xFFEC4899),
];

class GraficoPizza extends StatelessWidget {
  final Map<String, int> contagem;
  const GraficoPizza({super.key, required this.contagem});

  @override
  Widget build(BuildContext context) {
    final itens = contagem.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    if (itens.isEmpty) return const Text('Sem dados.', style: TextStyle(color: Colors.grey));
    final total = itens.fold<int>(0, (a, b) => a + b.value);

    final secoes = <PieChartSectionData>[];
    for (var i = 0; i < itens.length; i++) {
      secoes.add(PieChartSectionData(
        color: kPaleta.elementAt(i % kPaleta.length),
        value: itens.elementAt(i).value.toDouble(),
        title: '',
        radius: 28,
      ));
    }

    return Column(children: [
      SizedBox(
        height: 170,
        child: PieChart(PieChartData(sectionsSpace: 2, centerSpaceRadius: 45, sections: secoes)),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 6,
        children: List.generate(itens.length, (i) {
          final e = itens.elementAt(i);
          final double pct = total == 0 ? 0.0 : e.value * 100 / total;
          return Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, color: kPaleta.elementAt(i % kPaleta.length)),
            const SizedBox(width: 4),
            Text('${e.key}: ${e.value} (${pct.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 12)),
          ]);
        }),
      ),
    ]);
  }
}

// =====================================================
// FOTO DE PERFIL (mesmas fotos da web: /fotos_perfil/NOME.jpg)
// O backend precisa servir a pasta em /fotos_perfil (ver main.py).
// =====================================================
// Rota do backend que acha a foto ignorando acento/maiúscula/extensão (rota_perfil_fotos.py)
String urlFoto(String nome) => '${Api.baseUrl}/api/foto?nome=${Uri.encodeQueryComponent(nome.trim())}';

// Versão exibida no Perfil (manter igual ao pubspec.yaml)
const String kVersaoApp = '1.0.2';

String iniciaisDe(String nome) {
  final partes = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (partes.isEmpty) return '?';
  if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
  return (partes.first.substring(0, 1) + partes.last.substring(0, 1)).toUpperCase();
}

class FotoPerfil extends StatelessWidget {
  final String nome;
  final double raio;
  const FotoPerfil({super.key, required this.nome, this.raio = 20});

  Widget _iniciais() => Container(
        color: const Color(0xFF2563EB),
        alignment: Alignment.center,
        child: Text(iniciaisDe(nome),
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: raio * 0.7)),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: raio * 2,
      height: raio * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipOval(
        child: nome.trim().isEmpty
            ? _iniciais()
            : Image.network(
                urlFoto(nome),
                fit: BoxFit.cover,
                width: raio * 2,
                height: raio * 2,
                // Sem foto (404) ou servidor fora: mostra as iniciais
                errorBuilder: (_, __, ___) => _iniciais(),
                loadingBuilder: (ctx, child, progresso) => progresso == null ? child : _iniciais(),
              ),
      ),
    );
  }
}

// =====================================================
// TELAS DE BLOQUEIO / ERRO DOS MÓDULOS
// =====================================================
class TelaSemAcesso extends StatelessWidget {
  final String titulo;
  final String mensagem;
  const TelaSemAcesso({super.key, required this.titulo, required this.mensagem});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_outline, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(mensagem, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, height: 1.4)),
          ]),
        ),
      ),
    );
  }
}

class TelaErro extends StatelessWidget {
  final String titulo;
  final String mensagem;
  final VoidCallback onTentarDeNovo;
  const TelaErro({super.key, required this.titulo, required this.mensagem, required this.onTentarDeNovo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.wifi_off, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(mensagem, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: onTentarDeNovo, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
          ]),
        ),
      ),
    );
  }
}

/// Cabeçalho de um registro na consulta (card expansível)
class CardRegistro extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final Widget? etiqueta;
  final List<Widget> detalhes;
  final VoidCallback? onExcluir;
  final Color cor;
  final String? fotoNome; // se informado, mostra a foto da pessoa no lugar do ícone

  const CardRegistro({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.detalhes,
    this.etiqueta,
    this.onExcluir,
    this.cor = const Color(0xFF2563EB),
    this.fotoNome,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: fotoNome != null
            ? FotoPerfil(nome: fotoNome!, raio: 20)
            : CircleAvatar(
                backgroundColor: cor.withOpacity(0.12),
                child: Icon(Icons.assignment_turned_in, color: cor, size: 20),
              ),
        title: Row(children: [
          Expanded(
            child: Text(titulo,
                style: TextStyle(fontWeight: FontWeight.bold, color: cor, fontSize: 14), overflow: TextOverflow.ellipsis),
          ),
          if (etiqueta != null) etiqueta!,
        ]),
        subtitle: Text(subtitulo, style: const TextStyle(fontSize: 12.5)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...detalhes,
          if (onExcluir != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onExcluir,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('Excluir registro', style: TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Linha "Rótulo: valor" nos detalhes
class LinhaDetalhe extends StatelessWidget {
  final String label;
  final dynamic valor;
  const LinhaDetalhe(this.label, this.valor, {super.key});

  @override
  Widget build(BuildContext context) {
    final v = (valor ?? '').toString().trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(style: const TextStyle(color: Colors.black87, fontSize: 13), children: [
          TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: v.isEmpty ? '-' : v),
        ]),
      ),
    );
  }
}

/// Campo de busca padrão das consultas
class CampoBuscaTexto extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const CampoBuscaTexto({super.key, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

/// Seletor compacto (chip com menu) para filtros
class FiltroMenu extends StatelessWidget {
  final String rotulo;
  final String valor; // '' = todos
  final List<String> opcoes;
  final ValueChanged<String> onChanged;
  const FiltroMenu({super.key, required this.rotulo, required this.valor, required this.opcoes, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: '', child: Text('Todos')),
        ...opcoes.map((o) => PopupMenuItem(value: o, child: Text(o))),
      ],
      child: Chip(
        avatar: Icon(Icons.filter_list, size: 16, color: valor.isEmpty ? Colors.grey : const Color(0xFF2563EB)),
        label: Text(valor.isEmpty ? rotulo : '$rotulo: $valor', style: const TextStyle(fontSize: 12)),
        backgroundColor: valor.isEmpty ? Colors.grey.shade100 : const Color(0xFFDBEAFE),
        side: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }
}

/// Filtro de período (data inicial/final) em chip
class FiltroPeriodo extends StatelessWidget {
  final DateTimeRange? periodo;
  final ValueChanged<DateTimeRange?> onChanged;
  const FiltroPeriodo({super.key, required this.periodo, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final txt = periodo == null
        ? 'Período'
        : '${dataBrDe(periodo!.start).substring(0, 5)} a ${dataBrDe(periodo!.end).substring(0, 5)}';
    return InputChip(
      avatar: Icon(Icons.date_range, size: 16, color: periodo == null ? Colors.grey : const Color(0xFF2563EB)),
      label: Text(txt, style: const TextStyle(fontSize: 12)),
      backgroundColor: periodo == null ? Colors.grey.shade100 : const Color(0xFFDBEAFE),
      side: BorderSide(color: Colors.grey.shade300),
      onPressed: () async {
        final r = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          initialDateRange: periodo,
        );
        if (r != null) onChanged(r);
      },
      onDeleted: periodo == null ? null : () => onChanged(null),
    );
  }
}

bool dentroDoPeriodo(dynamic data, DateTimeRange? periodo) {
  if (periodo == null) return true;
  final iso = soDataIso(data);
  if (iso.isEmpty) return false;
  return iso.compareTo(dataIsoDe(periodo.start)) >= 0 && iso.compareTo(dataIsoDe(periodo.end)) <= 0;
}
