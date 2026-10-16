import 'package:flutter/material.dart';
import '../widgets/comum.dart';

// =====================================================
// Acesso calculado por módulo (GSD / GSP / GSA dependem do histórico)
// =====================================================
class AcessosModulos {
  final Map<String, NivelAcesso> niveis;
  final bool carregado;
  const AcessosModulos(this.niveis, {this.carregado = true});

  static const vazio = AcessosModulos({}, carregado: false);

  NivelAcesso nivel(String id) => niveis[id] ?? NivelAcesso.nenhum;
  bool tem(String id) => nivel(id) != NivelAcesso.nenhum;
}

/// Busca os históricos e calcula o acesso de cada módulo.
/// Admin não precisa buscar nada: acesso completo a tudo.
Future<AcessosModulos> carregarAcessos(Sessao s) async {
  const regras = [kRegraGsd, kRegraGsp, kRegraGsa];
  if (s.ehAdmin) {
    return AcessosModulos({for (final r in regras) r.id: NivelAcesso.completo});
  }

  Future<MapEntry<String, NivelAcesso>> calcular(RegraModulo regra) async {
    try {
      final resp = await apiGet(regra.endpoint);
      final historico = respostaOk(resp) ? listaDados(decodificar(resp)) : <Map<String, dynamic>>[];
      return MapEntry(regra.id, calcularAcesso(s, regra, historico));
    } catch (e) {
      debugPrint('Acesso ${regra.id}: $e');
      // Sem servidor: só o cargo decide
      return MapEntry(regra.id, calcularAcesso(s, regra, const []));
    }
  }

  final resultados = await Future.wait(regras.map(calcular));
  return AcessosModulos(Map.fromEntries(resultados));
}

// =====================================================
// Catálogo de módulos do app (usado na Home e no botão "+")
// =====================================================
class Modulo {
  final String id;
  final String titulo;
  final String descricao;
  final IconData icone;
  final Color cor;
  final String? rota; // null = aba Relatos do próprio BaseLayout
  final bool Function(Sessao s, AcessosModulos a) visivel;

  const Modulo({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.icone,
    required this.cor,
    required this.rota,
    required this.visivel,
  });
}

bool _todos(Sessao s, AcessosModulos a) => true;
bool _soAdmin(Sessao s, AcessosModulos a) => s.ehAdmin;
bool _gsd(Sessao s, AcessosModulos a) => a.tem('gsd');
bool _gsp(Sessao s, AcessosModulos a) => a.tem('gsp');
bool _gsa(Sessao s, AcessosModulos a) => a.tem('gsa');

const List<Modulo> kModulos = [
  Modulo(
    id: 'novo_relato',
    titulo: 'Novo Relato',
    descricao: 'Registrar ato, condição, incidente ou abordagem positiva',
    icone: Icons.add_alert_outlined,
    cor: Color(0xFFEF4444),
    rota: '/novo_relato',
    visivel: _todos,
  ),
  Modulo(
    id: 'relatos',
    titulo: 'Relatos',
    descricao: 'Consultar relatos e dashboard',
    icone: Icons.list_alt,
    cor: Color(0xFF2563EB),
    rota: null,
    visivel: _todos,
  ),
  Modulo(
    id: 'dto',
    titulo: 'DTO',
    descricao: 'Diagnóstico de Tarefa Operacional',
    icone: Icons.fact_check_outlined,
    cor: Color(0xFF0EA5E9),
    rota: '/dto',
    visivel: _todos,
  ),
  Modulo(
    id: 'gsd',
    titulo: 'GSD',
    descricao: 'Diálogos de Segurança (entrega)',
    icone: Icons.local_shipping_outlined,
    cor: Color(0xFF10B981),
    rota: '/gsd',
    visivel: _gsd,
  ),
  Modulo(
    id: 'gsa',
    titulo: 'GSA',
    descricao: 'Gabarito de Segurança do Armazém',
    icone: Icons.warehouse_outlined,
    cor: Color(0xFF7C3AED),
    rota: '/gsa',
    visivel: _gsa,
  ),
  Modulo(
    id: 'gsp',
    titulo: 'GSP',
    descricao: 'Guia de Segurança de Puxada',
    icone: Icons.fire_truck_outlined,
    cor: Color(0xFF0E7490),
    rota: '/gsp',
    visivel: _gsp,
  ),
  Modulo(
    id: 'usuarios',
    titulo: 'Gestão de Usuários',
    descricao: 'Lista de colaboradores e reset de senha',
    icone: Icons.admin_panel_settings_outlined,
    cor: Color(0xFF991B1B),
    rota: '/usuarios',
    visivel: _soAdmin,
  ),
];

List<Modulo> modulosVisiveis(Sessao s, AcessosModulos a) => kModulos.where((m) => m.visivel(s, a)).toList();

/// Abre o módulo: rota nomeada ou aba Relatos (callback)
Future<void> abrirModulo(BuildContext context, Modulo m, {VoidCallback? irParaRelatos, VoidCallback? aoVoltar}) async {
  if (m.rota == null) {
    irParaRelatos?.call();
    return;
  }
  final resultado = await Navigator.pushNamed(context, m.rota!);
  if (m.id == 'novo_relato' && resultado == true) irParaRelatos?.call();
  aoVoltar?.call(); // recalcula acessos (ex.: aplicou o 1º GSD)
}

/// Lista que "sobe" ao tocar no "+"
Future<void> mostrarMenuModulos(
  BuildContext context,
  Sessao sessao,
  AcessosModulos acessos, {
  VoidCallback? irParaRelatos,
  VoidCallback? aoVoltar,
}) {
  final mods = modulosVisiveis(sessao, acessos);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) {
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 8),
                child: Text('Módulos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              if (!acessos.carregado)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Row(children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 10),
                    Text('Verificando seus acessos...', style: TextStyle(color: Colors.grey)),
                  ]),
                ),
              ...mods.map((m) => ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: CircleAvatar(
                      backgroundColor: m.cor.withOpacity(0.12),
                      child: Icon(m.icone, color: m.cor),
                    ),
                    title: Text(m.titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(m.descricao, style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(ctx);
                      abrirModulo(context, m, irParaRelatos: irParaRelatos, aoVoltar: aoVoltar);
                    },
                  )),
            ],
          ),
        ),
      );
    },
  );
}
