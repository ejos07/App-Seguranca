import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api.dart';
import '../theme/app_theme.dart';

export '../theme/app_theme.dart'; // quem importa comum.dart já recebe AppCores, AppEspaco...

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
InputDecoration decoracao(String label, {String? hint, Widget? sufixo, IconData? prefixo}) => InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: true,
      suffixIcon: sufixo,
      prefixIcon: prefixo == null ? null : Icon(prefixo),
    );

class CampoSomenteLeitura extends StatelessWidget {
  final String label;
  final String valor;
  final IconData? icone;
  const CampoSomenteLeitura({super.key, required this.label, required this.valor, this.icone});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: decoracao(label, prefixo: icone ?? Icons.lock_outline)
          .copyWith(filled: true, fillColor: AppCores.superficieSuave),
      child: Text(valor.isEmpty ? '-' : valor,
          style: TextStyle(color: AppCores.textoSecundario, fontWeight: FontWeight.w500)),
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
      borderRadius: BorderRadius.circular(AppRaio.m),
      onTap: () async {
        final d = await escolherData(context, valor);
        if (d != null) onChanged(d);
      },
      child: InputDecorator(
        decoration: decoracao(label, prefixo: Icons.event_outlined, sufixo: const Icon(Icons.expand_more)),
        child: Text(dataBrDe(valor), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
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
  final IconData? icone;
  const CampoDropdown({
    super.key,
    required this.label,
    required this.opcoes,
    required this.valor,
    required this.onChanged,
    this.hint,
    this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      decoration: decoracao(label, prefixo: icone),
      value: opcoes.contains(valor) ? valor : null,
      isExpanded: true,
      borderRadius: BorderRadius.circular(AppRaio.m),
      icon: const Icon(Icons.expand_more),
      hint: hint == null ? null : Text(hint!),
      items: opcoes
          .map((o) => DropdownMenuItem<String>(value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

/// Busca de pessoa com autocomplete (mostra a foto). Só aceita nome que exista na lista.
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
      optionsViewBuilder: (context, aoEscolher, opcoesFiltradas) {
        final lista = opcoesFiltradas.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            color: AppCores.superficie,
            borderRadius: BorderRadius.circular(AppRaio.m),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: AppEspaco.xs),
                shrinkWrap: true,
                itemCount: lista.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 60),
                itemBuilder: (_, i) {
                  final nome = lista.elementAt(i);
                  final ehNome = !nome.toUpperCase().startsWith('NÃO SE APLICA');
                  return ListTile(
                    dense: true,
                    leading: ehNome
                        ? FotoPerfil(nome: nome, raio: 16)
                        : Icon(Icons.do_not_disturb_alt_outlined, color: AppCores.textoSuave),
                    title: Text(nome, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                    onTap: () => aoEscolher(nome),
                  );
                },
              ),
            ),
          ),
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.characters,
          onChanged: (t) {
            final txt = t.trim();
            onChanged(opcoes.contains(txt) ? txt : null);
          },
          decoration: decoracao(
            label,
            prefixo: Icons.person_search_outlined,
            hint: carregando ? 'Carregando...' : (opcoes.isEmpty ? 'Nenhum nome disponível' : 'Digite para buscar...'),
            sufixo: carregando
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : null,
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
    final ruim = valor == opcaoRuim;
    final bom = valor == opcaoBoa;

    Widget botao(String op, Color cor, IconData icone) {
      final sel = valor == op;
      return Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: sel ? cor : AppCores.superficie,
            borderRadius: BorderRadius.circular(AppRaio.m),
            border: Border.all(color: sel ? cor : AppCores.borda, width: 1.4),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRaio.m),
              onTap: () => onChanged(op),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icone, size: 18, color: sel ? Colors.white : cor),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(op,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: sel ? Colors.white : AppCores.texto, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: AppEspaco.m - 2),
      padding: const EdgeInsets.all(AppEspaco.m + 2),
      decoration: BoxDecoration(
        color: ruim ? AppCores.tinta(AppCores.perigo, 0.06) : AppCores.superficie,
        borderRadius: BorderRadius.circular(AppRaio.l),
        border: Border.all(
          color: faltando ? AppCores.perigo : (ruim ? AppCores.perigo.withOpacity(0.35) : AppCores.borda),
          width: faltando ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bom
                    ? AppCores.sucesso
                    : (ruim ? AppCores.perigo : (faltando ? AppCores.perigo.withOpacity(0.12) : AppCores.fundo)),
                shape: BoxShape.circle,
              ),
              child: bom || ruim
                  ? Icon(bom ? Icons.check : Icons.close, size: 15, color: Colors.white)
                  : Text('$numero',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: faltando ? AppCores.perigo : AppCores.textoSecundario)),
            ),
            const SizedBox(width: AppEspaco.m - 2),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (categoria != null && categoria!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(categoria!.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 10.5, fontWeight: FontWeight.w800, color: AppCores.primaria, letterSpacing: 0.4)),
                  ),
                Text(pergunta, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.35)),
              ]),
            ),
          ]),
          const SizedBox(height: AppEspaco.m),
          Row(children: [
            botao(opcaoBoa, AppCores.sucesso, Icons.thumb_up_alt_outlined),
            const SizedBox(width: AppEspaco.s + 2),
            botao(opcaoRuim, AppCores.perigo, Icons.thumb_down_alt_outlined),
          ]),
          if (faltando)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Responda esta pergunta', style: TextStyle(fontSize: 12, color: AppCores.perigo)),
            ),
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
      return Text('Nenhuma resposta de checklist registrada.', style: AppTexto.legenda);
    }
    final linhas = <Widget>[];
    var i = 0;
    for (final e in respostas.entries) {
      i++;
      final r = (e.value ?? '').toString();
      final ruim = ehRuim(r);
      linhas.add(Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: ruim ? AppCores.tinta(AppCores.perigo, 0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRaio.s),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(ruim ? Icons.cancel : Icons.check_circle,
                size: 18, color: ruim ? AppCores.perigo : AppCores.sucesso),
            const SizedBox(width: AppEspaco.s + 2),
            Expanded(
              child: Text('$i. ${e.key}',
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: ruim ? FontWeight.w600 : FontWeight.w400,
                      color: ruim ? AppCores.legivel(const Color(0xFFB91C1C)) : AppCores.texto)),
            ),
            if (r.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(r,
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: ruim ? AppCores.perigo : AppCores.sucesso)),
            ],
          ],
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: linhas);
  }
}

class CaixaObservacao extends StatelessWidget {
  final String texto;
  final String titulo;
  const CaixaObservacao(this.texto, {super.key, this.titulo = 'Observação'});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppEspaco.m),
      decoration: BoxDecoration(
        color: AppCores.tinta(AppCores.alerta, 0.08),
        borderRadius: BorderRadius.circular(AppRaio.m),
        border: Border.all(color: AppCores.alerta.withOpacity(0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.sticky_note_2_outlined, size: 18, color: AppCores.legivel(const Color(0xFFB45309))),
        const SizedBox(width: AppEspaco.s),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppCores.legivel(const Color(0xFFB45309)))),
            const SizedBox(height: 2),
            Text(texto, style: TextStyle(fontSize: 13, color: AppCores.legivel(const Color(0xFF92400E)), height: 1.35)),
          ]),
        ),
      ]),
    );
  }
}

class Etiqueta extends StatelessWidget {
  final String texto;
  final Color cor;
  final IconData? icone;
  const Etiqueta(this.texto, {super.key, this.cor = const Color(0xFF475569), this.icone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppCores.tinta(cor), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icone != null) ...[Icon(icone, size: 12, color: AppCores.legivel(cor)), const SizedBox(width: 3)],
        Text(texto, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppCores.legivel(cor))),
      ]),
    );
  }
}

class EstadoVazio extends StatelessWidget {
  final String texto;
  final IconData icone;
  final String? subtitulo;
  final String? rotuloAcao;
  final VoidCallback? onAcao;
  const EstadoVazio(this.texto,
      {super.key, this.icone = Icons.inbox_outlined, this.subtitulo, this.rotuloAcao, this.onAcao});

  @override
  Widget build(BuildContext context) {
    // ListView para o "puxar para atualizar" funcionar mesmo com a lista vazia
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppEspaco.xxl),
      children: [
        const SizedBox(height: 72),
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(color: AppCores.primaria.withOpacity(0.08), shape: BoxShape.circle),
            child: Icon(icone, size: 40, color: AppCores.primaria.withOpacity(0.7)),
          ),
        ),
        const SizedBox(height: AppEspaco.l),
        Text(texto, textAlign: TextAlign.center, style: AppTexto.tituloCard),
        if (subtitulo != null) ...[
          const SizedBox(height: AppEspaco.xs),
          Text(subtitulo!, textAlign: TextAlign.center, style: AppTexto.legenda),
        ],
        if (onAcao != null) ...[
          const SizedBox(height: AppEspaco.l),
          Center(
            child: OutlinedButton.icon(
              onPressed: onAcao,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(rotuloAcao ?? 'Tentar novamente'),
            ),
          ),
        ],
      ],
    );
  }
}

/// Lista "esqueleto" exibida enquanto carrega (sem pacote extra)
class ListaCarregando extends StatefulWidget {
  final int itens;
  const ListaCarregando({super.key, this.itens = 6});

  @override
  State<ListaCarregando> createState() => _ListaCarregandoState();
}

class _ListaCarregandoState extends State<ListaCarregando> with SingleTickerProviderStateMixin {
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Widget _barra(double largura, double altura) => Container(
        width: largura,
        height: altura,
        decoration: BoxDecoration(color: AppCores.borda, borderRadius: BorderRadius.circular(6)),
      );

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_anim),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppEspaco.m),
        itemCount: widget.itens,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: AppEspaco.m),
          padding: const EdgeInsets.all(AppEspaco.l),
          decoration: BoxDecoration(
            color: AppCores.superficie,
            borderRadius: BorderRadius.circular(AppRaio.l),
            border: Border.all(color: AppCores.borda),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppCores.borda, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppEspaco.m),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _barra(140, 12),
                const SizedBox(height: 8),
                _barra(double.infinity, 10),
                const SizedBox(height: 6),
                _barra(180, 10),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Seção de formulário: card branco com título, subtítulo e conteúdo
class SecaoForm extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final IconData? icone;
  final Widget child;
  const SecaoForm({super.key, required this.titulo, required this.child, this.subtitulo, this.icone});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppEspaco.l),
      padding: const EdgeInsets.all(AppEspaco.l),
      decoration: BoxDecoration(
        color: AppCores.superficie,
        borderRadius: BorderRadius.circular(AppRaio.l),
        border: Border.all(color: AppCores.borda),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (icone != null) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppCores.primaria.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRaio.s),
              ),
              child: Icon(icone, size: 18, color: AppCores.primaria),
            ),
            const SizedBox(width: AppEspaco.s + 2),
          ],
          Expanded(child: Text(titulo, style: AppTexto.tituloCard)),
        ]),
        if (subtitulo != null) ...[
          const SizedBox(height: AppEspaco.xs),
          Text(subtitulo!, style: AppTexto.legenda),
        ],
        const SizedBox(height: AppEspaco.l),
        child,
      ]),
    );
  }
}

/// Barra fixa no rodapé com o botão principal (Salvar)
class BarraAcaoInferior extends StatelessWidget {
  final String rotulo;
  final IconData icone;
  final bool carregando;
  final String rotuloCarregando;
  final VoidCallback? onPressed;
  final Widget? topo; // ex.: barra de progresso do checklist

  const BarraAcaoInferior({
    super.key,
    required this.rotulo,
    required this.onPressed,
    this.icone = Icons.check_circle_outline,
    this.carregando = false,
    this.rotuloCarregando = 'Salvando...',
    this.topo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppCores.superficie,
        border: Border(top: BorderSide(color: AppCores.borda)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppEspaco.l, AppEspaco.m, AppEspaco.l, AppEspaco.m),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (topo != null) ...[topo!, const SizedBox(height: AppEspaco.m)],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: carregando ? null : onPressed,
                icon: carregando
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(icone),
                label: Text(carregando ? rotuloCarregando : rotulo),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Progresso do checklist: "12/39 respondidas" + barra
class ProgressoChecklist extends StatelessWidget {
  final int respondidas;
  final int total;
  final int ruins;
  final String rotuloRuim;
  final String sufixo;
  const ProgressoChecklist({
    super.key,
    required this.respondidas,
    required this.total,
    this.ruins = 0,
    this.rotuloRuim = 'NOK',
    this.sufixo = 'respondidas',
  });

  @override
  Widget build(BuildContext context) {
    final frac = total == 0 ? 0.0 : respondidas / total;
    final completo = respondidas == total && total > 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(completo ? Icons.task_alt : Icons.checklist_rtl,
            size: 18, color: completo ? AppCores.sucesso : AppCores.textoSecundario),
        const SizedBox(width: 6),
        Text('$respondidas de $total $sufixo',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: completo ? AppCores.sucesso : AppCores.textoSecundario)),
        const Spacer(),
        if (ruins > 0) Etiqueta('$ruins $rotuloRuim', cor: AppCores.perigo),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: frac),
          duration: const Duration(milliseconds: 300),
          builder: (_, v, __) => LinearProgressIndicator(
            value: v,
            minHeight: 6,
            backgroundColor: AppCores.borda,
            valueColor: AlwaysStoppedAnimation<Color>(completo ? AppCores.sucesso : AppCores.primaria),
          ),
        ),
      ),
    ]);
  }
}

/// Escolha entre poucas opções em "cartões" (ex.: identificar-se / anônimo)
class OpcaoCartao<T> {
  final T valor;
  final String titulo;
  final String? subtitulo;
  final IconData icone;
  final Color cor;
  const OpcaoCartao({
    required this.valor,
    required this.titulo,
    required this.icone,
    this.subtitulo,
    this.cor = AppCores.primaria,
  });
}

class SeletorCartoes<T> extends StatelessWidget {
  final List<OpcaoCartao<T>> opcoes;
  final T? valor;
  final ValueChanged<T> onChanged;
  const SeletorCartoes({super.key, required this.opcoes, required this.valor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final itens = <Widget>[];
    for (var i = 0; i < opcoes.length; i++) {
      final o = opcoes.elementAt(i);
      final sel = o.valor == valor;
      if (i > 0) itens.add(const SizedBox(width: AppEspaco.s + 2));
      itens.add(Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: sel ? o.cor.withOpacity(0.08) : AppCores.superficie,
            borderRadius: BorderRadius.circular(AppRaio.m),
            border: Border.all(color: sel ? o.cor : AppCores.borda, width: sel ? 1.6 : 1),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRaio.m),
              onTap: () => onChanged(o.valor),
              child: Padding(
                padding: const EdgeInsets.all(AppEspaco.m),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(o.icone, size: 20, color: sel ? o.cor : AppCores.textoSecundario),
                    const Spacer(),
                    Icon(sel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        size: 18, color: sel ? o.cor : AppCores.textoSuave),
                  ]),
                  const SizedBox(height: AppEspaco.s),
                  Text(o.titulo,
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700, color: sel ? o.cor : AppCores.texto)),
                  if (o.subtitulo != null) ...[
                    const SizedBox(height: 2),
                    Text(o.subtitulo!,
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTexto.legenda.copyWith(fontSize: 11.5)),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ));
    }
    return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: itens));
  }
}

/// Rótulo pequeno acima de um grupo de campos
class RotuloCampo extends StatelessWidget {
  final String texto;
  const RotuloCampo(this.texto, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppEspaco.s),
        child: Text(texto, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppCores.texto)),
      );
}

/// Cabeçalho com gradiente da marca (usado no Login e na Home)
class CabecalhoMarca extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final BorderRadius? raio;
  const CabecalhoMarca({super.key, required this.child, this.padding = const EdgeInsets.all(AppEspaco.xl), this.raio});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: AppCores.gradienteMarca,
        borderRadius: raio ?? BorderRadius.circular(AppRaio.xl),
        boxShadow: [
          BoxShadow(color: AppCores.primariaEscura.withOpacity(0.25), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }
}

/// Barra de busca + filtros, padrão das telas de consulta
class BarraFiltros extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onBusca;
  final List<Widget> filtros;
  const BarraFiltros({super.key, required this.hint, required this.onBusca, this.filtros = const []});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppCores.superficie,
        border: Border(bottom: BorderSide(color: AppCores.borda)),
      ),
      padding: const EdgeInsets.fromLTRB(AppEspaco.m, AppEspaco.m, AppEspaco.m, AppEspaco.s),
      child: Column(children: [
        CampoBuscaTexto(hint: hint, onChanged: onBusca),
        if (filtros.isNotEmpty) ...[
          const SizedBox(height: AppEspaco.s),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in filtros) Padding(padding: const EdgeInsets.only(right: AppEspaco.s), child: f),
              ],
            ),
          ),
        ],
      ]),
    );
  }
}

/// Contador "N registros" acima das listas
class ContadorResultados extends StatelessWidget {
  final int total;
  final String singular;
  final String plural;
  const ContadorResultados(this.total, {super.key, this.singular = 'registro', this.plural = 'registros'});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppEspaco.l, AppEspaco.m, AppEspaco.l, 0),
        child: Text('$total ${total == 1 ? singular : plural}'.toUpperCase(), style: AppTexto.rotulo),
      );
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
        Icon(icone, color: AppCores.legivel(cor), size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(texto, style: TextStyle(color: AppCores.legivel(cor), fontSize: 13))),
      ]),
    );
  }
}

// =====================================================
// DASHBOARD: componentes visuais (funcionam no tema claro e escuro)
// =====================================================

/// Título de bloco dentro do dashboard
class TituloDash extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  const TituloDash(this.titulo, {super.key, this.subtitulo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, AppEspaco.xl, 2, AppEspaco.s),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo.toUpperCase(), style: AppTexto.rotulo),
        if (subtitulo != null) ...[
          const SizedBox(height: 2),
          Text(subtitulo!, style: AppTexto.legenda),
        ],
      ]),
    );
  }
}

/// Anel de progresso (0–100)
class AnelProgresso extends StatelessWidget {
  final double percentual;
  final double tamanho;
  final double espessura;
  final Color cor;
  final Color corFundo;
  final Widget? centro;
  const AnelProgresso({
    super.key,
    required this.percentual,
    this.tamanho = 92,
    this.espessura = 9,
    this.cor = Colors.white,
    this.corFundo = const Color(0x40FFFFFF),
    this.centro,
  });

  @override
  Widget build(BuildContext context) {
    final alvo = (percentual.isNaN ? 0.0 : percentual).clamp(0.0, 100.0).toDouble();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: alvo),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (ctx, v, _) => SizedBox(
        width: tamanho,
        height: tamanho,
        child: CustomPaint(
          painter: _PintorAnel(v / 100, cor, corFundo, espessura),
          child: Center(child: centro),
        ),
      ),
    );
  }
}

class _PintorAnel extends CustomPainter {
  final double fracao;
  final Color cor;
  final Color corFundo;
  final double espessura;
  _PintorAnel(this.fracao, this.cor, this.corFundo, this.espessura);

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);
    final raio = (size.shortestSide - espessura) / 2;
    final ret = Rect.fromCircle(center: centro, radius: raio);
    final fundo = Paint()
      ..color = corFundo
      ..style = PaintingStyle.stroke
      ..strokeWidth = espessura;
    canvas.drawCircle(centro, raio, fundo);
    if (fracao <= 0) return;
    final arco = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = espessura;
    canvas.drawArc(ret, -1.5708, 6.28318 * fracao, false, arco);
  }

  @override
  bool shouldRepaint(covariant _PintorAnel old) =>
      old.fracao != fracao || old.cor != cor || old.corFundo != corFundo;
}

/// Cartão principal do dashboard: índice em % + status + números rápidos
class PainelIndice extends StatelessWidget {
  final String titulo;
  final double percentual;
  final String status;
  final Color corStatus;
  final String? descricao;
  final List<(String, String)> numeros; // (valor, rótulo)
  final String? rotuloAcao;
  final VoidCallback? onAcao;
  final Gradient? gradiente;

  const PainelIndice({
    super.key,
    required this.titulo,
    required this.percentual,
    required this.status,
    required this.corStatus,
    this.descricao,
    this.numeros = const [],
    this.rotuloAcao,
    this.onAcao,
    this.gradiente,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppEspaco.l + 2),
      decoration: BoxDecoration(
        gradient: gradiente ?? AppCores.gradienteMarca,
        borderRadius: BorderRadius.circular(AppRaio.xl),
        boxShadow: AppCores.escuro
            ? null
            : [BoxShadow(color: AppCores.primariaEscura.withOpacity(0.25), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo,
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: AppEspaco.s),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: corStatus, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
              if (descricao != null) ...[
                const SizedBox(height: AppEspaco.s + 2),
                Text(descricao!,
                    style: TextStyle(color: Colors.white.withOpacity(0.78), fontSize: 12, height: 1.35)),
              ],
            ]),
          ),
          const SizedBox(width: AppEspaco.m),
          AnelProgresso(
            percentual: percentual,
            cor: corStatus,
            corFundo: Colors.white.withOpacity(0.18),
            centro: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${percentual.isNaN ? 0 : percentual.round()}%',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
        if (numeros.isNotEmpty) ...[
          const SizedBox(height: AppEspaco.l),
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppEspaco.m, horizontal: AppEspaco.s),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(AppRaio.m),
            ),
            child: Row(
              children: List.generate(numeros.length * 2 - 1, (i) {
                if (i.isOdd) {
                  return Container(width: 1, height: 28, color: Colors.white.withOpacity(0.18));
                }
                final (valor, rotulo) = numeros.elementAt(i ~/ 2);
                return Expanded(
                  child: Column(children: [
                    Text(valor,
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(rotulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 10.5)),
                  ]),
                );
              }),
            ),
          ),
        ],
        if (rotuloAcao != null && onAcao != null) ...[
          const SizedBox(height: AppEspaco.m),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withOpacity(0.12),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRaio.m)),
              ),
              onPressed: onAcao,
              icon: const Icon(Icons.insights_outlined, size: 18),
              label: Text(rotuloAcao!, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ]),
    );
  }
}

class KpiCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final Color cor;
  final IconData? icone;
  final String? subtitulo; // ex.: "32% do total"
  final double? fracao; // 0..1 -> mini barra de proporção
  const KpiCard({
    super.key,
    required this.titulo,
    required this.valor,
    required this.cor,
    this.icone,
    this.subtitulo,
    this.fracao,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppEspaco.m + 2),
      decoration: BoxDecoration(
        color: AppCores.superficie,
        borderRadius: BorderRadius.circular(AppRaio.l),
        border: Border.all(color: AppCores.borda),
        boxShadow: AppCores.sombra,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: AppCores.tinta(cor), borderRadius: BorderRadius.circular(AppRaio.s + 1)),
            child: Icon(icone ?? Icons.insights_outlined, size: 17, color: cor),
          ),
          const SizedBox(width: AppEspaco.s),
          Expanded(
            child: Text(titulo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: AppCores.textoSecundario, fontWeight: FontWeight.w600, height: 1.2)),
          ),
        ]),
        const SizedBox(height: AppEspaco.m),
        Text(valor, style: AppTexto.numeroGrande),
        if (subtitulo != null) ...[
          const SizedBox(height: 3),
          Text(subtitulo!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: cor, fontWeight: FontWeight.w600)),
        ],
        if (fracao != null) ...[
          const SizedBox(height: AppEspaco.s),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fracao!.clamp(0.0, 1.0).toDouble(),
              minHeight: 5,
              backgroundColor: AppCores.tinta(cor, 0.10),
              valueColor: AlwaysStoppedAnimation<Color>(cor),
            ),
          ),
        ],
      ]),
    );
  }
}

class GradeKpis extends StatelessWidget {
  final List<KpiCard> kpis;
  final int colunas;
  const GradeKpis(this.kpis, {super.key, this.colunas = 2});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final cols = c.maxWidth > 700 ? 4 : colunas;
      final largura = (c.maxWidth - AppEspaco.m * (cols - 1)) / cols;
      return Wrap(
        spacing: AppEspaco.m,
        runSpacing: AppEspaco.m,
        children: kpis.map((k) => SizedBox(width: largura, child: k)).toList(),
      );
    });
  }
}

class CartaoGrafico extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final IconData? icone;
  final Widget? acao;
  final Widget child;
  const CartaoGrafico({super.key, required this.titulo, required this.child, this.subtitulo, this.icone, this.acao});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppEspaco.m),
      padding: const EdgeInsets.all(AppEspaco.l),
      decoration: BoxDecoration(
        color: AppCores.superficie,
        borderRadius: BorderRadius.circular(AppRaio.l),
        border: Border.all(color: AppCores.borda),
        boxShadow: AppCores.sombra,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (icone != null) ...[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppCores.tinta(AppCores.primaria, 0.10),
                borderRadius: BorderRadius.circular(AppRaio.s),
              ),
              child: Icon(icone, size: 16, color: AppCores.primaria),
            ),
            const SizedBox(width: AppEspaco.s + 2),
          ],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: AppTexto.tituloCard),
              if (subtitulo != null) ...[
                const SizedBox(height: 2),
                Text(subtitulo!, style: AppTexto.legenda),
              ],
            ]),
          ),
          if (acao != null) acao!,
        ]),
        const SizedBox(height: AppEspaco.l),
        child,
      ]),
    );
  }
}

/// Faixa de destaque automático ("insight") no dashboard
class CartaoInsight extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String texto;
  final Color cor;
  const CartaoInsight({super.key, required this.icone, required this.titulo, required this.texto, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppEspaco.m),
      padding: const EdgeInsets.all(AppEspaco.m + 2),
      decoration: BoxDecoration(
        color: AppCores.tinta(cor, 0.07),
        borderRadius: BorderRadius.circular(AppRaio.m),
        border: Border.all(color: cor.withOpacity(0.30)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icone, color: cor, size: 22),
        const SizedBox(width: AppEspaco.m),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cor, letterSpacing: 0.3)),
            const SizedBox(height: 3),
            Text(texto, style: TextStyle(fontSize: 13, color: AppCores.texto, height: 1.35)),
          ]),
        ),
      ]),
    );
  }
}

/// Texto padrão de "sem dados" dentro dos cartões
class SemDadosGrafico extends StatelessWidget {
  final String texto;
  const SemDadosGrafico([this.texto = 'Sem dados no período.', Key? key]) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppEspaco.l),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.bar_chart_outlined, color: AppCores.textoSuave, size: 20),
        const SizedBox(width: AppEspaco.s),
        Text(texto, style: AppTexto.legenda),
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

/// Barras horizontais / ranking (melhor leitura no celular para nomes longos)
class BarrasHorizontais extends StatelessWidget {
  final List<ItemBarra> itens;
  final Color cor;
  final double? maximo;
  final bool ranking; // mostra posição 1, 2, 3...
  final String? sufixo; // ex.: 'ocorr.'
  const BarrasHorizontais({
    super.key,
    required this.itens,
    this.cor = const Color(0xFF3B82F6),
    this.maximo,
    this.ranking = true,
    this.sufixo,
  });

  @override
  Widget build(BuildContext context) {
    if (itens.isEmpty) return const SemDadosGrafico();
    final maxV = maximo ?? itens.map((e) => e.valor).fold<double>(0, (a, b) => b > a ? b : a);
    return Column(
      children: List.generate(itens.length, (i) {
        final it = itens.elementAt(i);
        final c = it.cor ?? cor;
        final frac = maxV <= 0 ? 0.0 : (it.valor / maxV).clamp(0.0, 1.0).toDouble();
        final inteiro = it.valor == it.valor.roundToDouble();
        final valorTxt = it.texto ??
            ((inteiro ? it.valor.toInt().toString() : it.valor.toStringAsFixed(1)) + (sufixo == null ? '' : ' $sufixo'));
        final destaque = ranking && i < 3;
        return Padding(
          padding: EdgeInsets.only(bottom: i == itens.length - 1 ? 0 : AppEspaco.m),
          child: Row(children: [
            if (ranking) ...[
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: destaque ? AppCores.tinta(c, 0.16) : AppCores.superficieSuave,
                  borderRadius: BorderRadius.circular(6),
                  border: destaque ? null : Border.all(color: AppCores.borda),
                ),
                child: Text('${i + 1}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: destaque ? c : AppCores.textoSecundario)),
              ),
              const SizedBox(width: AppEspaco.s + 2),
            ],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(it.rotulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: AppCores.texto, fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(width: AppEspaco.s),
                  Text(valorTxt, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: c)),
                ]),
                const SizedBox(height: 5),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: frac),
                  duration: Duration(milliseconds: 500 + i * 60),
                  curve: Curves.easeOutCubic,
                  builder: (ctx, v, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: v,
                      minHeight: 7,
                      backgroundColor: AppCores.tinta(c, 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(c),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        );
      }),
    );
  }
}

/// Top N de uma contagem {nome: qtd}, do maior para o menor
List<ItemBarra> topContagem(Map<String, int> contagem, {int n = 10, Color? cor}) {
  final lista = contagem.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return lista.take(n).map((e) => ItemBarra(e.key, e.value.toDouble(), cor: cor)).toList();
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

const List<String> _kMesesCurtos = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];

/// "2026-10" -> "out/26"
String rotuloMes(String anoMes) {
  final p = anoMes.split('-');
  if (p.length < 2) return anoMes;
  final m = int.tryParse(p.elementAt(1)) ?? 0;
  final a = p.first.length == 4 ? p.first.substring(2) : p.first;
  if (m < 1 || m > 12) return anoMes;
  return '${_kMesesCurtos.elementAt(m - 1)}/$a';
}

/// Estilo das linhas de grade dos gráficos
FlLine linhaGrade(double _) => FlLine(color: AppCores.borda, strokeWidth: 1, dashArray: const [4, 4]);

/// Linha do tempo: {AAAA-MM-DD: valor}.
/// Com mais de 45 dias distintos agrupa por mês (soma, ou média se [media]).
class GraficoLinhaTempo extends StatelessWidget {
  final Map<String, double> porData;
  final Color cor;
  final int ultimos;
  final double? maxY;
  final bool media;
  final String sufixo;
  const GraficoLinhaTempo({
    super.key,
    required this.porData,
    this.cor = const Color(0xFF10B981),
    this.ultimos = 15,
    this.maxY,
    this.media = false,
    this.sufixo = '',
  });

  @override
  Widget build(BuildContext context) {
    var dados = Map<String, double>.fromEntries(porData.entries.where((e) => e.key.length >= 7));
    var porMes = false;
    if (dados.length > 45) {
      porMes = true;
      final soma = <String, double>{};
      final qtd = <String, int>{};
      dados.forEach((d, v) {
        final m = d.substring(0, 7);
        soma[m] = (soma[m] ?? 0) + v;
        qtd[m] = (qtd[m] ?? 0) + 1;
      });
      dados = media ? soma.map((k, v) => MapEntry(k, v / (qtd[k] ?? 1))) : soma;
    }
    var chaves = dados.keys.toList()..sort();
    if (chaves.isEmpty) return const SemDadosGrafico();
    final limite = porMes ? 12 : ultimos;
    if (chaves.length > limite) chaves = chaves.sublist(chaves.length - limite);

    final spots = <FlSpot>[];
    for (var i = 0; i < chaves.length; i++) {
      spots.add(FlSpot(i.toDouble(), dados[chaves.elementAt(i)] ?? 0.0));
    }
    if (spots.length == 1) spots.add(FlSpot(1, spots.first.y));

    final passo = chaves.length <= 6 ? 1 : (chaves.length / 5).ceil();
    final estiloEixo = TextStyle(fontSize: 10, color: AppCores.textoSuave, fontWeight: FontWeight.w600);

    String rotulo(int i) {
      if (i < 0 || i >= chaves.length) return '';
      final k = chaves.elementAt(i);
      if (porMes) return rotuloMes(k);
      final p = k.split('-');
      return p.length == 3 ? '${p.last}/${p.elementAt(1)}' : k;
    }

    final total = spots.take(chaves.length).fold<double>(0, (a, s) => a + s.y);
    final ultimo = spots.elementAt(chaves.length - 1).y;
    String fmt(double v) => (v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1)) + sufixo;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _Pilula(texto: porMes ? 'Por mês' : 'Por dia', cor: cor),
        const Spacer(),
        Text(media || sufixo == '%' ? 'Último: ${fmt(ultimo)}' : 'Total: ${fmt(total)}',
            style: TextStyle(fontSize: 12, color: AppCores.textoSecundario, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: AppEspaco.m),
      SizedBox(
        height: 190,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY,
            gridData: const FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: linhaGrade),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (v, meta) {
                    if (v != v.roundToDouble()) return const SizedBox.shrink();
                    return Text(v.toInt().toString(), style: estiloEixo);
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (value != i.toDouble() || i % passo != 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Text(rotulo(i), style: estiloEixo),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.3,
                preventCurveOverShooting: true,
                color: cor,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  checkToShowDot: (s, b) => s.x == spots.last.x || spots.length <= 8,
                  getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                    radius: 3.5,
                    color: AppCores.superficie,
                    strokeWidth: 2.5,
                    strokeColor: cor,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [cor.withOpacity(AppCores.escuro ? 0.35 : 0.25), cor.withOpacity(0.0)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ]);
  }
}

class _Pilula extends StatelessWidget {
  final String texto;
  final Color cor;
  const _Pilula({required this.texto, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppCores.tinta(cor, 0.10), borderRadius: BorderRadius.circular(20)),
      child: Text(texto, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cor)),
    );
  }
}

/// Mantido por compatibilidade (use AppCores.paleta)
const List<Color> kPaleta = AppCores.paleta;

/// Rosca com total no centro + legenda com %; agrupa o excedente em "Outros"
class GraficoPizza extends StatelessWidget {
  final Map<String, int> contagem;
  final int maxFatias;
  final String rotuloCentro;
  final Map<String, Color>? cores; // cor fixa por categoria (opcional)
  const GraficoPizza({
    super.key,
    required this.contagem,
    this.maxFatias = 6,
    this.rotuloCentro = 'total',
    this.cores,
  });

  @override
  Widget build(BuildContext context) {
    var itens = contagem.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    if (itens.isEmpty) return const SemDadosGrafico();
    if (itens.length > maxFatias) {
      final resto = itens.skip(maxFatias - 1).fold<int>(0, (a, b) => a + b.value);
      itens = [...itens.take(maxFatias - 1), MapEntry('Outros', resto)];
    }
    final total = itens.fold<int>(0, (a, b) => a + b.value);
    Color corDe(int i, String k) => cores?[k] ?? AppCores.paleta.elementAt(i % AppCores.paleta.length);

    final secoes = <PieChartSectionData>[];
    for (var i = 0; i < itens.length; i++) {
      final e = itens.elementAt(i);
      secoes.add(PieChartSectionData(
        color: corDe(i, e.key),
        value: e.value.toDouble(),
        title: '',
        radius: 20,
      ));
    }

    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      SizedBox(
        width: 130,
        height: 130,
        child: Stack(alignment: Alignment.center, children: [
          PieChart(PieChartData(sectionsSpace: 2, centerSpaceRadius: 42, sections: secoes, startDegreeOffset: -90)),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$total', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppCores.texto)),
            Text(rotuloCentro, style: TextStyle(fontSize: 10.5, color: AppCores.textoSecundario)),
          ]),
        ]),
      ),
      const SizedBox(width: AppEspaco.l),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(itens.length, (i) {
            final e = itens.elementAt(i);
            final double pct = total == 0 ? 0.0 : e.value * 100 / total;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: corDe(i, e.key), borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(e.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: AppCores.texto)),
                ),
                const SizedBox(width: 6),
                Text('${pct.toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppCores.texto)),
                SizedBox(
                  width: 34,
                  child: Text('${e.value}',
                      textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: AppCores.textoSuave)),
                ),
              ]),
            );
          }),
        ),
      ),
    ]);
  }
}

class SerieEmpilhada {
  final String nome;
  final Color cor;
  const SerieEmpilhada(this.nome, this.cor);
}

/// Colunas empilhadas (ex.: relatos por mês, divididos por tipo)
/// valores: uma lista por coluna, com um valor para cada série
class GraficoBarrasEmpilhadas extends StatelessWidget {
  final List<String> rotulos;
  final List<SerieEmpilhada> series;
  final List<List<double>> valores;
  final double altura;
  const GraficoBarrasEmpilhadas({
    super.key,
    required this.rotulos,
    required this.series,
    required this.valores,
    this.altura = 210,
  });

  @override
  Widget build(BuildContext context) {
    if (rotulos.isEmpty) return const SemDadosGrafico();
    final estiloEixo = TextStyle(fontSize: 10, color: AppCores.textoSuave, fontWeight: FontWeight.w600);
    var maxTotal = 0.0;
    final grupos = <BarChartGroupData>[];
    final largura = rotulos.length <= 6 ? 22.0 : (rotulos.length <= 9 ? 16.0 : 11.0);

    for (var x = 0; x < rotulos.length; x++) {
      final vals = valores.elementAt(x);
      var acumulado = 0.0;
      final pilha = <BarChartRodStackItem>[];
      for (var s = 0; s < series.length; s++) {
        final v = s < vals.length ? vals.elementAt(s) : 0.0;
        if (v <= 0) continue;
        pilha.add(BarChartRodStackItem(acumulado, acumulado + v, series.elementAt(s).cor));
        acumulado += v;
      }
      if (acumulado > maxTotal) maxTotal = acumulado;
      grupos.add(BarChartGroupData(x: x, barRods: [
        BarChartRodData(
          toY: acumulado,
          width: largura,
          color: acumulado == 0 ? AppCores.borda : Colors.transparent,
          rodStackItems: pilha,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
        ),
      ]));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: altura,
        child: BarChart(
          BarChartData(
            maxY: maxTotal <= 0 ? 1 : maxTotal * 1.12,
            alignment: BarChartAlignment.spaceAround,
            barGroups: grupos,
            barTouchData: BarTouchData(enabled: false),
            gridData: const FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: linhaGrade),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 18,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i >= grupos.length) return const SizedBox.shrink();
                    final t = grupos.elementAt(i).barRods.first.toY;
                    if (t <= 0) return const SizedBox.shrink();
                    return Text(t.toInt().toString(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppCores.textoSecundario));
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (v, meta) {
                    if (v != v.roundToDouble() || v == meta.max) return const SizedBox.shrink();
                    return Text(v.toInt().toString(), style: estiloEixo);
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i >= rotulos.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Text(rotulos.elementAt(i), style: estiloEixo),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: AppEspaco.m),
      Wrap(
        spacing: AppEspaco.m,
        runSpacing: 6,
        children: series
            .map((s) => Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: s.cor, borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 5),
                  Text(s.nome, style: TextStyle(fontSize: 11.5, color: AppCores.textoSecundario)),
                ]))
            .toList(),
      ),
    ]);
  }
}

/// Barra única segmentada (ex.: 70% seguro / 30% inseguro)
class BarraProporcao extends StatelessWidget {
  final List<(String, double, Color)> partes;
  const BarraProporcao({super.key, required this.partes});

  @override
  Widget build(BuildContext context) {
    final total = partes.fold<double>(0, (a, p) => a + p.$2);
    if (total <= 0) return const SemDadosGrafico();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 14,
          child: Row(
            children: partes
                .where((p) => p.$2 > 0)
                .map((p) => Expanded(flex: (p.$2 * 1000 / total).round().clamp(1, 1000).toInt(), child: Container(color: p.$3)))
                .toList(),
          ),
        ),
      ),
      const SizedBox(height: AppEspaco.m),
      Wrap(
        spacing: AppEspaco.l,
        runSpacing: 6,
        children: partes.map((p) {
          final pct = p.$2 * 100 / total;
          return Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: p.$3, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 5),
            Text('${p.$1} ', style: TextStyle(fontSize: 12, color: AppCores.textoSecundario)),
            Text('${pct.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppCores.texto)),
          ]);
        }).toList(),
      ),
    ]);
  }
}

/// Conta registros por mês ("AAAA-MM") e por série, para GraficoBarrasEmpilhadas.
/// [serieDe] devolve o índice da série do registro (ou -1 para ignorar).
({List<String> rotulos, List<List<double>> valores}) empilharPorMes(
  Iterable<Map<String, dynamic>> registros, {
  required String campoData,
  required int qtdSeries,
  required int Function(Map<String, dynamic>) serieDe,
  int meses = 6,
}) {
  final mapa = <String, List<double>>{};
  for (final r in registros) {
    final d = soDataIso(r[campoData]);
    if (d.length < 7) continue;
    final s = serieDe(r);
    if (s < 0 || s >= qtdSeries) continue;
    final lista = mapa.putIfAbsent(d.substring(0, 7), () => List<double>.filled(qtdSeries, 0));
    lista[s] = lista.elementAt(s) + 1;
  }
  var chaves = mapa.keys.toList()..sort();
  if (chaves.length > meses) chaves = chaves.sublist(chaves.length - meses);
  return (
    rotulos: chaves.map(rotuloMes).toList(),
    valores: chaves.map((k) => mapa[k] ?? List<double>.filled(qtdSeries, 0)).toList(),
  );
}

/// Bottom sheet padrão de análise (usado nos dashboards)
Future<void> mostrarAnalise(
  BuildContext context, {
  required String titulo,
  required Color cor,
  required IconData icone,
  required List<(String, String, Color)> numeros,
  required String tituloTexto,
  required List<String> itens,
  String rotuloFechar = 'Entendido',
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppEspaco.xl, 0, AppEspaco.xl, AppEspaco.xl),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: AppCores.tinta(cor), borderRadius: BorderRadius.circular(AppRaio.m)),
              child: Icon(icone, color: cor),
            ),
            const SizedBox(width: AppEspaco.m),
            Expanded(child: Text(titulo, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: cor))),
          ]),
          const SizedBox(height: AppEspaco.l),
          Row(
            children: numeros
                .map((n) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: AppEspaco.m),
                        decoration: BoxDecoration(
                          color: AppCores.tinta(n.$3, 0.08),
                          borderRadius: BorderRadius.circular(AppRaio.m),
                        ),
                        child: Column(children: [
                          Text(n.$2, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: n.$3)),
                          const SizedBox(height: 2),
                          Text(n.$1, textAlign: TextAlign.center, style: AppTexto.legenda),
                        ]),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: AppEspaco.xl - 4),
          Text(tituloTexto, style: AppTexto.tituloCard),
          const SizedBox(height: AppEspaco.s + 2),
          ...itens.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: AppEspaco.s + 2),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(Icons.check_circle_outline, size: 17, color: cor),
                  ),
                  const SizedBox(width: AppEspaco.s + 2),
                  Expanded(child: Text(t, style: TextStyle(fontSize: 13.5, color: AppCores.texto, height: 1.45))),
                ]),
              )),
          const SizedBox(height: AppEspaco.m),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: () => Navigator.pop(ctx), child: Text(rotuloFechar)),
          ),
        ]),
      ),
    ),
  );
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
        border: Border.all(color: AppCores.borda),
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
          padding: const EdgeInsets.all(AppEspaco.xxl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: AppCores.alerta.withOpacity(0.12), shape: BoxShape.circle),
              child: const Icon(Icons.lock_outline_rounded, size: 42, color: AppCores.alerta),
            ),
            const SizedBox(height: AppEspaco.l),
            Text('Acesso restrito', style: AppTexto.tituloSecao),
            const SizedBox(height: AppEspaco.s),
            Text(mensagem, textAlign: TextAlign.center, style: AppTexto.legenda.copyWith(fontSize: 14, height: 1.45)),
            const SizedBox(height: AppEspaco.xl),
            OutlinedButton.icon(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Voltar'),
            ),
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
          padding: const EdgeInsets.all(AppEspaco.xxl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: AppCores.perigo.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.cloud_off_rounded, size: 42, color: AppCores.perigo),
            ),
            const SizedBox(height: AppEspaco.l),
            Text('Não foi possível carregar', style: AppTexto.tituloSecao),
            const SizedBox(height: AppEspaco.s),
            Text(mensagem, textAlign: TextAlign.center, style: AppTexto.legenda.copyWith(fontSize: 14)),
            const SizedBox(height: AppEspaco.xl),
            ElevatedButton.icon(
              onPressed: onTentarDeNovo,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Card de registro da consulta (expansível)
class CardRegistro extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final Widget? etiqueta;
  final List<Widget> detalhes;
  final VoidCallback? onExcluir;
  final Color cor;
  final String? fotoNome; // se informado, mostra a foto da pessoa no lugar do ícone
  final IconData icone;

  const CardRegistro({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.detalhes,
    this.etiqueta,
    this.onExcluir,
    this.cor = AppCores.primaria,
    this.fotoNome,
    this.icone = Icons.assignment_turned_in_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspaco.m - 2),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(border: Border(left: BorderSide(color: cor, width: 4))),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.fromLTRB(AppEspaco.m, AppEspaco.xs, AppEspaco.m, AppEspaco.xs),
            leading: fotoNome != null
                ? FotoPerfil(nome: fotoNome!, raio: 21)
                : Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: cor.withOpacity(0.12), borderRadius: BorderRadius.circular(AppRaio.m)),
                    child: Icon(icone, color: cor, size: 22),
                  ),
            title: Row(children: [
              Expanded(
                child: Text(titulo,
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppCores.texto, fontSize: 14.5),
                    overflow: TextOverflow.ellipsis),
              ),
              if (etiqueta != null) ...[const SizedBox(width: AppEspaco.s), etiqueta!],
            ]),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(subtitulo, style: AppTexto.legenda),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(AppEspaco.l, 0, AppEspaco.l, AppEspaco.l),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: AppEspaco.l),
              ...detalhes,
              if (onExcluir != null) ...[
                const SizedBox(height: AppEspaco.s),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppCores.perigo),
                    onPressed: onExcluir,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Excluir registro'),
                  ),
                ),
              ],
            ],
          ),
        ),
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 118, child: Text(label, style: AppTexto.legenda)),
        Expanded(
          child: Text(v.isEmpty ? '-' : v,
              style: TextStyle(fontSize: 13.5, color: AppCores.texto, fontWeight: FontWeight.w500)),
        ),
      ]),
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
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        isDense: true,
        filled: true,
        fillColor: AppCores.superficieSuave,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRaio.m),
          borderSide: BorderSide(color: AppCores.borda),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRaio.m),
          borderSide: BorderSide(color: AppCores.borda),
        ),
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
  final String rotuloTodos;
  const FiltroMenu({
    super.key,
    required this.rotulo,
    required this.valor,
    required this.opcoes,
    required this.onChanged,
    this.rotuloTodos = 'Todos',
  });

  @override
  Widget build(BuildContext context) {
    final ativo = valor.isNotEmpty;
    return PopupMenuButton<String>(
      onSelected: onChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRaio.m)),
      itemBuilder: (ctx) => [
        PopupMenuItem(value: '', child: Text(rotuloTodos)),
        ...opcoes.map((o) => PopupMenuItem(
              value: o,
              child: Row(children: [
                Expanded(child: Text(o)),
                if (o == valor) const Icon(Icons.check, size: 18, color: AppCores.primaria),
              ]),
            )),
      ],
      child: _ChipFiltro(
        icone: Icons.tune,
        texto: ativo ? '$rotulo: $valor' : rotulo,
        ativo: ativo,
      ),
    );
  }
}

class _ChipFiltro extends StatelessWidget {
  final IconData icone;
  final String texto;
  final bool ativo;
  final VoidCallback? onLimpar;
  const _ChipFiltro({required this.icone, required this.texto, required this.ativo, this.onLimpar});

  @override
  Widget build(BuildContext context) {
    final cor = ativo ? AppCores.primaria : AppCores.textoSecundario;
    return Container(
      height: 34,
      padding: EdgeInsets.only(left: 10, right: onLimpar != null ? 4 : 12),
      decoration: BoxDecoration(
        color: ativo ? AppCores.primaria.withOpacity(0.08) : AppCores.superficie,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: ativo ? AppCores.primaria.withOpacity(0.5) : AppCores.borda),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icone, size: 16, color: cor),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(texto,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: ativo ? AppCores.primaria : AppCores.texto)),
        ),
        if (onLimpar != null)
          InkWell(
            onTap: onLimpar,
            customBorder: const CircleBorder(),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 16, color: AppCores.primaria),
            ),
          )
        else
          Icon(Icons.expand_more, size: 18, color: cor),
      ]),
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
    final p = periodo;
    final txt = p == null ? 'Período' : '${dataBrDe(p.start).substring(0, 5)} a ${dataBrDe(p.end).substring(0, 5)}';
    return InkWell(
      borderRadius: BorderRadius.circular(17),
      onTap: () async {
        final r = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          initialDateRange: p,
        );
        if (r != null) onChanged(r);
      },
      child: _ChipFiltro(
        icone: Icons.date_range,
        texto: txt,
        ativo: p != null,
        onLimpar: p == null ? null : () => onChanged(null),
      ),
    );
  }
}

/// Chip simples liga/desliga (ex.: tipos de classificação)
class FiltroOpcoes extends StatelessWidget {
  final List<String> opcoes;
  final String valor; // '' = todos
  final ValueChanged<String> onChanged;
  final String rotuloTodos;
  const FiltroOpcoes({
    super.key,
    required this.opcoes,
    required this.valor,
    required this.onChanged,
    this.rotuloTodos = 'Todos',
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(String rotulo, String v) {
      final sel = valor == v;
      return Padding(
        padding: const EdgeInsets.only(right: AppEspaco.s),
        child: ChoiceChip(
          label: Text(rotulo),
          selected: sel,
          showCheckmark: false,
          onSelected: (_) => onChanged(v),
          labelStyle: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: sel ? AppCores.primaria : AppCores.texto,
          ),
          side: BorderSide(color: sel ? AppCores.primaria.withOpacity(0.5) : AppCores.borda),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        chip(rotuloTodos, ''),
        ...opcoes.map((o) => chip(o, o)),
      ]),
    );
  }
}

bool dentroDoPeriodo(dynamic data, DateTimeRange? periodo) {
  if (periodo == null) return true;
  final iso = soDataIso(data);
  if (iso.isEmpty) return false;
  return iso.compareTo(dataIsoDe(periodo.start)) >= 0 && iso.compareTo(dataIsoDe(periodo.end)) <= 0;
}
