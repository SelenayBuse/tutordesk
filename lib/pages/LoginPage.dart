import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'TeacherHomePage.dart';
import 'StudentHomePage.dart';
import 'CoachHomePage.dart';
import 'SignupPage.dart';
import 'package:tutordesk/pages/AdminHomePage.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  void _login() async {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kullanıcı adı ve şifre boş olamaz")),
      );
      return;
    }

    try {
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kullanıcı bulunamadı")),
        );
        return;
      }

      final userData = userQuery.docs.first.data();
      final email = userData['userMail'];
      final role = userData['role'];

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      switch (role) {
        case 'teacher':
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TeacherHomePage()));
          break;
        case 'student':
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StudentHomePage()));
          break;
        case 'coach':
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CoachHomePage()));
          break;
        case 'admin':
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminHomePage()));
          break;
        default:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Tanımsız kullanıcı rolü")),
          );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Giriş başarısız: ${e.message}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Giriş Yap")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(labelText: 'Kullanıcı Adı'),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Şifre'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _login,
              child: const Text("Giriş"),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpPage()));
              },
              child: const Text("Hesabınız yok mu? Kayıt olun"),
            ),
          ],
        ),
      ),
    );
  }
}
