import 'package:flutter/material.dart';
import 'widgets/barra_navegacion_widget.dart';


void main() {
  runApp(const MainApp());
  
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Titulo',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor:Color.fromARGB(255, 152, 223, 189))),
      home: MainNavigation()
    );
  }
}

