import 'package:flutter/material.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Panel")),
      body: const Center(
        child: Text(
          "Hoş geldiniz, Admin!",
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}