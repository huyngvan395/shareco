import 'package:flutter/material.dart';

class MainScaffold extends StatelessWidget{
  final Widget child;

  const MainScaffold({
    super.key,
    required this.child
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child
    );
  }
}