import 'package:flutter/material.dart';

class StudentHomePage extends StatelessWidget {
  const StudentHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Öğrenci Ana Sayfası")),
      body: const Center(
        child: Text(
          "Hoş geldiniz, Öğrenci!",
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
