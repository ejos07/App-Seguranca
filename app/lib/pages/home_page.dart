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
      appBar: AppBar(
        title: const Text('App Segurança'),
        actions: [
          IconButton(tooltip: 'Atualizar', icon: const Icon(Icons.refresh), onPressed: aoAtualizar),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: aoAtualizar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppEspaco.l, AppEspaco.l, AppEspaco.l, AppEspaco.xxl),
          children: [
            CabecalhoMarca(
              padding: const EdgeInsets.all(AppEspaco.xl - 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
                    ),
                    child: FotoPerfil(nome: sessao.nome, raio: 28),
                  ),
                  const SizedBox(width: AppEspaco.m + 2),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_saudacao,
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(_primeiroNome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                      if (sessao.cargo.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(sessao.cargo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12)),
                      ],
                    ]),
                  ),
                ]),
                const SizedBox(height: AppEspaco.l + 2),
                Container(
                  padding: const EdgeInsets.all(AppEspaco.m),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppRaio.m),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.health_and_safety_outlined, color: Colors.white, size: 26),
                    const SizedBox(width: AppEspaco.m),
                    const Expanded(
                      child: Text('Viu algo inseguro? Relate agora — leva menos de 1 minuto.',
                          style: TextStyle(color: Colors.white, fontSize: 12.5, height: 1.3)),
                    ),
                    const SizedBox(width: AppEspaco.s),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppCores.primariaEscura,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        minimumSize: const Size(0, 38),
                      ),
                      onPressed: () async {
                        final r = await Navigator.pushNamed(context, '/novo_relato');
                        if (r == true) irParaRelatos();
                      },
                      child: const Text('Relatar', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: AppEspaco.l),
            CardPendencias(sessao: sessao, versao: versao),
            const SizedBox(height: AppEspaco.xl),
            Row(children: [
              Expanded(child: Text('Módulos', style: AppTexto.tituloSecao)),
              if (!acessos.carregado)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Text('${mods.length} disponíveis', style: AppTexto.legenda),
            ]),
            const SizedBox(height: AppEspaco.m),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppEspaco.m,
              crossAxisSpacing: AppEspaco.m,
              childAspectRatio: 1.08,
              children: mods
                  .map((m) => _CardModulo(
                        modulo: m,
                        onTap: () => abrirModulo(context, m, irParaRelatos: irParaRelatos, aoVoltar: aoAtualizar),
                      ))
                  .toList(),
            ),
            const SizedBox(height: AppEspaco.xl),
            Center(child: Text('Grupo Rizatti • v$kVersaoApp', style: AppTexto.legenda)),
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
      color: AppCores.superficie,
      borderRadius: BorderRadius.circular(AppRaio.l),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRaio.l),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(AppEspaco.l - 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRaio.l),
            border: Border.all(color: AppCores.borda),
            boxShadow: [
              BoxShadow(color: AppCores.texto.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: modulo.cor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppRaio.m),
                ),
                child: Icon(modulo.icone, color: modulo.cor, size: 24),
              ),
              const Spacer(),
              Icon(Icons.arrow_outward_rounded, size: 18, color: AppCores.textoSuave),
            ]),
            const Spacer(),
            Text(modulo.titulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTexto.tituloCard),
            const SizedBox(height: 3),
            Text(modulo.descricao,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: AppCores.textoSecundario, height: 1.3)),
          ]),
        ),
      ),
    );
  }
}
