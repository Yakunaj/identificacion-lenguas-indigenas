import 'package:flutter/material.dart';
import '../../Paginas/color_pagina.dart';
import '../../Paginas/audios_pagina.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _indiceActual = 0; 

  final List<Widget> _paginas = [
    const ColorPagina(),
    const AudiosPagina()
  ];

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
          NavigationDestination(
            icon: Icon(Icons.home),
            label: 'Principal',
          ),
          NavigationDestination(
            icon: Icon(Icons.music_note),
            label: 'Audios',
          )
        ],
      ),
    );
  }
}