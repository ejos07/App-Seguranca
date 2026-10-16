import 'package:flutter/material.dart';
import '../widgets/comum.dart';
import 'home_page.dart';
import 'relatos_page.dart'; // tela da lista de relatos (classe RelatosPage)
import 'perfil_page.dart';
import 'modulos.dart';

// =====================================================
// Layout principal:  Início | Relatos | ( + ) | Perfil
// O "+" abre a lista de módulos (sobe de baixo).
// =====================================================
class BaseLayout extends StatefulWidget {
  const BaseLayout({super.key});

  @override
  State<BaseLayout> createState() => _BaseLayoutState();
}

class _BaseLayoutState extends State<BaseLayout> {
  Sessao _sessao = Sessao.vazia;
  AcessosModulos _acessos = AcessosModulos.vazio;
  bool _carregando = true;
  int _pagina = 0; // 0 = Início, 1 = Relatos, 2 = Perfil
  Key _chaveRelatos = UniqueKey();
  int _versao = 0; // recarrega o card de pendências

  @override
  void initState() {
    super.initState();
    _carregarSessao();
  }

  Future<void> _carregarSessao() async {
    final s = await Sessao.carregar();
    if (!mounted) return;
    if (s.nome.isEmpty) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    setState(() {
      _sessao = s;
      _carregando = false;
    });
    _recarregarAcessos();
  }

  Future<void> _recarregarAcessos() async {
    if (mounted && _acessos.carregado) setState(() => _versao++);
    final a = await carregarAcessos(_sessao);
    if (mounted) setState(() => _acessos = a);
  }

  void _irParaRelatos() {
    setState(() {
      _pagina = 1;
      _chaveRelatos = UniqueKey(); // recria a lista -> recarrega os relatos
    });
  }

  // Índice da barra (0..3) <-> página (0..2). O índice 2 da barra é o "+".
  int get _indiceBarra => _pagina == 2 ? 3 : _pagina;

  void _aoTocarBarra(int i) {
    if (i == 2) {
      mostrarMenuModulos(context, _sessao, _acessos, irParaRelatos: _irParaRelatos, aoVoltar: _recarregarAcessos);
      return;
    }
    setState(() => _pagina = i == 3 ? 2 : i);
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: IndexedStack(
        index: _pagina,
        children: [
          HomePage(
            sessao: _sessao,
            acessos: _acessos,
            irParaRelatos: _irParaRelatos,
            aoAtualizar: _recarregarAcessos,
            versao: _versao,
          ),
          RelatosPage(key: _chaveRelatos),
          PerfilPage(sessao: _sessao),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceBarra,
        onDestinationSelected: _aoTocarBarra,
        height: 68,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Início'),
          const NavigationDestination(
              icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'Relatos'),
          NavigationDestination(
            icon: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 26),
            ),
            label: 'Módulos',
          ),
          NavigationDestination(
            icon: FotoPerfil(nome: _sessao.nome, raio: 13),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
