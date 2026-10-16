import 'package:flutter/material.dart';
import '../widgets/comum.dart';
import 'modulos.dart';
import 'pendencias.dart';

// =====================================================
// Tela inicial com cards dos módulos
// =====================================================
class HomePage extends StatelessWidget {
  final Sessao sessao;
  final AcessosModulos acessos;
  final VoidCallback irParaRelatos;
  final Future<void> Function() aoAtualizar;
  final int versao; // muda a cada atualização -> recarrega o card de pendências

  const HomePage({
    super.key,
    required this.sessao,
    required this.acessos,
    required this.irParaRelatos,
    required this.aoAtualizar,
    this.versao = 0,
  });

  String get _saudacao {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bom dia';
    if (h < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  String get _primeiroNome {
    final partes = sessao.nome.trim().split(' ');
    return partes.isEmpty ? '' : partes.first;
  }

  @override
  Widget build(BuildContext context) {
    final mods = modulosVisiveis(sessao, acessos).where((m) => m.id != 'novo_relato').toList();

    return Scaffold(
      appBar: AppBar(title: const Text('App Segurança')),
      body: RefreshIndicator(
        onRefresh: aoAtualizar,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$_saudacao, $_primeiroNome!',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      sessao.cargo.isEmpty ? 'Segurança em primeiro lugar.' : sessao.cargo,
                      style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1E293B),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () async {
                        final r = await Navigator.pushNamed(context, '/novo_relato');
                        if (r == true) irParaRelatos();
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Novo Relato', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ),
                const SizedBox(width: 12),
                FotoPerfil(nome: sessao.nome, raio: 34),
              ]),
            ),
            const SizedBox(height: 16),
            CardPendencias(sessao: sessao, versao: versao),
            const SizedBox(height: 24),
            Row(children: [
              const Expanded(
                child: Text('Módulos',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ),
              if (!acessos.carregado)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ]),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.05,
              children: mods
                  .map((m) => _CardModulo(
                        modulo: m,
                        onTap: () => abrirModulo(context, m, irParaRelatos: irParaRelatos, aoVoltar: aoAtualizar),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _CardModulo extends StatelessWidget {
  final Modulo modulo;
  final VoidCallback onTap;
  const _CardModulo({required this.modulo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: modulo.cor.withOpacity(0.12),
              child: Icon(modulo.icone, color: modulo.cor),
            ),
            const Spacer(),
            Text(modulo.titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            Text(modulo.descricao,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          ]),
        ),
      ),
    );
  }
}
