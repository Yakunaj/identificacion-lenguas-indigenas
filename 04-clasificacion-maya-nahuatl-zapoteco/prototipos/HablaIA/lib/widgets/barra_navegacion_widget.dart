import 'package:flutter/material.dart';
import '../paginas/principal_pagina.dart';
import '../paginas/audios_pagina.dart';

// Widget de navegación principal con barra de navegación inferior para cambiar entre la página principal y la página de audios.
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

// Estado del widget de navegación principal, que maneja la lógica de cambio de página y la barra de navegación inferior.
class _MainNavigationState extends State<MainNavigation> {
  int _indiceActual = 0;

  final List<Widget> _paginas = [const PrincipalPagina(), const AudiosPagina()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _paginas[_indiceActual],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceActual,
        onDestinationSelected: (int index) {
          setState(() {
            _indiceActual = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Principal'),
          NavigationDestination(icon: Icon(Icons.music_note), label: 'Audios'),
        ],
      ),
    );
  }
}
