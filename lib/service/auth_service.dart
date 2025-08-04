import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Future<UserCredential> signUp(String email, String password, String role) async {
    final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await _firestore.collection('users').doc(credential.user!.uid).set({
      'uid': credential.user!.uid,
      'email': email,
      'role': role,
    });
    return credential;
  }

  Future<Map<String, dynamic>?> login(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    final userDoc = await _firestore.collection('users').doc(credential.user!.uid).get();
    return userDoc.data();
  }
}
