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
      width: 260,
      backgroundColor: const Color(0xFFF9F5FF),
      child: Column(
        children: [
          Container(
            height: 140,
            width: double.infinity,
            padding: const EdgeInsets.only(left: 16, bottom: 12),
            alignment: Alignment.bottomLeft,
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 211, 192, 242),
              borderRadius: BorderRadius.only(
                bottomRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                )
              ],
            ),
            child: const Text(
              'Menü',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.deepPurple,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _drawerItem(
                  icon: Icons.calendar_today,
                  label: 'Ana Sayfa',
                  onTap: () {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TeacherHomePage()));
                  },
                ),
                _drawerItem(
                  icon: Icons.calendar_view_week,
                  label: 'Haftalık Program',
                  onTap: () {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WeeklyProgramPage()));
                  },
                ),
                if (role != 'student')
                  _drawerItem(
                    icon: Icons.person,
                    label: 'Öğrencilerim',
                    onTap: () {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MyStudentsPage()));
                    },
                  ),
                if (role != 'student')
                  _drawerItem(
                    icon: Icons.payment,
                    label: 'Ödemelerim',
                    onTap: () {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MyPaymentsPage()));
                    },
                  ),
              ],
            ),
          ),
          const Divider(thickness: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.deepPurple),
              title: const Text(
                'Çıkış Yap',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.deepPurple),
      title: Text(
        label,
        style: const TextStyle(fontSize: 16, color: Colors.black87),
      ),
      onTap: onTap,
      hoverColor: const Color(0xFFEDE7F6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
