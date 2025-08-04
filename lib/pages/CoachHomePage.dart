import 'package:flutter/material.dart';

class CoachHomePage extends StatelessWidget {
  const CoachHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Koç Ana Sayfası")),
      body: const Center(
        child: Text(
          "Hoş geldiniz, Öğrenci Koçu!",
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
