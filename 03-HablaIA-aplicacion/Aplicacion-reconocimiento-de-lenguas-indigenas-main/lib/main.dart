import 'package:flutter/material.dart';
import 'widgets/barra_navegacion_widget.dart';
import 'estructuras/tema_color_estructura.dart';


void main() {
  runApp(const MainApp());
  
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Titulo',
      theme: TemaColorEstructura.lightTheme,
      darkTheme: TemaColorEstructura.darkTheme,
      themeMode: ThemeMode.system, 
      home: MainNavigation()
    );
  }
}

