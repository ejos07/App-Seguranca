import 'package:flutter/material.dart';
import '../widgets/comum.dart';

// =====================================================
// Catálogo de módulos do app (usado na Home e no botão "+")
// Para adicionar um módulo novo: crie a tela, registre a rota no main.dart
// e inclua um item aqui.
// =====================================================
class Modulo {
  final String id;
  final String titulo;
  final String descricao;
  final IconData icone;
  final Color cor;
  final String? rota; // null = aba Relatos do próprio BaseLayout
  final bool Function(Sessao s) visivel;

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

bool _todos(Sessao s) => true;
bool _podeDto(Sessao s) => s.podeCriarDTO;
bool _soAdmin(Sessao s) => s.ehAdmin;

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
    rota: '/novo_dto',
    visivel: _podeDto,
  ),
  Modulo(
    id: 'gsd',
    titulo: 'GSD',
    descricao: 'Diálogos de Segurança (entrega)',
    icone: Icons.local_shipping_outlined,
    cor: Color(0xFF10B981),
    rota: '/gsd',
    visivel: _todos,
  ),
  Modulo(
    id: 'gsa',
    titulo: 'GSA',
    descricao: 'Gabarito de Segurança do Armazém',
    icone: Icons.warehouse_outlined,
    cor: Color(0xFF7C3AED),
    rota: '/gsa',
    visivel: _todos,
  ),
  Modulo(
    id: 'gsp',
    titulo: 'GSP',
    descricao: 'Guia de Segurança de Puxada',
    icone: Icons.fire_truck_outlined,
    cor: Color(0xFF0E7490),
    rota: '/gsp',
    visivel: _todos,
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

List<Modulo> modulosVisiveis(Sessao s) => kModulos.where((m) => m.visivel(s)).toList();

/// Abre o módulo: rota nomeada ou aba Relatos (callback)
Future<void> abrirModulo(BuildContext context, Modulo m, {VoidCallback? irParaRelatos}) async {
  if (m.rota == null) {
    irParaRelatos?.call();
    return;
  }
  final resultado = await Navigator.pushNamed(context, m.rota!);
  // Se salvou um relato, volta para a aba Relatos atualizada
  if (m.id == 'novo_relato' && resultado == true) irParaRelatos?.call();
}

/// Lista que "sobe" ao tocar no "+"
Future<void> mostrarMenuModulos(BuildContext context, Sessao sessao, {VoidCallback? irParaRelatos}) {
  final mods = modulosVisiveis(sessao);
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
                      abrirModulo(context, m, irParaRelatos: irParaRelatos);
                    },
                  )),
            ],
          ),
        ),
      );
    },
  );
}
