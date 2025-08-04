import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../teacherHomePage.dart';
import 'MyStudentsPage.dart';
import 'MyPaymentsPage.dart';
import 'WeeklyProgramPage.dart';
import '../LoginPage.dart';

class AppDrawer extends StatelessWidget {
  final String role;

  const AppDrawer({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 240,
      backgroundColor: const Color(0xFFF9F5FF),
      child: Column(
        children: [
          Container(
            height: 120,
            padding: const EdgeInsets.only(left: 16, bottom: 12),
            alignment: Alignment.bottomLeft,
            color: const Color.fromARGB(255, 211, 192, 242),
            child: const Text(
              'Menü',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.deepPurple),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _drawerItem(Icons.calendar_today, 'Ana Sayfa', () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TeacherHomePage()));
                }),
                _drawerItem(Icons.calendar_view_week, 'Haftalık Program', () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WeeklyProgramPage()));
                }),
                if (role != 'student')
                  _drawerItem(Icons.person, 'Öğrencilerim', () {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MyStudentsPage()));
                  }),
                if (role != 'student')
                  _drawerItem(Icons.payment, 'Ödemelerim', () {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MyPaymentsPage()));
                  }),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.deepPurple),
            title: const Text('Çıkış Yap', style: TextStyle(fontSize: 16, color: Colors.black87)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.deepPurple),
      title: Text(title, style: const TextStyle(fontSize: 16, color: Colors.black87)),
      onTap: onTap,
    );
  }
}
