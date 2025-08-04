import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'StudentHomePage.dart';
import 'TeacherHomePage.dart';
import 'CoachHomePage.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String _selectedRole = 'Öğrenci';
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  String _mapRoleToKey(String role) {
    switch (role) {
      case 'Öğrenci':
        return 'student';
      case 'Öğretmen':
        return 'teacher';
      case 'Öğrenci Koçu':
        return 'coach';
      default:
        return 'unknown';
    }
  }

  String _normalizeTurkish(String input) {
    return input
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 's')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'u');
  }

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final fullName = _nameController.text.trim();
        final nameParts = fullName.split(' ');

        if (nameParts.length < 2) {
          _showSnack('Lütfen ad ve soyad giriniz.');
          setState(() => _isLoading = false);
          return;
        }

        final firstName = _normalizeTurkish(nameParts.first).toLowerCase();
        final lastName = _normalizeTurkish(nameParts.last).toLowerCase();
        final generatedUsername = '$lastName.$firstName';

        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();
        final phone = _phoneController.text.trim();

        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        await userCredential.user!.sendEmailVerification();
        _showVerifyDialog(userCredential.user!, generatedUsername, fullName, phone);
      } on FirebaseAuthException catch (e) {
        setState(() => _isLoading = false);
        if (e.code == 'email-already-in-use') {
          _showSnack('Bu e-posta adresi zaten kullanılıyor.');
        } else {
          _showSnack('Hata: ${e.message}');
        }
      } catch (e) {
        setState(() => _isLoading = false);
        _showSnack('Hata: ${e.toString()}');
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showVerifyDialog(User user, String username, String fullName, String phone) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('E-posta Doğrulama'),
        content: const Text(
            'Lütfen e-posta adresinize gelen doğrulama bağlantısına tıklayın. Ardından "Doğruladım" butonuna basın.'),
        actions: [
          TextButton(
            onPressed: () async {
              await user.reload();
              if (_auth.currentUser!.emailVerified) {
                await _saveUser(user, username, fullName, phone, true);

                final roleKey = _mapRoleToKey(_selectedRole);
                Widget nextPage;
                if (roleKey == 'student') {
                  nextPage = const StudentHomePage();
                } else if (roleKey == 'teacher') {
                  nextPage = const TeacherHomePage();
                } else {
                  nextPage = const CoachHomePage();
                }

                if (mounted) {
                  Navigator.of(context).pop();
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => nextPage));
                }
              } else {
                _showSnack('E-posta henüz doğrulanmadı.');
              }
            },
            child: const Text('Doğruladım'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveUser(User user, String username, String name, String phone, bool isVerified) async {
    await _firestore.collection('users').doc(user.uid).set({
      'userMail': user.email,
      'name': name,
      'phone': phone,
      'role': _mapRoleToKey(_selectedRole),
      'username': username,
      'uid': user.uid,
      'isPhoneVerified': false,
      'isMailVerified': isVerified,
    });

    _showSnack('Kayıt başarılı! $username kullanıcı adıyla giriş yapabilirsiniz.');
  }

  Widget _buildRoleButton(String roleLabel) {
    return Expanded(
      child: ElevatedButton(
        onPressed: () => setState(() => _selectedRole = roleLabel),
        style: ElevatedButton.styleFrom(
          backgroundColor: _selectedRole == roleLabel
              ? const Color.fromARGB(255, 191, 169, 229)
              : Colors.grey[400],
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          roleLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("Kayıt Ol")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '... olarak kayıt olmak istiyorum.',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildRoleButton('Öğrenci'),
                        const SizedBox(width: 8),
                        _buildRoleButton('Öğretmen'),
                        const SizedBox(width: 8),
                        _buildRoleButton('Öğrenci Koçu'),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) =>
                          value != null && value.contains('@') ? null : 'Geçerli bir email giriniz',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Ad Soyad',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) =>
                          value != null && value.isNotEmpty ? null : 'Ad soyad gerekli',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Telefon (+90...)',
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) =>
                          value != null && value.length >= 10 ? null : 'Telefon numarası geçersiz',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Şifre',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                      validator: (value) =>
                          value != null && value.length >= 6 ? null : 'Şifre en az 6 karakter olmalı',
                    ),
                    const SizedBox(height: 24),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton.icon(
                            onPressed: _signUp,
                            icon: const Icon(Icons.person_add),
                            label: const Text('Kayıt Ol'),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
